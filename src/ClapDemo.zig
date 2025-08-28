const std = @import("std");
const clap = @import("clap-bindings");

const Voice = @import("Voice.zig");
const Gui = @import("Gui.zig");

const max_voices = 64;

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

pub const Param = enum {
    oscillator_detune,
    amp_attack,
    amp_release,
    amp_is_gate,
    volume,
};

const ParamValues = std.EnumArray(Param, f64);

const param_count = std.meta.fields(Param).len;

const param_defaults: std.enums.EnumFieldStruct(Param, f64, null) = .{
    .oscillator_detune = 0,
    .amp_attack = 0.01,
    .amp_release = 0.2,
    .amp_is_gate = 0,
    .volume = 1,
};

allocator: std.mem.Allocator,
plugin: clap.Plugin,
host: *const clap.Host,
param_values: ParamValues = ParamValues.init(param_defaults),
sample_rate: ?f64 = null,
voices_buffer: [2 * max_voices * @sizeOf(Voice)]u8,
voice_allocator: std.heap.FixedBufferAllocator,
voices: std.ArrayList(Voice),

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
        .voices_buffer = undefined,
        .voice_allocator = undefined,
        .voices = undefined,
    };
    return &clap_demo.plugin;
}

fn init(plugin: *const clap.Plugin) callconv(.C) bool {
    var clap_demo = fromPlugin(plugin);
    clap_demo.voice_allocator = std.heap.FixedBufferAllocator.init(&clap_demo.voices_buffer);
    clap_demo.voices = std.ArrayList(Voice).init(clap_demo.voice_allocator.allocator());
    Gui.timer_support.registerTimer(clap_demo);
    return true;
}

fn destroy(plugin: *const clap.Plugin) callconv(.C) void {
    var clap_demo = fromPlugin(plugin);
    Gui.timer_support.unregisterTimer(clap_demo);
    clap_demo.allocator.destroy(clap_demo);
}

fn activate(
    plugin: *const clap.Plugin,
    sample_rate: f64,
    _: u32,
    _: u32,
) callconv(.C) bool {
    var clap_demo = fromPlugin(plugin);
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

    var clap_demo = fromPlugin(plugin);

    const out = clap_process.audio_outputs[0].data32.?;
    const channel_count = clap_process.audio_outputs[0].channel_count;

    const events = clap_process.in_events;
    const event_count = events.size(events);
    var next_event: ?*const clap.events.Header = if (event_count > 0) events.get(events, 0) else null;
    var next_event_index: u32 = 0;
    var sample: u32 = 0;
    while (sample < clap_process.frames_count) : (sample += 1) {
        // multiple events can happen on the same sample!
        while (next_event != null and next_event.?.sample_offset == sample) {
            clap_demo.handleInboundEvent(next_event.?);
            next_event_index += 1;
            next_event = if (next_event_index < event_count) events.get(events, next_event_index) else null;
        }
        // reset output buffers
        for (0..channel_count) |channel| {
            out[channel][sample] = 0;
        }

        const delta = 1 / clap_demo.sample_rate.?;
        //                                    the voice may stop playing
        //                                    before the frames are over
        //                                    and we don't wanna fuss with
        //                                    removing them on the sample
        //                                    they ended.
        for (clap_demo.voices.items) |*voice| if (voice.isPlaying()) {
            const output = voice.next(delta);
            if (channel_count >= 2) {
                out[0][sample] += @floatCast(output.left);
                out[1][sample] += @floatCast(output.right);
            } else if (channel_count == 1) {
                out[0][sample] += @floatCast((output.left + output.right) * 0.5);
            }
        };
    }

    // loop over the voices backwards and remove voices
    // that are no longer playing from the active voices
    // we also wanna send a note end event to the host
    // for all voices that are being removed.
    const out_events = clap_process.out_events;
    var last_index = clap_demo.voices.items.len;
    while (last_index > 0) {
        last_index -= 1;
        const voice = clap_demo.voices.items[last_index];
        if (!voice.isPlaying()) {
            _ = clap_demo.voices.orderedRemove(last_index);
            const event = clap.events.Note{
                .header = .{
                    .size = @sizeOf(clap.events.Note),
                    .sample_offset = clap_process.frames_count - 1,
                    .space_id = clap.events.core_space_id,
                    .type = .note_end,
                    .flags = .{},
                },
                .note_id = voice.note_id,
                .port_index = voice.port_index,
                .channel = voice.channel,
                .key = voice.key,
                .velocity = 0,
            };
            _ = out_events.tryPush(out_events, &event.header);
        }
    }

    // we only need to continue if we still have active voices!
    // if we have no active voices we tell the host it can
    // skip our processing until we get the next event
    return if (clap_demo.voices.items.len > 0) .@"continue" else .sleep;
}

fn handleInboundEvent(clap_demo: *@This(), event_header: *const clap.events.Header) void {
    if (event_header.space_id != clap.events.core_space_id) {
        return;
    }

    switch (event_header.type) {
        .note_on => {
            const note_event = @as(*const clap.events.Note, @ptrCast(@alignCast(event_header)));
            // we try to find a voice currently playing on the same key and steal it, if one does
            // not exist we add another voice to the list if we can, or steal the oldest voice
            const new_voice: *Voice = find_voice: for (clap_demo.voices.items) |*voice| {
                if (voice.key != .unspecified and voice.key == note_event.key) {
                    break :find_voice voice;
                }
            } else {
                // we gotta add a new one!
                // first make sure we got space
                if (clap_demo.voices.items.len >= max_voices) {
                    // the oldest voice is at index 0, this is sorta needlessly
                    // expensive, but also like the cost is still quite low. this
                    // really should not happen often.
                    _ = clap_demo.voices.orderedRemove(0);
                }
                break :find_voice clap_demo.voices.addOne() catch unreachable;
            };

            new_voice.* = Voice.init(
                note_event.note_id,
                note_event.port_index,
                note_event.channel,
                note_event.key,
                clap_demo.param_values.get(.amp_attack),
                clap_demo.param_values.get(.amp_release),
                .{
                    .volume = clap_demo.param_values.get(.volume),
                    .oscillator_detune = clap_demo.param_values.get(.oscillator_detune),
                    .amp_is_gate = clap_demo.param_values.get(.amp_is_gate) > 0.5,
                },
            );
        },
        .note_off => {
            const note_event = @as(*const clap.events.Note, @ptrCast(@alignCast(event_header)));
            for (clap_demo.voices.items) |*voice| {
                if (voice.key == note_event.key and
                    voice.port_index == note_event.port_index and
                    voice.channel == note_event.channel)
                {
                    voice.amp_env.release();
                }
            }
        },
        .param_value => {
            const value_event = @as(*const clap.events.ParamValue, @ptrCast(@alignCast(event_header)));
            const param_tag: Param = @enumFromInt(@intFromEnum(value_event.param_id));
            clap_demo.param_values.set(param_tag, value_event.value);
            clap_demo.pushParamsToVoices();
        },
        .param_mod => {
            const mod_event = @as(*const clap.events.ParamMod, @ptrCast(@alignCast(event_header)));
            const param_tag: Param = @enumFromInt(@intFromEnum(mod_event.param_id));
            if (mod_event.note_id != .unspecified) {
                // modulation is polyphonic by note id
                for (clap_demo.voices.items) |*voice| if (voice.note_id == mod_event.note_id) {
                    voice.applyModulation(param_tag, mod_event.value);
                };
            } else if (mod_event.key != .unspecified and mod_event.channel != .unspecified and mod_event.port_index != .unspecified) {
                // modulation is polyphonic by port, channel, and key
                for (clap_demo.voices.items) |*voice| {
                    if (voice.key == mod_event.key and
                        voice.channel == mod_event.channel and
                        voice.port_index == mod_event.port_index)
                    {
                        voice.applyModulation(param_tag, mod_event.value);
                    }
                }
            } else {
                // modulation is monophonic
                for (clap_demo.voices.items) |*voice| {
                    voice.applyModulation(param_tag, mod_event.value);
                }
            }
        },
        .note_expression => {
            const expression_event = @as(*const clap.events.NoteExpression, @ptrCast(@alignCast(event_header)));
            for (clap_demo.voices.items) |*voice| {
                if (voice.key == expression_event.key and
                    voice.channel == expression_event.channel and
                    voice.port_index == expression_event.port_index)
                {
                    switch (expression_event.expression_id) {
                        .volume => voice.expressions.volume = @floatCast(expression_event.value - 1),
                        .tuning => {
                            voice.expressions.pitch = @floatCast(expression_event.value);
                        },
                        else => {},
                    }
                }
            }
        },
        else => {},
    }
}

fn scaleTime(time: f64) f64 {
    return @exp2(6 * time - 4);
}

fn unscaleTime(time: f64) f64 {
    return (@log2(time) + 4) / 6;
}

fn pushParamsToVoices(clap_demo: *@This()) void {
    for (clap_demo.voices.items) |*voice| {
        voice.parameters.oscillator_detune = clap_demo.param_values.get(.oscillator_detune);
        voice.parameters.volume = clap_demo.param_values.get(.volume);
        voice.amp_env.attack_time = scaleTime(clap_demo.param_values.get(.amp_attack));
        voice.amp_env.release_time = scaleTime(clap_demo.param_values.get(.amp_release));
        voice.parameters.amp_is_gate = clap_demo.param_values.get(.amp_is_gate) > 0.5;
    }
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
        return &voice_info.extension;
    } else if (eql(clap.ext.state.id, id)) {
        return &state.extension;
    } else if (eql(clap.ext.params.id, id)) {
        return &params.extension;
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
            true => 1,
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

const voice_info = struct {
    const extension = clap.ext.voice_info.Plugin{
        .get = get,
    };

    fn get(_: *const clap.Plugin, info: *clap.ext.voice_info.Info) callconv(.C) bool {
        info.* = .{
            .voice_count = max_voices,
            .voice_capacity = max_voices,
            .flags = .{ .supports_overlapping_notes = true },
        };
        return true;
    }
};

const state = struct {
    const extension = clap.ext.state.Plugin{
        .save = save,
        .load = load,
    };

    const chunk_size = 256;
    const max_size = chunk_size * param_count;

    fn save(plugin: *const clap.Plugin, stream: *const clap.OStream) callconv(.C) bool {
        // in a real plugin you should write an actual serializer
        const clap_demo = fromPlugin(plugin);
        var param_values = clap_demo.param_values.iterator();
        // loop through each param, write it to out stream in the form `param_id=value;`
        while (param_values.next()) |param| {
            var buffer = [_]u8{0} ** chunk_size;
            const param_serialized = std.fmt.bufPrint(
                &buffer,
                "{}={d};",
                .{ @intFromEnum(param.key), param.value.* },
            ) catch unreachable;
            var written: u31 = 0;
            while (written < param_serialized.len) {
                const remaining = param_serialized[written..];
                const amt: u64 = switch (stream.write(stream, remaining.ptr, remaining.len)) {
                    .write_error, @as(clap.OStream.Result, @enumFromInt(0)) => return false,
                    _ => |bytes| @intCast(@intFromEnum(bytes)),
                };
                written += @intCast(amt);
            }
        }
        return true;
    }

    fn load(plugin: *const clap.Plugin, stream: *const clap.IStream) callconv(.C) bool {
        // in a real plugin you should write an actual deserializer
        var buffer = [_]u8{0} ** max_size;
        // read the stream into `buffer` until the stream is empty.
        var total_read: usize = 0;
        while (readStream(buffer[total_read..], stream)) |read| {
            total_read += read;
        } else |err| {
            switch (err) {
                error.ReadError => return false,
                error.EndOfFile => {},
            }
        }

        // don't try to parse an empty buffer
        if (total_read == 0) {
            return false;
        }

        var clap_demo = fromPlugin(plugin);
        // the part of the buffer that was read into is 0..total_read, but we wanna skip the last
        // semicolon so we don't have to deal with it in the split logic
        const read_buffer = buffer[0 .. total_read - 1];
        var param_values = std.mem.splitSequence(u8, read_buffer, ";");
        while (param_values.next()) |param_serialized| {
            const seperator_index = std.mem.indexOfScalarPos(u8, param_serialized, 0, '=') orelse return false;
            const param_bytes = param_serialized[0..seperator_index];
            const param_id = std.fmt.parseInt(u8, param_bytes, 10) catch return false;
            const param_tag: Param = @enumFromInt(param_id);
            const value_bytes = param_serialized[seperator_index + 1 ..];
            const param_value = std.fmt.parseFloat(f64, value_bytes) catch return false;
            clap_demo.param_values.set(param_tag, param_value);
        }
        clap_demo.pushParamsToVoices();
        return true;
    }

    fn readStream(buffer: []u8, stream: *const clap.IStream) !usize {
        return switch (stream.read(stream, buffer.ptr, buffer.len)) {
            .read_error => error.ReadError,
            .end_of_file => error.EndOfFile,
            _ => |bytes| @intCast(@intFromEnum(bytes)),
        };
    }
};

const params = struct {
    const extension = clap.ext.params.Plugin{
        .count = count,
        .getInfo = getInfo,
        .getValue = getValue,
        .valueToText = valueToText,
        .textToValue = textToValue,
        .flush = flush,
    };

    fn count(_: *const clap.Plugin) callconv(.C) u32 {
        return param_count;
    }

    const basic_flags = clap.ext.params.Info.Flags{
        .is_automatable = true,
    };
    const stepped_flags = clap.ext.params.Info.Flags{
        .is_stepped = true,
        .is_automatable = true,
    };
    const mod_flags = clap.ext.params.Info.Flags{
        .is_automatable = true,
        .is_modulatable = true,
        .is_modulatable_per_note_id = true,
        .is_modulatable_per_key = true,
    };

    fn getInfo(
        _: *const clap.Plugin,
        index: u32,
        info: *clap.ext.params.Info,
    ) callconv(.C) bool {
        switch (index) {
            0 => {
                info.* = .{
                    .id = @enumFromInt(@intFromEnum(Param.oscillator_detune)),
                    .flags = mod_flags,
                    .cookie = null,
                    .name = undefined,
                    .module = undefined,
                    .min_value = -200,
                    .max_value = 200,
                    .default_value = param_defaults.oscillator_detune,
                };
                _ = std.fmt.bufPrintZ(&info.name, "{s}", .{"Oscillator Detuning"}) catch unreachable;
                _ = std.fmt.bufPrintZ(&info.module, "{s}", .{"Oscillator"}) catch unreachable;
                return true;
            },
            1 => {
                info.* = .{
                    .id = @enumFromInt(@intFromEnum(Param.amp_attack)),
                    .flags = basic_flags,
                    .cookie = null,
                    .name = undefined,
                    .module = undefined,
                    .min_value = 0,
                    .max_value = 1,
                    .default_value = param_defaults.amp_attack,
                };
                _ = std.fmt.bufPrintZ(&info.name, "{s}", .{"Amplitude Attack"}) catch unreachable;
                _ = std.fmt.bufPrintZ(&info.module, "{s}", .{"Amplitude Envelope Generator"}) catch unreachable;
                return true;
            },
            2 => {
                info.* = .{
                    .id = @enumFromInt(@intFromEnum(Param.amp_release)),
                    .flags = basic_flags,
                    .cookie = null,
                    .name = undefined,
                    .module = undefined,
                    .min_value = 0,
                    .max_value = 1,
                    .default_value = param_defaults.amp_release,
                };
                _ = std.fmt.bufPrintZ(&info.name, "{s}", .{"Amplitude Release"}) catch unreachable;
                _ = std.fmt.bufPrintZ(&info.module, "{s}", .{"Amplitude Envelope Generator"}) catch unreachable;
                return true;
            },
            3 => {
                info.* = .{
                    .id = @enumFromInt(@intFromEnum(Param.amp_is_gate)),
                    .flags = stepped_flags,
                    .cookie = null,
                    .name = undefined,
                    .module = undefined,
                    .min_value = 0,
                    .max_value = 1,
                    .default_value = param_defaults.amp_is_gate,
                };
                _ = std.fmt.bufPrintZ(&info.name, "{s}", .{"Deactivate Amplitude Envelope"}) catch unreachable;
                _ = std.fmt.bufPrintZ(&info.module, "{s}", .{"Amplitude Envelope Generator"}) catch unreachable;
                return true;
            },
            4 => {
                info.* = .{
                    .id = @enumFromInt(@intFromEnum(Param.volume)),
                    .flags = mod_flags,
                    .cookie = null,
                    .name = undefined,
                    .module = undefined,
                    .min_value = 0,
                    .max_value = 1,
                    .default_value = param_defaults.volume,
                };
                _ = std.fmt.bufPrintZ(&info.name, "{s}", .{"Output Volume"}) catch unreachable;
                _ = std.fmt.bufPrintZ(&info.module, "{s}", .{""}) catch unreachable;
                return true;
            },
            else => return false,
        }
    }

    fn getValue(plugin: *const clap.Plugin, id: clap.Id, value: *f64) callconv(.C) bool {
        const clap_demo = fromPlugin(plugin);
        value.* = clap_demo.param_values.get(@enumFromInt(@intFromEnum(id)));
        return true;
    }

    fn valueToText(
        _: *const clap.Plugin,
        id: clap.Id,
        value: f64,
        out_buffer: [*]u8,
        out_buffer_capacity: u32,
    ) callconv(.C) bool {
        const buffer_slice = out_buffer[0..out_buffer_capacity];
        const param_id: Param = @enumFromInt(@intFromEnum(id));
        switch (param_id) {
            .volume => {
                _ = std.fmt.bufPrintZ(buffer_slice, "{d:.3}", .{value}) catch unreachable;
                return true;
            },
            .amp_attack, .amp_release => {
                const seconds = scaleTime(value);
                _ = std.fmt.bufPrintZ(buffer_slice, "{d:.3} s", .{seconds}) catch unreachable;
                return true;
            },
            .oscillator_detune => {
                _ = std.fmt.bufPrintZ(buffer_slice, "{d:.3} cents", .{value}) catch unreachable;
                return true;
            },
            .amp_is_gate => {
                switch (value > 0.5) {
                    true => _ = std.fmt.bufPrintZ(buffer_slice, "{s}", .{"AEG Bypassed"}) catch unreachable,
                    false => _ = std.fmt.bufPrintZ(buffer_slice, "{s}", .{"AEG On"}) catch unreachable,
                }
                return true;
            },
        }
    }

    fn textToValue(
        _: *const clap.Plugin,
        id: clap.Id,
        value_text: [*:0]const u8,
        out_value: *f64,
    ) callconv(.C) bool {
        const value_slice = value_text[0..std.mem.len(value_text)];
        const param_tag: Param = @enumFromInt(@intFromEnum(id));
        switch (param_tag) {
            .volume => {
                const value = parseNumParam(value_slice) catch return false;
                out_value.* = std.math.clamp(value, 0, 1);
                return true;
            },
            .amp_attack, .amp_release => {
                const value = parseNumParam(value_slice) catch return false;
                out_value.* = unscaleTime(value);
                return true;
            },
            .oscillator_detune => {
                const value = parseNumParam(value_slice) catch return false;
                out_value.* = std.math.clamp(value, -200, 200);
                return true;
            },
            .amp_is_gate => {
                if (std.mem.eql(u8, "AEG Bypassed", value_slice)) {
                    out_value.* = 1;
                } else if (std.mem.eql(u8, "AEG On", value_slice)) {
                    out_value.* = 0;
                } else {
                    return false;
                }
                return true;
            },
        }
    }

    fn parseNumParam(value_text: []const u8) !f64 {
        const number_end = std.mem.indexOfNone(u8, value_text, "1234567890.-") orelse value_text.len;
        const number_slice = value_text[0..number_end];
        return std.fmt.parseFloat(f64, number_slice);
    }

    fn flush(
        plugin: *const clap.Plugin,
        in: *const clap.events.InputEvents,
        _: *const clap.events.OutputEvents,
    ) callconv(.C) void {
        var clap_demo = fromPlugin(plugin);

        const event_count = in.size(in);
        var event_index: u32 = 0;
        while (event_index < event_count) : (event_index += 1) {
            const next_event = in.get(in, event_index);
            clap_demo.handleInboundEvent(next_event);
        }
    }
};

pub fn log(self: @This(), comptime fmt: []const u8, args: anytype) void {
    const host: *const clap.ext.log.Host = @ptrCast(@alignCast(self.host.getExtension(self.host, clap.ext.log.id)));
    const msg = std.fmt.allocPrintZ(self.allocator, fmt, args) catch unreachable;
    defer self.allocator.free(msg);
    host.log(self.host, .info, msg);
}
