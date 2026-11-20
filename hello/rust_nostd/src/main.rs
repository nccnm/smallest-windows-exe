#![no_std]
#![no_main]

use core::ffi::c_void;

#[link(name = "kernel32")]
unsafe extern "system" {
    fn GetStdHandle(n: u32) -> *mut c_void;
    fn WriteFile(h: *mut c_void, b: *const u8, n: u32, w: *mut u32, o: *mut c_void) -> i32;
    fn ExitProcess(code: u32) -> !;
}

#[panic_handler]
fn panic(_: &core::panic::PanicInfo) -> ! {
    unsafe { ExitProcess(1) }
}

#[unsafe(no_mangle)]
pub extern "system" fn start() -> ! {
    let msg = b"Hello, World!\r\n";
    let mut n = 0u32;
    unsafe {
        WriteFile(GetStdHandle(-11i32 as u32), msg.as_ptr(), msg.len() as u32, &mut n, core::ptr::null_mut());
        ExitProcess(0)
    }
}
