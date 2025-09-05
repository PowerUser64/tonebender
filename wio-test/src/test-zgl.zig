const std = @import("std");
const wio = @import("wio");
const gl = @import("zgl");

pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}).init;
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    try wio.init(alloc, .{});
    defer wio.deinit();

    var win = try wio.createWindow(.{
        .opengl = .{ .major_version = 4, .minor_version = 5 },
    });
    defer win.destroy();

    win.makeContextCurrent();
    win.swapInterval(1);

    try gl.loadExtensions(void, glGetProcAddress);

    try wio.run(loop);
}

fn glGetProcAddress(_: anytype, comptime name: [:0]const u8) gl.binding.FunctionPointer {
    return wio.glGetProcAddress(name);
}

fn loop() !bool {
    return false;
}
