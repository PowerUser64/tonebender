// using raylib backend as example since it is opengl-ish

const std = @import("std");
const builtin = @import("builtin");
const dvui = @import("dvui");
pub const wio = @import("wio");
const gl = @import("zgl");

const Self = @This();

alloc: std.mem.Allocator,
win: wio.Window,
arena: std.mem.Allocator = undefined,
vao: gl.VertexArray,

fn glGetProcAddress(_: anytype, comptime name: [:0]const u8) gl.binding.FunctionPointer {
    return wio.glGetProcAddress(name);
}

pub fn init(alloc: std.mem.Allocator, options: wio.CreateWindowOptions) !Self {
    try wio.init(alloc, .{});
    var win = try wio.createWindow(options);

    win.makeContextCurrent();
    win.swapInterval(1);

    gl.loadExtensions(void, glGetProcAddress) catch unreachable;

    // TODO: setup vertex format
    const vao = gl.VertexArray.create();

    return .{
        .alloc = alloc,
        .win = win,
        .vao = vao,
    };
}

pub fn deinit(self: *Self) void {
    self.vao.delete();

    self.win.destroy();
    wio.deinit();
}

pub fn backend(self: *Self) dvui.Backend {
    return dvui.Backend.init(self);
}

//////////////////////////////////////////

pub fn nanoTime(_: *Self) i128 {
    return std.time.nanoTimestamp();
}
pub fn sleep(_: *Self, ns: u64) void {
    std.time.sleep(ns);
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

pub fn begin(self: *Self, arena: std.mem.Allocator) void {
    self.arena = arena;
}
pub fn end(_: *Self) void {}

pub fn drawClippedTriangles(_: *Self, _: ?dvui.Texture, _: []const dvui.Vertex, _: []const u16, _: ?dvui.Rect.Physical) !void {
    return undefined;
}

pub fn textureCreate(_: *Self, _: [*]const u8, _: u32, _: u32, _: dvui.enums.TextureInterpolation) !dvui.Texture {
    return undefined;
}

pub fn textureDestroy(_: *Self, _: dvui.Texture) void {}

pub fn clipboardText(self: *Self) ![]const u8 {
    return self.win.getClipboardText(self.arena) orelse error.BackendError;
}

pub fn clipboardTextSet(self: *Self, text: []const u8) !void {
    self.win.setClipboardText(text);
}

pub fn preferredColorScheme(_: *Self) ?dvui.enums.ColorScheme {
    if (builtin.target.os.tag == .windows) {
        return dvui.Backend.Common.windowsGetPreferredColorScheme();
    }
    return null;
}

pub fn refresh(_: *Self) void {}
