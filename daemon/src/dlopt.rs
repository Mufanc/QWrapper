use std::ffi::{c_void, CStr, CString};

use anyhow::Result;
use nix::libc;
use nix::libc::c_int;

#[derive(Debug)]
pub struct Handle(String, *mut c_void);

pub fn dlopen(path: &str, flag: c_int) -> Result<Handle> {
    let filename = CString::new(path)?;

    unsafe {
        let handle = libc::dlopen(filename.as_ptr(), flag);

        if handle.is_null() {
            let error = CStr::from_ptr(libc::dlerror()).to_str()?;
            anyhow::bail!("dlopen {path} failed: {error}");
        }

        Ok(Handle(path.to_string(), handle))
    }
}

pub fn dlsym(handle: Handle, symbol: &str) -> Result<*mut c_void> {
    let name = CString::new(symbol)?;

    unsafe {
        let addr = libc::dlsym(handle.1, name.as_ptr());

        if addr.is_null() {
            let error = CStr::from_ptr(libc::dlerror()).to_str()?;
            anyhow::bail!("failed to dlsym for `{symbol}` in {}: {error}", handle.0);
        }

        Ok(addr)
    }
}
