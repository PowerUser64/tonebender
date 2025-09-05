const std = @import("std");
const wio = @import("wio");
const gl = @import("gl");

var win: wio.Window = undefined;
var procs: gl.ProcTable = undefined;

pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}).init;
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    try wio.init(alloc, .{});
    defer wio.deinit();

    win = try wio.createWindow(.{
        .opengl = .{ .major_version = 4, .minor_version = 6 },
    });
    defer win.destroy();

    win.makeContextCurrent();
    win.swapInterval(1);

    if (!procs.init(glGetProcAddress)) return error.ProcInitfailed;
    gl.makeProcTableCurrent(&procs);
    defer gl.makeProcTableCurrent(null);

    try wio.run(loop);
}

fn glGetProcAddress(comptime name: [*:0]const u8) ?gl.PROC {
    return wio.glGetProcAddress(std.mem.span(name));
}

fn loop() !bool {
    while (win.getEvent()) |event| {
        if (event == .mouse) continue;
        std.log.info("{}", .{event});
    }

    gl.ClearColor(1, 0, 0, 1);
    gl.Clear(gl.COLOR_BUFFER_BIT);

    win.swapBuffers();

    // wio.wait();
    return true;
}
