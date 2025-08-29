const std = @import("std");
const builtin = @import("builtin");
const dvui = @import("dvui");
pub const wio = @import("wio");

const Self = @This();

alloc: std.mem.Allocator,
win: wio.Window,

pub fn init(alloc: std.mem.Allocator, options: wio.CreateWindowOptions) !Self {
    try wio.init(alloc, .{});
    var win = try wio.createWindow(options);

    win.makeContextCurrent();
    win.swapInterval(1);

    return .{
        .alloc = alloc,
        .win = win,
    };
}

pub fn deinit(self: *Self) void {
    self.win.destroy();
    wio.deinit();
}

pub fn backend(self: *Self) dvui.Backend {
    return dvui.Backend.init(self);
}

pub fn pixelSize(_: *Self) dvui.Size.Physical {
    return .{ .w = 640, .h = 480 };
}
pub fn windowSize(_: *Self) dvui.Size.Natural {
    return .{ .w = 640, .h = 480 };
}
pub fn contentScale(_: *Self) f32 {
    return 1;
}
pub fn textureDestroy(_: *Self, _: dvui.Texture) void {}
pub fn preferredColorScheme(_: *Self) ?dvui.enums.ColorScheme {
    if (builtin.target.os.tag == .windows) {
        return dvui.Backend.Common.windowsGetPreferredColorScheme();
    }
    return null;
}
