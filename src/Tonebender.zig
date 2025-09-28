const std = @import("std");
const clap = @import("clap-bindings");

const Gui = @import("Gui.zig");

const c = @cImport({
    @cInclude("mydsp.gen.c");
    @cInclude("faust.h");
    @cInclude("faust_prints.c");
});

pub const desc = clap.Plugin.Descriptor{
    .clap_version = clap.version,
    .id = "com.bnw.tonebender",
    .name = "Tonebender synthesizer",
    .vendor = "bnw",
    .url = "blake.ly",
    .manual_url = "",
    .support_url = "",
    .version = "1.0.0",
    .description = "a tone-bending synthesizer",
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

dsp: [*c]c.mydsp = null, // set in init. should make this not c pointer at some point

pub fn fromPlugin(plugin: *const clap.Plugin) *@This() {
    return @ptrCast(@alignCast(plugin.plugin_data));
}

pub fn create(host: *const clap.Host, allocator: std.mem.Allocator) !*const clap.Plugin {
    const tonebender = try allocator.create(@This());
    errdefer allocator.destroy(tonebender);
    tonebender.* = .{
        .allocator = allocator,
        .plugin = .{
            .descriptor = &desc,
            .plugin_data = tonebender,
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
    };
    return &tonebender.plugin;
}

fn init(plugin: *const clap.Plugin) callconv(.C) bool {
    var tonebender = fromPlugin(plugin);
    tonebender.dsp = c.newmydsp();
    return true;
}

fn destroy(plugin: *const clap.Plugin) callconv(.C) void {
    var tonebender = fromPlugin(plugin);
    c.deletemydsp(tonebender.dsp);
    tonebender.allocator.destroy(tonebender);
}

fn activate(
    plugin: *const clap.Plugin,
    sample_rate: f64,
    _: u32,
    _: u32,
) callconv(.C) bool {
    var tonebender = fromPlugin(plugin);
    c.initmydsp(tonebender.dsp, @intFromFloat(@round(sample_rate)));
    tonebender.sample_rate = sample_rate;
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

    const tonebender = fromPlugin(plugin);
    _ = tonebender; // autofix

    const out = clap_process.audio_outputs[0].data32.?;
    const channel_count = clap_process.audio_outputs[0].channel_count;

    const events = clap_process.in_events;
    const event_count = events.size(events);
    _ = event_count; // autofix

    // c.computemydsp(
    //     tonebender.dsp,
    //     @intCast(clap_process.frames_count),
    //     null,
    //     @ptrCast(out),
    // );

    for (out[0..channel_count]) |channel| {
        for (channel, 0..clap_process.frames_count) |*frame, i| {
            const x: f32 = @floatFromInt(i);
            frame.* = @sin(x);
        }
    }

    return .@"continue";
}

fn handleInboundEvent(tonebender: *@This(), event_header: *const clap.events.Header) void {
    _ = tonebender; // autofix

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
        return &Gui.gui.extension;
    } else if (eql(clap.ext.timer_support.id, id)) {
        return &Gui.timer_support.extension;
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
