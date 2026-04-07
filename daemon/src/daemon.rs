use std::os::fd::AsRawFd;
use std::os::unix::net::UnixListener as SystemUnixListener;

use anyhow::Result;
use log::{debug, error, info};
use nix::sys::socket;
use nix::sys::socket::{AddressFamily, SockFlag, SockType, UnixAddr};
use tokio::io::AsyncReadExt;
use tokio::net::{UnixListener, UnixStream};
use tokio::process::Command;

use crate::configs::Operation;

mod configs;

trait BindAbstract<A: AsRef<str>> {
    fn bind_abstract(addr: A) -> Result<UnixListener>;
}

impl<A: AsRef<str>> BindAbstract<A> for UnixListener {
    fn bind_abstract(addr: A) -> Result<UnixListener> {
        let fd = socket::socket(
            AddressFamily::Unix,
            SockType::Stream,
            SockFlag::empty(),
            None,
        )?;
        let addr = &UnixAddr::new_abstract(addr.as_ref().as_bytes())?;

        socket::bind(fd.as_raw_fd(), addr)?;
        socket::listen(&fd, 16)?;

        let sys = SystemUnixListener::from(fd);

        Ok(UnixListener::from_std(sys)?)
    }
}

async fn handle_client(mut client: UnixStream) -> Result<()> {
    let op = Operation::try_from(client.read_i32().await?)?;

    match op {
        Operation::OpenFileOrLink => {
            let mut url = String::new();

            client.read_to_string(&mut url).await?;

            let status = Command::new("xdg-open").arg(&url).status().await?;
            if !status.success() {
                anyhow::bail!("xdg-open failed: {}", status);
            }

            info!("xdg-open {url}");
        }
    }

    Ok(())
}

async fn run_server() -> Result<()> {
    let listener = UnixListener::bind_abstract(configs::server_address())?;

    loop {
        match listener.accept().await {
            Ok((client, _)) => {
                debug!("new connection: {client:?}");

                tokio::spawn(async move {
                    if let Err(e) = handle_client(client).await {
                        error!("error while handling client: {e}");
                    }
                });
            }
            Err(e) => {
                error!("error while accepting connection: {e}");
                break;
            }
        }
    }

    Ok(())
}

#[tokio::main]
async fn main() -> Result<()> {
    env_logger::init();

    info!("daemon started");

    let addr = configs::server_address();

    let server = tokio::spawn(async { run_server().await });

    let mut child = Command::new("/opt/QQ/launcher.sh")
        .env(configs::DAEMON_ADDRESS_ENV, &addr)
        .spawn()?;

    tokio::select! {
        child_status = child.wait() => {
            let status = child_status?;
            info!("launcher exited with status: {}", status);
        }
        server_result = server => {
            match server_result {
                Ok(Ok(())) => error!("server exited unexpectedly"),
                Ok(Err(e)) => error!("server exited with error: {e}"),
                Err(e) => error!("server join error: {e}"),
            }
        }
    }

    Ok(())
}
