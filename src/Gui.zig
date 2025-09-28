//! gui portion of the plugin. uses dvui

const clap = @import("clap-bindings");
const dvui = @import("dvui");
const Backend = @import("backend");

const Tonebender = @import("Tonebender.zig");

// will globals explode? idk
var win: dvui.Window = undefined;
var backend: Backend = undefined;
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
        var tonebender = Tonebender.fromPlugin(plugin);
        tonebender.log("create {?s} {}", .{ api, is_floating });

        backend = Backend.init(tonebender.allocator, .{ .opengl = .{ .major_version = 4, .minor_version = 6 } }) catch unreachable;
        win = dvui.Window.init(@src(), tonebender.allocator, backend.backend(), .{}) catch unreachable;
        timer_support.registerTimer(tonebender);

        return true;
    }

    fn destroy(plugin: *const clap.Plugin) callconv(.C) void {
        var tonebender = Tonebender.fromPlugin(plugin);
        tonebender.log("destroy", .{});

        timer_support.unregisterTimer(tonebender);
        win.deinit();
        backend.deinit();
    }

    fn setParent(plugin: *const clap.Plugin, window: *const clap.ext.gui.Window) callconv(.C) bool {
        var tonebender = Tonebender.fromPlugin(plugin);
        tonebender.log("setParent {s} {}", .{ window.api, window.data.ptr });

        backend.win.setParent(@intFromPtr(window.data.ptr));

        return true;
    }

    fn isApiSupported(plugin: *const clap.Plugin, api: [*:0]const u8, is_floating: bool) callconv(.C) bool {
        var tonebender = Tonebender.fromPlugin(plugin);
        tonebender.log("isApiSupported {s} {}", .{ api, is_floating });
        return is_floating == true;
    }
    fn getPreferredApi(plugin: *const clap.Plugin, api: *[*:0]const u8, is_floating: *bool) callconv(.C) bool {
        var tonebender = Tonebender.fromPlugin(plugin);

        api.* = clap.ext.gui.window_api.wayland;
        is_floating.* = true;

        tonebender.log("getPreferredApi {s} {}", .{ api.*, is_floating.* });
        return true;
    }
    fn setScale(plugin: *const clap.Plugin, scale: f64) callconv(.C) bool {
        var tonebender = Tonebender.fromPlugin(plugin);
        tonebender.log("setScale {}", .{scale});
        return false;
    }
    fn getSize(plugin: *const clap.Plugin, width: *u32, height: *u32) callconv(.C) bool {
        var tonebender = Tonebender.fromPlugin(plugin);

        width.* = backend.size.width;
        height.* = backend.size.height;

        tonebender.log("getSize {} {}", .{ width.*, height.* });
        return true;
    }
    fn canResize(plugin: *const clap.Plugin) callconv(.C) bool {
        var tonebender = Tonebender.fromPlugin(plugin);
        tonebender.log("canResize", .{});
        return false;
    }
    fn getResizeHints(plugin: *const clap.Plugin, hints: *clap.ext.gui.ResizeHints) callconv(.C) bool {
        var tonebender = Tonebender.fromPlugin(plugin);
        tonebender.log("getResizeHints {}", .{hints.*});
        return false;
    }
    fn adjustSize(plugin: *const clap.Plugin, width: *u32, height: *u32) callconv(.C) bool {
        var tonebender = Tonebender.fromPlugin(plugin);
        tonebender.log("adjustSize {} {}", .{ width.*, height.* });

        return getSize(plugin, width, height);
    }
    fn setSize(plugin: *const clap.Plugin, width: u32, height: u32) callconv(.C) bool {
        var tonebender = Tonebender.fromPlugin(plugin);
        tonebender.log("setSize {} {}", .{ width, height });
        return true;
    }
    fn setTransient(plugin: *const clap.Plugin, window: *const clap.ext.gui.Window) callconv(.C) bool {
        var tonebender = Tonebender.fromPlugin(plugin);
        tonebender.log("setTransient {s} {}", .{ window.api, window.data.ptr });
        return false;
    }
    fn suggestTitle(plugin: *const clap.Plugin, title: [*:0]const u8) callconv(.C) bool {
        var tonebender = Tonebender.fromPlugin(plugin);
        tonebender.log("suggestTitle {s}", .{title});
        return false;
    }
    fn show(plugin: *const clap.Plugin) callconv(.C) bool {
        var tonebender = Tonebender.fromPlugin(plugin);
        tonebender.log("show", .{});
        // TODO
        return true;
    }
    fn hide(plugin: *const clap.Plugin) callconv(.C) bool {
        var tonebender = Tonebender.fromPlugin(plugin);
        tonebender.log("hide", .{});
        // TODO
        return true;
    }
};

pub const timer_support = struct {
    pub const extension = clap.ext.timer_support.Plugin{
        .onTimer = onTimer,
    };

    pub fn registerTimer(tonebender: *Tonebender) void {
        const host: *const clap.ext.timer_support.Host = @ptrCast(@alignCast(tonebender.host.getExtension(tonebender.host, clap.ext.timer_support.id)));
        _ = host.registerTimer(tonebender.host, 1000 / 60, &timerId);
    }
    pub fn unregisterTimer(tonebender: *Tonebender) void {
        const host: *const clap.ext.timer_support.Host = @ptrCast(@alignCast(tonebender.host.getExtension(tonebender.host, clap.ext.timer_support.id)));
        _ = host.unregisterTimer(tonebender.host, timerId);
    }

    fn onTimer(plugin: *const clap.Plugin, timer_id: clap.Id) callconv(.C) void {
        const tonebender = Tonebender.fromPlugin(plugin);
        _ = timer_id;
        // tonebender.log("timer", .{});

        win.begin(0) catch unreachable;

        const quit = backend.addAllEvents(&win) catch unreachable;
        if (quit) {
            const host: *const clap.ext.gui.Host = @ptrCast(@alignCast(tonebender.host.getExtension(tonebender.host, clap.ext.gui.id)));
            host.closed(tonebender.host, true);
            return;
        }

        backend.clear();
        dvui.Examples.demo();

        _ = win.end(.{}) catch unreachable;

        backend.setCursor(win.cursorRequested());
    }
};
