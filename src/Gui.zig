//! gui portion of the plugin. uses dvui

const clap = @import("clap-bindings");
const dvui = @import("dvui");
const Backend = @import("backend");

const Tonebender = @import("Tonebender.zig");

// will globals explode? yes
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

        backend = Backend.initWindow(.{
            .allocator = tonebender.allocator,
            .size = .{ .w = 800.0, .h = 600.0 },
            .min_size = .{ .w = 250.0, .h = 350.0 },
            .title = "joe mama",
            .vsync = false,
        }) catch unreachable;
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

        // no :)

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

        const size = backend.windowSize();
        width.* = @intFromFloat(size.w);
        height.* = @intFromFloat(size.h);

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

        if (wio_test_loop() catch false) {
            const host: *const clap.ext.gui.Host = @ptrCast(@alignCast(tonebender.host.getExtension(tonebender.host, clap.ext.gui.id)));
            host.closed(tonebender.host, true);
            return;
        }
    }

    //////////////////////////////////
    /// I LOVE STEALING
    //////////////////////////////////

    fn wio_test_loop() !bool {
        // beginWait coordinates with waitTime below to run frames only when needed
        const nstime = win.beginWait(true);

        // marks the beginning of a frame for dvui, can call dvui functions after this
        try win.begin(nstime);

        // send all SDL events to dvui for processing
        const quit = try backend.addAllEvents(&win);
        if (quit) return true;

        // if dvui widgets might not cover the whole window, then need to clear
        // the previous frame's render
        _ = Backend.c.SDL_SetRenderDrawColor(backend.renderer, 0, 0, 0, 255);
        _ = Backend.c.SDL_RenderClear(backend.renderer);

        const keep_running = gui_frame();
        if (!keep_running) return true;

        // marks end of dvui frame, don't call dvui functions after this
        // - sends all dvui stuff to backend for rendering, must be called before renderPresent()
        const end_micros = try win.end(.{});

        // cursor management
        try backend.setCursor(win.cursorRequested());
        try backend.textInputRect(win.textInputRequested());

        // render frame to OS
        try backend.renderPresent();

        // waitTime and beginWait combine to achieve variable framerates
        const wait_event_micros = win.waitTime(end_micros, null);
        _ = wait_event_micros; // autofix
        // _ = try backend.waitEventTimeout(wait_event_micros);

        return false;
    }

    // both dvui and SDL drawing
    // return false if user wants to exit the app
    fn gui_frame() bool {
        {
            var hbox = dvui.box(@src(), .{ .dir = .horizontal }, .{ .style = .window, .background = true, .expand = .horizontal });
            defer hbox.deinit();

            var m = dvui.menu(@src(), .horizontal, .{});
            defer m.deinit();

            if (dvui.menuItemLabel(@src(), "File", .{ .submenu = true }, .{})) |r| {
                var fw = dvui.floatingMenu(@src(), .{ .from = r }, .{});
                defer fw.deinit();

                if (dvui.menuItemLabel(@src(), "Close Menu", .{}, .{ .expand = .horizontal }) != null) {
                    m.close();
                }

                if (dvui.menuItemLabel(@src(), "Exit", .{}, .{ .expand = .horizontal }) != null) {
                    return false;
                }
            }

            if (dvui.menuItemLabel(@src(), "Edit", .{ .submenu = true }, .{})) |r| {
                var fw = dvui.floatingMenu(@src(), .{ .from = r }, .{});
                defer fw.deinit();
                _ = dvui.menuItemLabel(@src(), "Dummy", .{}, .{ .expand = .horizontal });
                _ = dvui.menuItemLabel(@src(), "Dummy Long", .{}, .{ .expand = .horizontal });
                _ = dvui.menuItemLabel(@src(), "Dummy Super Long", .{}, .{ .expand = .horizontal });
            }
        }

        var scroll = dvui.scrollArea(@src(), .{}, .{ .expand = .both });
        defer scroll.deinit();

        var tl = dvui.textLayout(@src(), .{}, .{ .expand = .horizontal, .font_style = .title_4 });
        const lorem = "This example shows how to use dvui in a normal application.";
        tl.addText(lorem, .{});
        tl.deinit();

        var tl2 = dvui.textLayout(@src(), .{}, .{ .expand = .horizontal });
        tl2.addText(
            \\DVUI
            \\- paints the entire window
            \\- can show floating windows and dialogs
            \\- example menu at the top of the window
            \\- rest of the window is a scroll area
        , .{});
        tl2.addText("\n\n", .{});
        tl2.addText("Framerate is variable and adjusts as needed for input events and animations.", .{});
        tl2.addText("\n\n", .{});
        if (true) {
            tl2.addText("Framerate is capped by vsync.", .{});
        } else {
            tl2.addText("Framerate is uncapped.", .{});
        }
        tl2.addText("\n\n", .{});
        tl2.addText("Cursor is always being set by dvui.", .{});
        tl2.addText("\n\n", .{});
        if (dvui.useFreeType) {
            tl2.addText("Fonts are being rendered by FreeType 2.", .{});
        } else {
            tl2.addText("Fonts are being rendered by stb_truetype.", .{});
        }
        tl2.deinit();

        const label = if (dvui.Examples.show_demo_window) "Hide Demo Window" else "Show Demo Window";
        if (dvui.button(@src(), label, .{}, .{})) {
            dvui.Examples.show_demo_window = !dvui.Examples.show_demo_window;
        }

        if (dvui.button(@src(), "Debug Window", .{}, .{})) {
            dvui.toggleDebugWindow();
        }

        {
            dvui.labelNoFmt(@src(), "Below is drawn directly by the backend, not going through DVUI.", .{}, .{ .margin = .{ .x = 4 } });

            var box = dvui.box(@src(), .{ .dir = .horizontal }, .{ .expand = .horizontal, .min_size_content = .{ .h = 40 }, .background = true, .margin = .{ .x = 8, .w = 8 } });
            defer box.deinit();

            // Here is some arbitrary drawing that doesn't have to go through DVUI.
            // It can be interleaved with DVUI drawing.
            // NOTE: This only works in the main window (not floating subwindows
            // like dialogs).

            // get the screen rectangle for the box
            const rs = box.data().contentRectScale();

            // rs.r is the pixel rectangle, rs.s is the scale factor (like for
            // hidpi screens or display scaling)
            var rect: if (Backend.sdl3) Backend.c.SDL_FRect else Backend.c.SDL_Rect = undefined;
            if (Backend.sdl3) rect = .{
                .x = (rs.r.x + 4 * rs.s),
                .y = (rs.r.y + 4 * rs.s),
                .w = (20 * rs.s),
                .h = (20 * rs.s),
            } else rect = .{
                .x = @intFromFloat(rs.r.x + 4 * rs.s),
                .y = @intFromFloat(rs.r.y + 4 * rs.s),
                .w = @intFromFloat(20 * rs.s),
                .h = @intFromFloat(20 * rs.s),
            };
            _ = Backend.c.SDL_SetRenderDrawColor(backend.renderer, 255, 0, 0, 255);
            _ = Backend.c.SDL_RenderFillRect(backend.renderer, &rect);

            rect.x += if (Backend.sdl3) 24 * rs.s else @intFromFloat(24 * rs.s);
            _ = Backend.c.SDL_SetRenderDrawColor(backend.renderer, 0, 255, 0, 255);
            _ = Backend.c.SDL_RenderFillRect(backend.renderer, &rect);

            rect.x += if (Backend.sdl3) 24 * rs.s else @intFromFloat(24 * rs.s);
            _ = Backend.c.SDL_SetRenderDrawColor(backend.renderer, 0, 0, 255, 255);
            _ = Backend.c.SDL_RenderFillRect(backend.renderer, &rect);

            _ = Backend.c.SDL_SetRenderDrawColor(backend.renderer, 255, 0, 255, 255);

            if (Backend.sdl3)
                _ = Backend.c.SDL_RenderLine(backend.renderer, (rs.r.x + 4 * rs.s), (rs.r.y + 30 * rs.s), (rs.r.x + rs.r.w - 8 * rs.s), (rs.r.y + 30 * rs.s))
            else
                _ = Backend.c.SDL_RenderDrawLine(backend.renderer, @intFromFloat(rs.r.x + 4 * rs.s), @intFromFloat(rs.r.y + 30 * rs.s), @intFromFloat(rs.r.x + rs.r.w - 8 * rs.s), @intFromFloat(rs.r.y + 30 * rs.s));
        }

        // look at demo() for examples of dvui widgets, shows in a floating window
        dvui.Examples.demo();

        return true;
    }
};
