const clap = @import("clap-bindings");

// const dvui = @import("dvui");
// const Backend = @import("backend");
const wio = @import("wio");

const ClapDemo = @import("ClapDemo.zig");

// var backend: ?Backend = null;
// var win: ?dvui.Window = null;
// var interrupted: bool = false;
var win: wio.Window = undefined;
var timerId: clap.Id = undefined;

pub const gui = struct {
    pub const extension = clap.ext.gui.Plugin{
        .create = create,
        .destroy = destroy,
        .setParent = setParent,
        .adjustSize = adjustSize,
        .canResize = canResize,
        .getPreferredApi = getPreferredApi,
        .getResizeHints = getResizeHints,
        .getSize = getSize,
        .hide = hide,
        .isApiSupported = isApiSupported,
        .setScale = setScale,
        .setSize = setSize,
        .setTransient = setTransient,
        .show = show,
        .suggestTitle = suggestTitle,
    };

    fn create(plugin: *const clap.Plugin, api: ?[*:0]const u8, is_floating: bool) callconv(.C) bool {
        var clap_demo = ClapDemo.fromPlugin(plugin);
        clap_demo.log("create {?s} {}", .{ api, is_floating });

        wio.init(clap_demo.allocator, .{}) catch unreachable;
        win = wio.createWindow(.{}) catch unreachable;

        return is_floating == false;
    }

    fn destroy(plugin: *const clap.Plugin) callconv(.C) void {
        var clap_demo = ClapDemo.fromPlugin(plugin);
        clap_demo.log("destroy", .{});

        win.destroy();
        wio.deinit();

        // backend.?.deinit();
        // backend = null;

        clap_demo.log("closing da plugin", .{});
    }

    fn setParent(plugin: *const clap.Plugin, window: *const clap.ext.gui.Window) callconv(.C) bool {
        var clap_demo = ClapDemo.fromPlugin(plugin);
        clap_demo.log("setParent {}", .{window.*});

        // const props = Backend.c.SDL_CreateProperties();
        // defer Backend.c.SDL_DestroyProperties(props);
        // _ = Backend.c.SDL_SetPointerProperty(props, Backend.c.SDL_PROP_WINDOW_CREATE_COCOA_WINDOW_POINTER, window.data.ptr);
        // _ = Backend.c.SDL_SetPointerProperty(props, Backend.c.SDL_PROP_WINDOW_CREATE_WAYLAND_WL_SURFACE_POINTER, window.data.ptr);
        // _ = Backend.c.SDL_SetPointerProperty(props, Backend.c.SDL_PROP_WINDOW_CREATE_WIN32_HWND_POINTER, window.data.ptr);
        // _ = Backend.c.SDL_SetPointerProperty(props, Backend.c.SDL_PROP_WINDOW_CREATE_X11_WINDOW_NUMBER, window.data.ptr);
        // const sdl_window = Backend.c.SDL_CreateWindowWithProperties(props).?;

        // const renderer = Backend.c.SDL_CreateRenderer(sdl_window, null).?;

        // backend = Backend.init(sdl_window, renderer);
        // backend.?.we_own_window = true;

        // win = dvui.Window.init(@src(), clap_demo.allocator, backend.?.backend(), .{}) catch unreachable;

        win.setParent(@intFromPtr(window.data.ptr));

        return true;
    }

    fn isApiSupported(plugin: *const clap.Plugin, api: [*:0]const u8, is_floating: bool) callconv(.C) bool {
        var clap_demo = ClapDemo.fromPlugin(plugin);
        clap_demo.log("isApiSupported {s} {}", .{ api, is_floating });
        return true;
    }
    fn getPreferredApi(plugin: *const clap.Plugin, api: *[*:0]const u8, is_floating: *bool) callconv(.C) bool {
        var clap_demo = ClapDemo.fromPlugin(plugin);

        api.* = clap.ext.gui.window_api.wayland;
        is_floating.* = false;

        clap_demo.log("getPreferredApi {s} {}", .{ api, is_floating });
        return true;
    }
    fn setScale(plugin: *const clap.Plugin, scale: f64) callconv(.C) bool {
        var clap_demo = ClapDemo.fromPlugin(plugin);
        clap_demo.log("setScale {}", .{scale});
        return false;
    }
    fn getSize(plugin: *const clap.Plugin, width: *u32, height: *u32) callconv(.C) bool {
        var clap_demo = ClapDemo.fromPlugin(plugin);

        width.* = 640;
        height.* = 480;

        clap_demo.log("getSize {} {}", .{ width.*, height.* });
        return true;
    }
    fn canResize(plugin: *const clap.Plugin) callconv(.C) bool {
        var clap_demo = ClapDemo.fromPlugin(plugin);
        clap_demo.log("canResize", .{});
        return false;
    }
    fn getResizeHints(plugin: *const clap.Plugin, hints: *clap.ext.gui.ResizeHints) callconv(.C) bool {
        var clap_demo = ClapDemo.fromPlugin(plugin);
        clap_demo.log("getResizeHints {}", .{hints.*});
        return false;
    }
    fn adjustSize(plugin: *const clap.Plugin, width: *u32, height: *u32) callconv(.C) bool {
        var clap_demo = ClapDemo.fromPlugin(plugin);
        clap_demo.log("adjustSize {} {}", .{ width.*, height.* });

        return getSize(plugin, width, height);
    }
    fn setSize(plugin: *const clap.Plugin, width: u32, height: u32) callconv(.C) bool {
        var clap_demo = ClapDemo.fromPlugin(plugin);
        clap_demo.log("setSize {} {}", .{ width, height });
        return true;
    }
    fn setTransient(plugin: *const clap.Plugin, window: *const clap.ext.gui.Window) callconv(.C) bool {
        var clap_demo = ClapDemo.fromPlugin(plugin);
        clap_demo.log("setTransient {}", .{window.*});
        return false;
    }
    fn suggestTitle(plugin: *const clap.Plugin, title: [*:0]const u8) callconv(.C) bool {
        var clap_demo = ClapDemo.fromPlugin(plugin);
        clap_demo.log("suggestTitle {s}", .{title});
        return false;
    }
    fn show(plugin: *const clap.Plugin) callconv(.C) bool {
        var clap_demo = ClapDemo.fromPlugin(plugin);
        clap_demo.log("show", .{});
        // TODO
        return true;
    }
    fn hide(plugin: *const clap.Plugin) callconv(.C) bool {
        var clap_demo = ClapDemo.fromPlugin(plugin);
        clap_demo.log("hide", .{});
        // TODO
        return true;
    }
};

pub const timer_support = struct {
    pub const extension = clap.ext.timer_support.Plugin{
        .onTimer = onTimer,
    };

    pub fn registerTimer(clap_demo: *ClapDemo) void {
        const host: *const clap.ext.timer_support.Host = @alignCast(@ptrCast(clap_demo.host.getExtension(clap_demo.host, clap.ext.timer_support.id)));
        _ = host.registerTimer(clap_demo.host, 1000 / 60, &timerId);
    }
    pub fn unregisterTimer(clap_demo: *ClapDemo) void {
        const host: *const clap.ext.timer_support.Host = @alignCast(@ptrCast(clap_demo.host.getExtension(clap_demo.host, clap.ext.timer_support.id)));
        _ = host.unregisterTimer(clap_demo.host, timerId);
    }

    fn onTimer(plugin: *const clap.Plugin, timer_id: clap.Id) callconv(.C) void {
        const clap_demo = ClapDemo.fromPlugin(plugin);
        _ = clap_demo;
        _ = timer_id;

        wio.update();
        wio.wait();
        // try_onTimer(clap_demo) catch unreachable;
    }

    fn try_onTimer(clap_demo: *ClapDemo) !void {
        _ = clap_demo;
    }
};
