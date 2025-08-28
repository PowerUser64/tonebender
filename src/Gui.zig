const clap = @import("clap-bindings");

const dvui = @import("dvui");
const Backend = @import("backend");
const wio = @import("wio");

const ClapDemo = @import("ClapDemo.zig");

var backend: ?Backend = null;
var win: ?dvui.Window = null;
var interrupted: bool = false;

pub const gui = struct {
    pub const extension = clap.ext.gui.Plugin{
        .create = gui_create,
        .destroy = gui_destroy,
        .setParent = gui_setParent,
        .adjustSize = gui_adjustSize,
        .canResize = gui_canResize,
        .getPreferredApi = gui_getPreferredApi,
        .getResizeHints = gui_getResizeHints,
        .getSize = gui_getSize,
        .hide = gui_hide,
        .isApiSupported = gui_isApiSupported,
        .setScale = gui_setScale,
        .setSize = gui_setSize,
        .setTransient = gui_setTransient,
        .show = gui_show,
        .suggestTitle = gui_suggestTitle,
    };

    fn gui_create(plugin: *const clap.Plugin, api: ?[*:0]const u8, is_floating: bool) callconv(.C) bool {
        var clap_demo = ClapDemo.fromPlugin(plugin);
        clap_demo.log("gui_create {?s} {}", .{ api, is_floating });

        return is_floating == false;
    }

    fn gui_destroy(plugin: *const clap.Plugin) callconv(.C) void {
        var clap_demo = ClapDemo.fromPlugin(plugin);
        clap_demo.log("gui_destroy", .{});

        win.?.deinit();
        win = null;

        backend.?.deinit();
        backend = null;

        clap_demo.log("closing da plugin", .{});
    }

    fn gui_setParent(plugin: *const clap.Plugin, window: *const clap.ext.gui.Window) callconv(.C) bool {
        var clap_demo = ClapDemo.fromPlugin(plugin);
        clap_demo.log("gui_setParent {}", .{window.*});

        const props = Backend.c.SDL_CreateProperties();
        defer Backend.c.SDL_DestroyProperties(props);
        _ = Backend.c.SDL_SetPointerProperty(props, Backend.c.SDL_PROP_WINDOW_CREATE_COCOA_WINDOW_POINTER, window.data.ptr);
        _ = Backend.c.SDL_SetPointerProperty(props, Backend.c.SDL_PROP_WINDOW_CREATE_WAYLAND_WL_SURFACE_POINTER, window.data.ptr);
        _ = Backend.c.SDL_SetPointerProperty(props, Backend.c.SDL_PROP_WINDOW_CREATE_WIN32_HWND_POINTER, window.data.ptr);
        _ = Backend.c.SDL_SetPointerProperty(props, Backend.c.SDL_PROP_WINDOW_CREATE_X11_WINDOW_NUMBER, window.data.ptr);
        const sdl_window = Backend.c.SDL_CreateWindowWithProperties(props).?;

        const renderer = Backend.c.SDL_CreateRenderer(sdl_window, null).?;

        backend = Backend.init(sdl_window, renderer);
        backend.?.we_own_window = true;

        win = dvui.Window.init(@src(), clap_demo.allocator, backend.?.backend(), .{}) catch unreachable;

        return true;
    }

    fn gui_isApiSupported(plugin: *const clap.Plugin, api: [*:0]const u8, is_floating: bool) callconv(.C) bool {
        var clap_demo = ClapDemo.fromPlugin(plugin);
        clap_demo.log("gui_isApiSupported {s} {}", .{ api, is_floating });
        return true;
    }
    fn gui_getPreferredApi(plugin: *const clap.Plugin, api: *[*:0]const u8, is_floating: *bool) callconv(.C) bool {
        var clap_demo = ClapDemo.fromPlugin(plugin);

        api.* = clap.ext.gui.window_api.wayland;
        is_floating.* = false;

        clap_demo.log("gui_getPreferredApi {s} {}", .{ api, is_floating });
        return true;
    }
    fn gui_setScale(plugin: *const clap.Plugin, scale: f64) callconv(.C) bool {
        var clap_demo = ClapDemo.fromPlugin(plugin);
        clap_demo.log("gui_setScale {}", .{scale});
        return false;
    }
    fn gui_getSize(plugin: *const clap.Plugin, width: *u32, height: *u32) callconv(.C) bool {
        var clap_demo = ClapDemo.fromPlugin(plugin);

        width.* = 640;
        height.* = 480;

        clap_demo.log("gui_getSize {} {}", .{ width.*, height.* });
        return true;
    }
    fn gui_canResize(plugin: *const clap.Plugin) callconv(.C) bool {
        var clap_demo = ClapDemo.fromPlugin(plugin);
        clap_demo.log("gui_canResize", .{});
        return false;
    }
    fn gui_getResizeHints(plugin: *const clap.Plugin, hints: *clap.ext.gui.ResizeHints) callconv(.C) bool {
        var clap_demo = ClapDemo.fromPlugin(plugin);
        clap_demo.log("gui_getResizeHints {}", .{hints.*});
        return false;
    }
    fn gui_adjustSize(plugin: *const clap.Plugin, width: *u32, height: *u32) callconv(.C) bool {
        var clap_demo = ClapDemo.fromPlugin(plugin);
        clap_demo.log("gui_adjustSize {} {}", .{ width.*, height.* });

        return gui_getSize(plugin, width, height);
    }
    fn gui_setSize(plugin: *const clap.Plugin, width: u32, height: u32) callconv(.C) bool {
        var clap_demo = ClapDemo.fromPlugin(plugin);
        clap_demo.log("gui_setSize {} {}", .{ width, height });
        return true;
    }
    fn gui_setTransient(plugin: *const clap.Plugin, window: *const clap.ext.gui.Window) callconv(.C) bool {
        var clap_demo = ClapDemo.fromPlugin(plugin);
        clap_demo.log("gui_setTransient {}", .{window.*});
        return false;
    }
    fn gui_suggestTitle(plugin: *const clap.Plugin, title: [*:0]const u8) callconv(.C) bool {
        var clap_demo = ClapDemo.fromPlugin(plugin);
        clap_demo.log("gui_suggestTitle {s}", .{title});
        return false;
    }
    fn gui_show(plugin: *const clap.Plugin) callconv(.C) bool {
        var clap_demo = ClapDemo.fromPlugin(plugin);
        clap_demo.log("gui_show", .{});
        // TODO
        return true;
    }
    fn gui_hide(plugin: *const clap.Plugin) callconv(.C) bool {
        var clap_demo = ClapDemo.fromPlugin(plugin);
        clap_demo.log("gui_hide", .{});
        // TODO
        return true;
    }
};

pub const timer_support = struct {
    pub const extension = clap.ext.timer_support.Plugin{
        .onTimer = onTimer,
    };

    fn onTimer(plugin: *const clap.Plugin, timer_id: clap.Id) callconv(.C) void {
        const clap_demo = ClapDemo.fromPlugin(plugin);
        _ = timer_id;

        do_frame(clap_demo) catch unreachable;
    }

    fn do_frame(clap_demo: *ClapDemo) !void {
        _ = clap_demo;
        // var backend = clap_demo.backend.?;
        // var win = clap_demo.win.?;

        // copied from dvui example

        // beginWait coordinates with waitTime below to run frames only when needed
        const nstime = win.?.beginWait(interrupted);

        // marks the beginning of a frame for dvui, can call dvui functions after this
        try win.?.begin(nstime);

        // send all SDL events to dvui for processing
        const quit = try backend.?.addAllEvents(&win.?);
        _ = quit;

        // if dvui widgets might not cover the whole window, then need to clear
        // the previous frame's render
        _ = Backend.c.SDL_SetRenderDrawColor(backend.?.renderer, 0, 0, 0, 255);
        _ = Backend.c.SDL_RenderClear(backend.?.renderer);

        // const keep_running = gui_frame();
        // if (!keep_running) break :main_loop;

        // marks end of dvui frame, don't call dvui functions after this
        // - sends all dvui stuff to backend for rendering, must be called before renderPresent()
        const end_micros = try win.?.end(.{});

        // cursor management
        try backend.?.setCursor(win.?.cursorRequested());
        try backend.?.textInputRect(win.?.textInputRequested());

        // render frame to OS
        try backend.?.renderPresent();

        // waitTime and beginWait combine to achieve variable framerates
        const wait_event_micros = win.?.waitTime(end_micros, null);
        interrupted = try backend.?.waitEventTimeout(wait_event_micros);

        // Example of how to show a dialog from another thread (outside of win.begin/win.end)
        // if (show_dialog_outside_frame) {
        //     show_dialog_outside_frame = false;
        //     dvui.dialog(@src(), .{}, .{ .window = &win, .modal = false, .title = "Dialog from Outside", .message = "This is a non modal dialog that was created outside win.begin()/win.end(), usually from another thread." });
        // }

    }
};
