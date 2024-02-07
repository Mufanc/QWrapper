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
use nix::libc::{c_int, RTLD_LAZY};
use nix::sys::socket;
use nix::sys::socket::{AddressFamily, SockFlag, SockType, UnixAddr};
use once_cell::sync::Lazy;
use tokio::io::AsyncWriteExt;
use tokio::net::UnixStream;
use tokio::runtime::Runtime;
use url::Url;

use crate::configs::Operation;

mod dlopt;
mod configs;

static SERVER_ADDRESS: Lazy<UnixAddr> = Lazy::new(|| {
    UnixAddr::new_abstract(configs::server_address().as_bytes()).unwrap()
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


fn open_url(url: &str) -> Result<()> {
    let client = socket::socket(AddressFamily::Unix, SockType::Stream, SockFlag::empty(), None)?;
    let client_raw = client.as_raw_fd();

    socket::connect(client_raw, SERVER_ADDRESS.deref())?;

    let url_owned = url.to_owned();
    let future = ASYNC_RUNTIME.spawn(async move {
        let result: Result<()> = try {
            let mut stream = UnixStream::from_std(SystemUnixStream::from(client))?;

            stream.write_i32(Operation::OpenLink.into()).await?;
            stream.write_all(url_owned.as_bytes()).await?;
        };

        if let Err(e) = result {
            eprintln!("failed to open link: {e}");
        }
    });

    ASYNC_RUNTIME.block_on(future)?;

    Ok(())
}


fn handle_open(argv: *const *const c_char) {
    unsafe {
        CStr::from_ptr(*argv.add(1)).to_str()
            .ok()
            .and_then(|url| Url::parse(url).ok())
            .and_then(|url| {
                match url.domain() {
                    Some("c.pc.qq.com") => {
                        let queries: HashMap<_, _> = url.query_pairs().into_owned().collect();
                        queries.get("pfurl").or(queries.get("url")).cloned()
                    }
                    _ => Some(url.to_string())
                }
            })
            .and_then(|url| open_url(&url).ok());
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

        println!("found libc: {libc}");

        let handle = dlopt::dlopen(&libc, RTLD_LAZY).unwrap();
        let execvp = dlopt::dlsym(handle, "execvp").unwrap();

        println!("found execvp: {execvp:?}");

        unsafe { mem::transmute(execvp) }
    });

    unsafe {
        if CStr::from_ptr(file).to_str() == Ok("xdg-open") {
            handle_open(argv);
        }
    }

    real_execvp(file, argv)
}


#[ctor]
fn main() {
    println!("injected!");
}
