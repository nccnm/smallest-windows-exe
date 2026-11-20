// Zig without std I/O: call kernel32 directly.
const w = @import("std").os.windows;
extern "kernel32" fn GetStdHandle(n: u32) callconv(.winapi) ?*anyopaque;
extern "kernel32" fn WriteFile(h: ?*anyopaque, b: [*]const u8, n: u32, written: ?*u32, o: ?*anyopaque) callconv(.winapi) i32;
pub fn main() void {
    const msg = "Hello, World!\r\n";
    _ = w;
    _ = WriteFile(GetStdHandle(@bitCast(@as(i32, -11))), msg, msg.len, null, null);
}
