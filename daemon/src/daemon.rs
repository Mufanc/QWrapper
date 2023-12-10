#![feature(peer_credentials_unix_socket)]

use std::fs;
use std::fs::Metadata;
use std::io::Read;
use std::os::fd::{AsRawFd, OwnedFd};
use std::os::unix::fs::MetadataExt;
use std::os::unix::net::UnixListener;
use std::process::{Command, exit};
use std::thread::sleep;
use std::time::Duration;

use anyhow::{bail, Result};
use nix::{libc, unistd};
use nix::errno::Errno;
use nix::sys::prctl;
use nix::sys::signal::Signal;
use nix::sys::socket;
use nix::sys::socket::{AddressFamily, MsgFlags, SockFlag, SockType, UnixAddr};

mod configs;


fn bind_server(fd: &OwnedFd) -> Result<()> {
    let addr = &UnixAddr::new_abstract(configs::SERVER_ADDRESS.as_bytes())?;

    if let Err(err) = socket::bind(fd.as_raw_fd(), addr) {
        if err != Errno::EADDRINUSE {
            bail!(err);
        }

        eprintln!("address already in use, stop old daemon and retry...");

        let client = socket::socket(AddressFamily::Unix, SockType::Stream, SockFlag::empty(), None)?;
        let client_raw = client.as_raw_fd();

        socket::connect(client_raw, addr)?;
        socket::send(client_raw, "@exit".as_bytes(), MsgFlags::empty())?;

        drop(client);  // close fd

        sleep(Duration::from_secs(1));

        return bind_server(fd);
    }

    socket::listen(&fd, 16)?;

    Ok(())
}


fn verify_ns(proc: Option<libc::pid_t>) -> bool {
    if proc.is_none() {
        return false
    }

    fn get_ns(id: libc::pid_t) -> Option<Metadata> {
        fs::metadata(format!("/proc/{id}/ns/pid")).ok()
    }

    let remote = get_ns(proc.unwrap());
    let local = get_ns(unistd::getpid().as_raw());

    match (remote, local) {
        (Some(remote), Some(local)) => {
            remote.dev() == local.dev() && remote.ino() == local.ino()
        }
        _ => false
    }
}


fn super_command(cmd: &str) {
    match cmd {
        "@exit" => exit(0),
        "@example" => println!("example"),
        _ => ()
    }
}


fn main() -> Result<()> {
    let fd = socket::socket(AddressFamily::Unix, SockType::Stream, SockFlag::empty(), None)?;

    bind_server(&fd)?;

    let listener = UnixListener::from(fd);
    println!("daemon is listening on @{}", configs::SERVER_ADDRESS);

    prctl::set_pdeathsig(Signal::SIGKILL)?;

    let mut command = Command::new("/opt/QQ/launcher.sh");
    let mut child = command.spawn()?;

    for stream in listener.incoming() {
        match stream {
            Ok(mut client) => {
                let remote_pid = client.peer_cred()
                    .ok()
                    .and_then(|c| c.pid);

                let mut data = String::new();
                match client.read_to_string(&mut data) {
                    Ok(_) => {
                        #[allow(clippy::collapsible_else_if)]
                        if data.starts_with('@') && verify_ns(remote_pid) {
                            super_command(&data);
                        } else {
                            if let Err(err) = Command::new("xdg-open").arg(data).status() {
                                eprintln!("{err}");
                            }
                        }
                    }
                    Err(err) => eprintln!("error while receiving url: {err}")
                }
            }
            Err(err) => {
                eprintln!("error while accepting connection: {err}");
                break
            }
        }
    }

    child.kill()?;

    Ok(())
}
