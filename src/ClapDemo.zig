const std = @import("std");
const clap = @import("clap-bindings");

// const Gui = @import("Gui.zig");

const c = @cImport({
    @cInclude("mydsp.gen.c");
    @cInclude("faust.h");
    @cInclude("faust_prints.c");
});

pub const desc = clap.Plugin.Descriptor{
    .clap_version = clap.version,
    .id = "com.interpunct.clap-demo",
    .name = "clap demo synth",
    .vendor = "interpunct",
    .url = "eva.fish",
    .manual_url = "",
    .support_url = "",
    .version = "1.0.0",
    .description = "a simple synth to show some CLAP features.",
    .features = &[_:null]?[*:0]const u8{
        clap.Plugin.features.instrument,
        clap.Plugin.features.synthesizer,
        null,
    },
};

allocator: std.mem.Allocator,
plugin: clap.Plugin,
host: *const clap.Host,
sample_rate: ?f64 = null,

dsp: [*c]c.mydsp,

pub fn fromPlugin(plugin: *const clap.Plugin) *@This() {
    return @ptrCast(@alignCast(plugin.plugin_data));
}

pub fn create(host: *const clap.Host, allocator: std.mem.Allocator) !*const clap.Plugin {
    const clap_demo = try allocator.create(@This());
    errdefer allocator.destroy(clap_demo);
    clap_demo.* = .{
        .allocator = allocator,
        .plugin = .{
            .descriptor = &desc,
            .plugin_data = clap_demo,
            .init = init,
            .destroy = destroy,
            .activate = activate,
            .deactivate = deactivate,
            .startProcessing = startProcessing,
            .stopProcessing = stopProcessing,
            .reset = reset,
            .process = process,
            .getExtension = getExtension,
            .onMainThread = onMainThread,
        },
        .host = host,
        // we set these in the init function
        .dsp = undefined,
    };
    return &clap_demo.plugin;
}

fn init(plugin: *const clap.Plugin) callconv(.C) bool {
    var clap_demo = fromPlugin(plugin);

    clap_demo.dsp = c.newmydsp();

    return true;
}

fn destroy(plugin: *const clap.Plugin) callconv(.C) void {
    var clap_demo = fromPlugin(plugin);

    c.deletemydsp(clap_demo.dsp);

    clap_demo.allocator.destroy(clap_demo);
}

fn activate(
    plugin: *const clap.Plugin,
    sample_rate: f64,
    _: u32,
    _: u32,
) callconv(.C) bool {
    var clap_demo = fromPlugin(plugin);
    c.initmydsp(clap_demo.dsp, @intFromFloat(@round(sample_rate)));
    clap_demo.sample_rate = sample_rate;
    return true;
}

fn deactivate(_: *const clap.Plugin) callconv(.C) void {}

fn startProcessing(_: *const clap.Plugin) callconv(.C) bool {
    return true;
}

fn stopProcessing(_: *const clap.Plugin) callconv(.C) void {}

fn reset(_: *const clap.Plugin) callconv(.C) void {}

fn process(plugin: *const clap.Plugin, clap_process: *const clap.Process) callconv(.C) clap.Process.Status {
    // nothing to do with no outputs
    if (clap_process.audio_outputs_count <= 0) {
        return .sleep;
    }

    const clap_demo = fromPlugin(plugin);

    const out = clap_process.audio_outputs[0].data32.?;
    const channel_count = clap_process.audio_outputs[0].channel_count;
    _ = channel_count; // autofix

    const events = clap_process.in_events;
    const event_count = events.size(events);
    _ = event_count; // autofix

    c.computemydsp(
        clap_demo.dsp,
        @intCast(clap_process.frames_count),
        null,
        @ptrCast(out),
    );

    // for (out[0..channel_count]) |channel| {
    //     for (channel, 0..clap_process.frames_count) |*frame, i| {
    //         std.log.debug("sample {}: {}", .{ i, frame.* });
    //     }
    // }

    return .@"continue";
}

fn handleInboundEvent(clap_demo: *@This(), event_header: *const clap.events.Header) void {
    _ = clap_demo; // autofix

    if (event_header.space_id != clap.events.core_space_id) {
        return;
    }
}

fn scaleTime(time: f64) f64 {
    return @exp2(6 * time - 4);
}

fn unscaleTime(time: f64) f64 {
    return (@log2(time) + 4) / 6;
}

fn eql(a: [*:0]const u8, b: [*:0]const u8) bool {
    return std.mem.orderZ(u8, a, b) == .eq;
}

fn getExtension(_: *const clap.Plugin, id: [*:0]const u8) callconv(.C) ?*const anyopaque {
    if (eql(clap.ext.note_ports.id, id)) {
        return &note_ports.extension;
    } else if (eql(clap.ext.audio_ports.id, id)) {
        return &audio_ports.extension;
    } else if (eql(clap.ext.voice_info.id, id)) {
        return null; //&voice_info.extension;
    } else if (eql(clap.ext.state.id, id)) {
        return null; //&state.extension;
    } else if (eql(clap.ext.params.id, id)) {
        return null; //&params.extension;
    } else if (eql(clap.ext.gui.id, id)) {
        return null; //&Gui.gui.extension;
    } else if (eql(clap.ext.timer_support.id, id)) {
        return null; //&Gui.timer_support.extension;
    } else {
        return null;
    }
}

fn onMainThread(_: *const clap.Plugin) callconv(.C) void {}

const note_ports = struct {
    const extension = clap.ext.note_ports.Plugin{
        .count = count,
        .get = get,
    };

    fn count(_: *const clap.Plugin, is_input: bool) callconv(.C) u32 {
        return switch (is_input) {
            true => 0,
            false => 0,
        };
    }

    fn get(
        _: *const clap.Plugin,
        index: u32,
        is_input: bool,
        info: *clap.ext.note_ports.Info,
    ) callconv(.C) bool {
        if (is_input and index == 0) {
            info.* = .{
                .id = @enumFromInt(0),
                .supported_dialects = .{ .clap = true },
                .preferred_dialect = .clap,
                .name = undefined,
            };
            _ = std.fmt.bufPrintZ(&info.name, "{s}", .{"Note Port"}) catch unreachable;
            return true;
        } else {
            return false;
        }
    }
};

const audio_ports = struct {
    const extension = clap.ext.audio_ports.Plugin{
        .count = count,
        .get = get,
    };

    fn count(_: *const clap.Plugin, is_input: bool) callconv(.C) u32 {
        return switch (is_input) {
            true => 0,
            false => 1,
        };
    }

    fn get(
        _: *const clap.Plugin,
        index: u32,
        is_input: bool,
        info: *clap.ext.audio_ports.Info,
    ) callconv(.C) bool {
        if (!is_input and index == 0) {
            info.* = .{
                .id = @enumFromInt(0),
                .name = undefined,
                .flags = .{ .is_main = true },
                .channel_count = 2,
                .port_type = clap.ext.audio_ports.port_stereo,
                .in_place_pair = .invalid_id,
            };
            _ = std.fmt.bufPrintZ(&info.name, "{s}", .{"Audio Output"}) catch unreachable;
            return true;
        } else {
            return false;
        }
    }
};

pub fn log(self: @This(), comptime fmt: []const u8, args: anytype) void {
    const host: *const clap.ext.log.Host = @ptrCast(@alignCast(self.host.getExtension(self.host, clap.ext.log.id)));
    const msg = std.fmt.allocPrintZ(self.allocator, fmt, args) catch unreachable;
    defer self.allocator.free(msg);
    host.log(self.host, .info, msg);
}
