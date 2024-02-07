use std::env;
use nix::unistd::getpid;
use crate::configs::Operation::OpenLink;

const DAEMON_ADDRESS_ENV: &str = "QWRAPPER_DAEMON";
const DAEMON_ADDRESS_PREFIX: &str = "qwrapper-daemon-";


pub fn server_address() -> String {
    if let Ok(addr) = env::var(DAEMON_ADDRESS_ENV) {
        addr
    } else {
        env::set_var(DAEMON_ADDRESS_ENV, format!("{}{}", DAEMON_ADDRESS_PREFIX, getpid()));
        server_address()
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
