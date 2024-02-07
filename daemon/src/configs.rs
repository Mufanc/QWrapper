use std::env;
use nix::unistd::getpid;
use crate::configs::Operation::OpenLink;

pub const DAEMON_ADDRESS_ENV: &str = "QWRAPPER_DAEMON";
pub const DAEMON_ADDRESS_PREFIX: &str = "qwrapper-daemon-";


pub fn server_address() -> String {
    if let Ok(addr) = env::var(DAEMON_ADDRESS_ENV) {
        addr
    } else {
        format!("{}{}", DAEMON_ADDRESS_PREFIX, getpid())
    }
}


pub enum Operation {
    OpenLink = 0
}

impl From<i32> for Operation {
    fn from(value: i32) -> Self {
        match value {
            0 => OpenLink,
            _ => panic!("invalid value: {value}")
        }
    }
}

impl Into<i32> for Operation {
    fn into(self) -> i32 {
        match self {
            OpenLink => 0
        }
    }
}
