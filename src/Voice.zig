const std = @import("std");
const clap = @import("clap-bindings");

const Output = struct {
    left: f64,
    right: f64,
};

const Modulators = struct {
    oscillator_detune: f64 = 0,
    volume: f64 = 0,
};

const Expressions = struct {
    volume: f64 = 0,
    pitch: f64 = 0,
};

const Parameters = struct {
    volume: f64,
    oscillator_detune: f64,
    amp_is_gate: bool,
};

/// a simple linear AR envelope
const EnvelopeAttackRelease = struct {
    const State = union(enum) {
        attack,
        hold,
        // value releasing from
        release: f64,
        off,
    };

    attack_time: f64,
    release_time: f64,
    state: State,
    time: f64,

    fn init(attack_time: f64, release_time: f64) EnvelopeAttackRelease {
        return .{
            .attack_time = attack_time,
            .release_time = release_time,
            .state = .attack,
            .time = 0,
        };
    }

    // `delta` should be 1/sample rate
    fn next(env: *EnvelopeAttackRelease, delta: f64) f64 {
        std.debug.assert(env.state != .off);
        std.debug.assert(delta > 0);

        env.time += delta;
        switch (env.state) {
            .attack => {
                if (env.time >= env.attack_time) {
                    env.state = .hold;
                    return 1;
                } else {
                    return env.time / env.attack_time;
                }
            },
            .hold => return 1,
            .release => |from| {
                if (env.time >= env.release_time) {
                    env.state = .off;
                }
                return from * (1 - (env.time / env.release_time));
            },
            .off => unreachable,
        }
    }

    // release the env
    pub fn release(env: *EnvelopeAttackRelease) void {
        switch (env.state) {
            .attack => env.state = .{ .release = env.time / env.attack_time },
            .hold => env.state = .{ .release = 1 },
            else => {},
        }
        env.time = 0;
    }
};

// note id is delivered by the host
note_id: clap.events.NoteId,
// clap note port index
port_index: clap.events.PortIndex,
// midi channel
channel: clap.events.Channel,
// midi key
key: clap.events.Key,

phase: f64 = 0,

parameters: Parameters,
modulators: Modulators = .{},
expressions: Expressions = .{},

amp_env: EnvelopeAttackRelease,

pub fn init(
    note_id: clap.events.NoteId,
    port_index: clap.events.PortIndex,
    channel: clap.events.Channel,
    key: clap.events.Key,
    attack_time: f64,
    release_time: f64,
    parameters: Parameters,
) @This() {
    return .{
        .note_id = note_id,
        .port_index = port_index,
        .channel = channel,
        .key = key,
        .parameters = parameters,
        .amp_env = EnvelopeAttackRelease.init(attack_time, release_time),
    };
}

fn pitchFromKey(key: f64) f64 {
    return 440 * @exp2((key - 69) / 12);
}

// `delta` should be 1/sample rate
pub fn next(voice: *@This(), delta: f64) Output {
    const volume = voice.parameters.volume + voice.modulators.volume + voice.expressions.volume;
    const amp_scale = if (voice.parameters.amp_is_gate) scale: {
        _ = voice.amp_env.next(delta);
        break :scale @as(f64, @floatFromInt(@intFromBool(voice.isPlaying())));
    } else voice.amp_env.next(delta) * volume;

    const key = @as(f64, @floatFromInt(@intFromEnum(voice.key))) + voice.expressions.pitch;
    const detune = voice.parameters.oscillator_detune + voice.modulators.oscillator_detune;
    const pitch = pitchFromKey(key + detune / 100);
    const phase_delta = pitch * delta;
    // without the 0.2 it's full scale and we just don't want that
    const sine = 0.2 * @sin(std.math.tau * voice.phase) * amp_scale;

    voice.phase += phase_delta;
    voice.phase -= @floor(voice.phase);

    return .{
        .left = sine,
        .right = sine,
    };
}

pub fn isPlaying(voice: @This()) bool {
    return switch (voice.amp_env.state) {
        .attack, .hold, .release => true,
        .off => false,
    };
}

pub fn applyModulation(
    voice: *@This(),
    mod_tag: @import("ClapDemo.zig").Param,
    value: f64,
) void {
    if (voice.isPlaying()) switch (mod_tag) {
        .oscillator_detune => {
            voice.modulators.oscillator_detune = value;
        },
        .volume => {
            voice.modulators.volume = value;
        },
        else => unreachable,
    };
}
