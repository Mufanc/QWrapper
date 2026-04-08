use nix::unistd::getpid;
use std::convert::TryFrom;
use std::env;

pub const DAEMON_ADDRESS_ENV: &str = "QWRAPPER_DAEMON";
pub const DAEMON_ADDRESS_PREFIX: &str = "qwrapper-daemon-";

pub fn server_address() -> String {
    match env::var(DAEMON_ADDRESS_ENV) {
        Ok(addr) if !addr.is_empty() => addr,
        _ => format!("{}{}", DAEMON_ADDRESS_PREFIX, getpid().as_raw()),
    }
}

#[repr(i32)]
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Operation {
    OpenFileOrLink = 0,
}

impl TryFrom<i32> for Operation {
    type Error = anyhow::Error;

    fn try_from(value: i32) -> Result<Self, Self::Error> {
        match value {
            0 => Ok(Self::OpenFileOrLink),
            _ => Err(anyhow::anyhow!("invalid operation value: {}", value)),
        }
    }
}

impl From<Operation> for i32 {
    fn from(op: Operation) -> Self {
        op as i32
    }
}
