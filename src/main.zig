const std = @import("std");
const clap = @import("clap-bindings");
const ClapDemo = @import("ClapDemo.zig");

export const clap_entry = clap.Entry{
    .version = clap.version,
    .init = init,
    .deinit = deinit,
    .getFactory = getFactory,
};

var gpa: std.heap.GeneralPurposeAllocator(.{}) = undefined;

fn init(_: [*:0]const u8) callconv(.C) bool {
    gpa = .{};
    return true;
}

fn deinit() callconv(.C) void {
    _ = gpa.deinit();
}

fn getFactory(id: [*:0]const u8) callconv(.C) ?*const anyopaque {
    if (std.mem.orderZ(u8, id, clap.PluginFactory.id) == .eq) {
        return &demo_factory;
    } else {
        return null;
    }
}

const demo_factory = clap.PluginFactory{
    .getPluginCount = getPluginCount,
    .getPluginDescriptor = getPluginDescriptor,
    .createPlugin = createPlugin,
};

fn getPluginCount(_: *const clap.PluginFactory) callconv(.C) u32 {
    return 1;
}

fn getPluginDescriptor(_: *const clap.PluginFactory, index: u32) callconv(.C) ?*const clap.Plugin.Descriptor {
    if (index == 0) {
        return &ClapDemo.desc;
    } else {
        return null;
    }
}

fn createPlugin(
    _: *const clap.PluginFactory,
    host: *const clap.Host,
    id: [*:0]const u8,
) callconv(.C) ?*const clap.Plugin {
    if (host.clap_version.isCompatible() and
        std.mem.orderZ(u8, id, ClapDemo.desc.id) == .eq)
    {
        const plugin = ClapDemo.create(host, gpa.allocator()) catch return null;
        return plugin;
    } else {
        return null;
    }
}
