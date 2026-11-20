const std = @import("std");
const Io = std.Io;

pub fn main(init: std.process.Init) !void {
    var buf: [64]u8 = undefined;
    var fw: Io.File.Writer = .init(.stdout(), init.io, &buf);
    try fw.interface.writeAll("Hello, World!\n");
    try fw.interface.flush();
}
