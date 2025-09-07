//! using raylib backend as example since it is opengl-ish
//! see https://github.com/david-vanderson/dvui/blob/main/src/backends/raylib.zig
//! and https://github.com/david-vanderson/dvui/blob/main/src/backends/sdl.zig

const std = @import("std");
const builtin = @import("builtin");
const dvui = @import("dvui");
pub const wio = @import("wio");
const gl = @import("gl");

const Self = @This();

alloc: std.mem.Allocator,
win: wio.Window,
procs: *gl.ProcTable,
arena: std.mem.Allocator = undefined,

fn glGetProcAddress(comptime name: [*:0]const u8) ?gl.PROC {
    return wio.glGetProcAddress(std.mem.span(name));
}

const vertexSource =
    \\#version 330
    \\layout (location = 0) in vec2 vertexPosition;
    \\layout (location = 1) in vec4 vertexColor;
    \\layout (location = 2) in vec2 vertexTexCoord;
    \\out vec2 fragTexCoord;
    \\out vec4 fragColor;
    \\uniform mat4 mvp;
    \\void main()
    \\{
    \\    fragTexCoord = vertexTexCoord;
    \\    fragColor = vertexColor / 255.0;
    \\    gl_Position = mvp*vec4(vertexPosition, 0.0, 1.0);
    \\}
;

const fragmentSource =
    \\#version 330
    \\in vec2 fragTexCoord;
    \\in vec4 fragColor;
    \\out vec4 finalColor;
    \\uniform sampler2D texture0;
    \\uniform bool useTex;
    \\void main()
    \\{
    \\    if (useTex) {
    \\        finalColor = texture(texture0, fragTexCoord) * fragColor;
    \\    } else {
    \\        finalColor = fragColor;
    \\    }
    \\}
;

var useTex_loc: gl.int = undefined;

pub fn init(alloc: std.mem.Allocator, options: wio.CreateWindowOptions) !Self {
    try wio.init(alloc, .{}); // does global stuff. is that bad??
    errdefer wio.deinit();

    var win = try wio.createWindow(options);
    errdefer win.destroy();

    win.makeContextCurrent();
    win.swapInterval(1);

    var procs = try alloc.create(gl.ProcTable);
    errdefer alloc.destroy(procs);
    if (!procs.init(glGetProcAddress)) return error.InitFailed;
    gl.makeProcTableCurrent(procs);

    const vertex = gl.CreateShader(gl.VERTEX_SHADER);
    gl.ShaderSource(vertex, 1, @ptrCast(&vertexSource), null);
    gl.CompileShader(vertex);
    const fragment = gl.CreateShader(gl.FRAGMENT_SHADER);
    gl.ShaderSource(fragment, 1, @ptrCast(&fragmentSource), null);
    gl.CompileShader(fragment);
    const program = gl.CreateProgram();
    gl.AttachShader(program, vertex);
    gl.AttachShader(program, fragment);
    gl.LinkProgram(program);
    gl.DeleteShader(vertex);
    gl.DeleteShader(fragment);
    gl.UseProgram(program);

    var vao: gl.uint = undefined;
    gl.CreateVertexArrays(1, &vao);
    var vbo: gl.uint = undefined;
    gl.CreateBuffers(1, @ptrCast(&vbo));
    var ebo: gl.uint = undefined;
    gl.CreateBuffers(1, @ptrCast(&ebo));

    gl.BindVertexArray(vao);
    gl.BindBuffer(gl.ARRAY_BUFFER, vbo);
    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, ebo);

    gl.VertexAttribPointer(0, 2, gl.FLOAT, gl.FALSE, @sizeOf(dvui.Vertex), @offsetOf(dvui.Vertex, "pos"));
    gl.EnableVertexAttribArray(0);
    gl.VertexAttribPointer(1, 4, gl.FLOAT, gl.FALSE, @sizeOf(dvui.Vertex), @offsetOf(dvui.Vertex, "col"));
    gl.EnableVertexAttribArray(1);
    gl.VertexAttribPointer(2, 2, gl.FLOAT, gl.FALSE, @sizeOf(dvui.Vertex), @offsetOf(dvui.Vertex, "uv"));
    gl.EnableVertexAttribArray(2);

    useTex_loc = gl.GetUniformLocation(program, "useTex");

    gl.Enable(gl.BLEND);
    gl.BlendFunc(gl.ONE, gl.ONE_MINUS_SRC_ALPHA);
    gl.BlendEquation(gl.FUNC_ADD);

    return .{
        .alloc = alloc,
        .win = win,
        .procs = procs,
    };
}

pub fn deinit(self: *Self) void {
    // destroying the opengl context SHOULD delete all the resources, im just not going to care rn

    self.alloc.destroy(self.procs);
    gl.makeProcTableCurrent(null);

    self.win.destroy();
    wio.deinit();
}

pub fn backend(self: *Self) dvui.Backend {
    return dvui.Backend.init(self);
}

pub fn addAllEvents(self: *Self, win: *dvui.Window) !bool {
    _ = win;
    while (self.win.getEvent()) |event| {
        switch (event) {
            .close => return true,
            // TODO
            else => {},
        }
    }

    return false;
}

pub fn clear(_: *Self) void {
    gl.Clear(gl.COLOR_BUFFER_BIT);
}

pub fn setCursor(self: *Self, cursor: dvui.enums.Cursor) void {
    self.win.setCursor(switch (cursor) {
        .arrow, .arrow_all => .arrow,
        .wait_arrow => .arrow_busy,
        .wait => .busy,
        .bad => .forbidden,
        .hand => .hand,
        .ibeam => .text,
        .crosshair => .crosshair,
        .arrow_n_s => .size_ns,
        .arrow_ne_sw => .size_nesw,
        .arrow_nw_se => .size_nwse,
        .arrow_w_e => .size_ew,
    });
}

///////////////////////////////////////////////////////////

pub const kind = dvui.enums.Backend.custom;

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

pub fn end(self: *Self) void {
    // other backends put this elsewhere... idk why
    self.win.swapBuffers();

    wio.update();
}

pub fn drawClippedTriangles(_: *Self, texture: ?dvui.Texture, vtx: []const dvui.Vertex, idx: []const u16, maybe_clipr: ?dvui.Rect.Physical) !void {
    if (maybe_clipr) |clipr| {
        gl.Enable(gl.SCISSOR_TEST);
        gl.Scissor(@intFromFloat(clipr.x), @intFromFloat(clipr.y), @intFromFloat(clipr.w), @intFromFloat(clipr.h));
    }

    if (texture) |tex| {
        const gl_texture: gl.uint = @intCast(@intFromPtr(tex.ptr));
        gl.BindTexture(gl.TEXTURE_2D, gl_texture);
        gl.Uniform1i(useTex_loc, 1);
    } else {
        gl.BindTexture(gl.TEXTURE_2D, 0);
        gl.Uniform1i(useTex_loc, 0);
    }

    // TODO: do i want DYNAMIC_DRAW or STREAM_DRAW?
    gl.BufferData(gl.ARRAY_BUFFER, @intCast(@sizeOf(dvui.Vertex) * vtx.len), vtx.ptr, gl.STREAM_DRAW);
    gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, @intCast(@sizeOf(u16) * idx.len), idx.ptr, gl.STREAM_DRAW);

    gl.DrawElements(gl.TRIANGLES, @intCast(idx.len), gl.UNSIGNED_SHORT, 0);

    if (maybe_clipr) |_| {
        gl.Disable(gl.SCISSOR_TEST);
    }
    return undefined;
}

pub fn textureCreate(_: *Self, pixels: [*]const u8, width: u32, height: u32, interpolation: dvui.enums.TextureInterpolation) !dvui.Texture {
    const gl_interpolation: gl.int = if (interpolation == .linear) gl.LINEAR else gl.NEAREST;
    var texture: gl.uint = undefined;
    gl.CreateTextures(gl.TEXTURE_2D, 1, @ptrCast(&texture));
    gl.TextureParameteri(texture, gl.TEXTURE_MIN_FILTER, gl_interpolation);
    gl.TextureParameteri(texture, gl.TEXTURE_MAG_FILTER, gl_interpolation);
    gl.TextureStorage2D(texture, 1, gl.RGBA8, @intCast(width), @intCast(height));
    gl.TextureSubImage2D(texture, 0, 0, 0, @intCast(width), @intCast(height), gl.RGBA, gl.UNSIGNED_BYTE, pixels);

    return .{ .ptr = @ptrFromInt(texture), .width = width, .height = height };
}

pub fn textureUpdate(_: *Self, texture: dvui.Texture, pixels: [*]const u8) !void {
    const gl_texture: gl.uint = @intCast(@intFromPtr(texture.ptr));
    gl.TextureSubImage2D(gl_texture, 0, 0, 0, @intCast(texture.width), @intCast(texture.height), gl.RGBA, gl.UNSIGNED_BYTE, pixels);
}

pub fn textureDestroy(_: *Self, texture: dvui.Texture) void {
    const gl_texture: gl.uint = @intCast(@intFromPtr(texture.ptr));
    gl.DeleteTextures(1, @ptrCast(&gl_texture));
}

pub fn textureCreateTarget(_: *Self, width: u32, height: u32, interpolation: dvui.enums.TextureInterpolation) !dvui.TextureTarget {
    const gl_interpolation: gl.int = if (interpolation == .linear) gl.LINEAR else gl.NEAREST;
    var texture: gl.uint = undefined;
    gl.CreateTextures(gl.TEXTURE_2D, 1, @ptrCast(&texture));
    gl.TextureParameteri(texture, gl.TEXTURE_MIN_FILTER, gl_interpolation);
    gl.TextureParameteri(texture, gl.TEXTURE_MAG_FILTER, gl_interpolation);
    gl.TextureStorage2D(texture, 1, gl.RGBA8, @intCast(width), @intCast(height));

    var framebuffer: gl.uint = undefined;
    gl.CreateFramebuffers(1, @ptrCast(&framebuffer));
    gl.NamedFramebufferTexture(framebuffer, gl.COLOR_ATTACHMENT0, texture, 0);

    return .{ .ptr = @ptrFromInt(framebuffer), .width = width, .height = height };
}

pub fn textureFromTarget(_: *Self, texture: dvui.TextureTarget) dvui.Texture {
    const framebuffer: gl.uint = @intCast(@intFromPtr(texture.ptr));
    var gl_texture: gl.uint = undefined;
    gl.GetNamedFramebufferAttachmentParameteriv(framebuffer, gl.COLOR_ATTACHMENT0, gl.FRAMEBUFFER_ATTACHMENT_OBJECT_NAME, @ptrCast(&gl_texture));

    gl.DeleteFramebuffers(1, @ptrCast(&framebuffer));

    return .{ .ptr = @ptrFromInt(gl_texture), .width = texture.width, .height = texture.height };
}

pub fn textureReadTarget(_: *Self, texture: dvui.TextureTarget, pixels: [*]u8) !void {
    const framebuffer: gl.uint = @intCast(@intFromPtr(texture.ptr));
    var gl_texture: gl.uint = undefined;
    gl.GetNamedFramebufferAttachmentParameteriv(framebuffer, gl.COLOR_ATTACHMENT0, gl.FRAMEBUFFER_ATTACHMENT_OBJECT_NAME, @ptrCast(&gl_texture));

    gl.GetTextureImage(gl_texture, 0, gl.RGBA, gl.UNSIGNED_BYTE, @intCast(texture.width * texture.height * 4), pixels);
}

pub fn renderTarget(_: *Self, texture: ?dvui.TextureTarget) !void {
    const framebuffer: gl.uint = if (texture) |tex| @intCast(@intFromPtr(tex.ptr)) else 0;
    gl.BindFramebuffer(gl.FRAMEBUFFER, framebuffer);
}

pub fn clipboardText(self: *Self) ![]const u8 {
    return self.win.getClipboardText(self.arena) orelse error.BackendError;
}

pub fn clipboardTextSet(self: *Self, text: []const u8) !void {
    self.win.setClipboardText(text);
}

pub fn openURL(_: *Self, _: []const u8) !void {} // no

pub fn preferredColorScheme(_: *Self) ?dvui.enums.ColorScheme {
    if (builtin.target.os.tag == .windows) {
        return dvui.Backend.Common.windowsGetPreferredColorScheme();
    }
    return null;
}

pub fn cursorShow(self: *Self, value: ?bool) !bool {
    if (value) |val| {
        self.win.setCursorMode(if (val) .normal else .hidden);
    }
    return undefined; // TODO
}

pub fn refresh(_: *Self) void {} // not used probably
