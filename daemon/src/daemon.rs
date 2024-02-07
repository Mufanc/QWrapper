use std::os::fd::AsRawFd;
use std::os::unix::net::UnixListener as SystemUnixListener;

use anyhow::Result;
use nix::sys::{signal, socket};
use nix::sys::socket::{AddressFamily, SockFlag, SockType, UnixAddr};
use nix::unistd;
use tokio::io::AsyncReadExt;
use tokio::net::{UnixListener, UnixStream};
use tokio::process::Command;

use crate::configs::Operation;

mod configs;


trait BindAbstract<A : AsRef<str>> {
    fn bind_abstract(addr: A) -> Result<UnixListener>;
}

impl<A : AsRef<str>> BindAbstract<A> for UnixListener {
    fn bind_abstract(addr: A) -> Result<UnixListener> {
        let fd = socket::socket(AddressFamily::Unix, SockType::Stream, SockFlag::empty(), None)?;
        let addr = &UnixAddr::new_abstract(addr.as_ref().as_bytes())?;

        socket::bind(fd.as_raw_fd(), addr)?;
        socket::listen(&fd, 16)?;

        let sys = SystemUnixListener::from(fd);
        
        Ok(UnixListener::from_std(sys)?)
    }
}


async fn handle_client(mut client: UnixStream) -> Result<()> {
    // let remote_pid = client.peer_cred()
    //     .ok()
    //     .and_then(|c| c.pid())
    //     .unwrap();

    let op = Operation::from(client.read_i32().await?);

    match op {
        Operation::OpenLink => {
            let mut url = String::new();

            client.read_to_string(&mut url).await?;
            Command::new("xdg-open").arg(url).status().await?;
        }
    }

    Ok(())
}


async fn run_server() -> Result<()> {
    let listener = UnixListener::bind_abstract(configs::server_address())?;

    loop {
        match listener.accept().await {
            Ok((client, _)) => {
                if let Err(e) = handle_client(client).await {
                    eprintln!("error while handling client: {e}");
                }
            }
            Err(e) => {
                eprintln!("error while accepting connection: {e}");
                break
            }
        }
    }

    Ok(())
}


#[tokio::main]
async fn main() -> Result<()> {
    let server = tokio::spawn(async {
        run_server().await.expect("failed to run server!");
    });

    let mut command = Command::new("/opt/QQ/launcher.sh");
    let mut child = command.spawn()?;

    child.wait().await?;

    tokio::select! {
        _ = child.wait() => (),
        _ = server => (),
    }

    signal::killpg(unistd::getpid(), signal::SIGKILL)?;

    Ok(())
}
