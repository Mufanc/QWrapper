#![feature(try_blocks)]

use std::{fs, mem};
use std::collections::HashMap;
use std::ffi::{c_char, CStr};
use std::ops::Deref;
use std::os::fd::AsRawFd;
use std::os::unix::net::UnixStream as SystemUnixStream;
use std::process::exit;

use anyhow::Result;
use ctor::ctor;
use goblin::elf::dynamic::DT_NEEDED;
use goblin::elf::Elf;
use log::{debug, error, info};
use nix::libc::{c_int, RTLD_LAZY};
use nix::sys::socket;
use nix::sys::socket::{AddressFamily, SockFlag, SockType, UnixAddr};
use nix::unistd::getpid;
use once_cell::sync::Lazy;
use tokio::io::AsyncWriteExt;
use tokio::net::UnixStream;
use tokio::runtime::Runtime;
use url::Url;

use crate::configs::Operation;

mod dlopt;
mod configs;

static SERVER_ADDRESS: Lazy<UnixAddr> = Lazy::new(|| {
    let address = configs::server_address();
    info!("daemon address: {address}");
    UnixAddr::new_abstract(address.as_bytes()).unwrap()
});

static ASYNC_RUNTIME: Lazy<Runtime> = Lazy::new(|| {
    Runtime::new().unwrap()
});


fn find_libc() -> Result<String> {
    const QQNT_ELF: &str = "/opt/QQ/main";

    let data = fs::read(QQNT_ELF)?;
    let elf = Elf::parse(&data)?;

    if let Some(dynamic) = elf.dynamic {
        for item in &dynamic.dyns {
            if item.d_tag != DT_NEEDED {
                continue;
            }

            if let Some(name) = elf.dynstrtab.get_at(item.d_val as usize) {
                if !name.starts_with("libc.so") {
                    continue
                }

                return Ok(name.to_string())
            }
        }
    }

    anyhow::bail!("failed to find libc!")
}


fn do_open(url: &str) -> Result<()> {
    let client = socket::socket(AddressFamily::Unix, SockType::Stream, SockFlag::empty(), None)?;
    let client_raw = client.as_raw_fd();

    socket::connect(client_raw, SERVER_ADDRESS.deref())?;

    let url_owned = url.to_owned();
    let future = ASYNC_RUNTIME.spawn(async move {
        let result: Result<()> = try {
            let mut stream = UnixStream::from_std(SystemUnixStream::from(client))?;

            stream.write_i32(Operation::OpenFileOrLink.into()).await?;
            stream.write_all(url_owned.as_bytes()).await?;
        };

        if let Err(e) = result {
            error!("failed to open: {e}");
        }
    });

    ASYNC_RUNTIME.block_on(future)?;

    Ok(())
}


fn handle_open(args: &[&str]) {
    let target = Url::parse(args[1])
        .ok()
        .and_then(|url| {
            let new_url = match url.domain() {
                Some("c.pc.qq.com") => {
                    let queries: HashMap<_, _> = url.query_pairs().into_owned().collect();
                    queries.get("pfurl").or(queries.get("url")).cloned()
                }
                _ => Some(url.to_string())
            };

            if let Some(new_url) = &new_url {
                if url.as_str() != new_url {
                    debug!("transform url: {url} -> {new_url}");
                } else {
                    debug!("open url: {url} (not changed)");
                }
            }

            new_url
        })
        .unwrap_or(args[1].to_owned());

    if let Err(e) = do_open(&target) {
        error!("failed to open [{}]: {}", args.join(", "), e);
    }

    exit(0);
}


type ExecvpFn = fn(*const c_char, *const *const c_char) -> i32;

#[no_mangle]
#[allow(non_upper_case_globals)]
#[allow(clippy::not_unsafe_ptr_arg_deref)]
pub fn execvp(file: *const c_char, argv: *const *const c_char) -> c_int {
    static real_execvp: Lazy<ExecvpFn> = Lazy::new(|| {
        let libc = find_libc().unwrap();

        debug!("found libc: {libc}");

        let handle = dlopt::dlopen(&libc, RTLD_LAZY).unwrap();
        let execvp = dlopt::dlsym(handle, "execvp").unwrap();

        debug!("found execvp: {execvp:?}");

        unsafe { mem::transmute(execvp) }
    });

    let pathname = unsafe { CStr::from_ptr(file).to_str() };

    if let Ok("xdg-open") = pathname {
        info!("xdg-open detected, redirecting...");

        let mut args: Vec<&str> = vec![];
        let mut ptr: *const *const c_char = argv;
        let mut index = 0;

        unsafe {
            while !(*ptr).is_null() {
                let arg = CStr::from_ptr(*ptr).to_str().expect(&format!("failed to decode argv[{index}]"));
                args.push(arg);
                ptr = ptr.add(1);
                index += 1;
            }
        }

        debug!("{}", args.join(" "));

        handle_open(&args);
    }

    real_execvp(file, argv)
}


#[ctor]
fn main() {
    env_logger::init();
    info!("injected into process {} in container", getpid());
}
