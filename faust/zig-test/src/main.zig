//! A translation of the Faust "minimal.c" example code to zig
//! https://github.com/grame-cncm/faust/blob/master-dev/architecture/minimal.c
const std = @import("std");
const c = @cImport({
    @cInclude("mydsp.gen.c");
    @cInclude("faust.h");
    @cInclude("faust_prints.c");
    // @cInclude("unistd.h");
    // @cInclude("c");
});

const BUFFER_SIZE = 20;
const SAMPLE_RATE = 4800;

pub fn main() !void {
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    const mydsp = c.newmydsp(); // DONE
    defer c.deletemydsp(mydsp); // DONE

    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    defer _ = gpa.deinit();
    var alloc = gpa.allocator();

    try stdout.print("DSP inputs: {}\n", .{c.getNumInputsmydsp(mydsp)});
    try bw.flush();
    try stdout.print("DSP outputs: {}\n", .{c.getNumOutputsmydsp(mydsp)});
    try bw.flush();

    // "init with audio driver SR"
    c.initmydsp(mydsp, SAMPLE_RATE); // DONE

    var ui_glue = c.UIGlue{
        .openHorizontalBox = c.printHGroup,
        .openVerticalBox = c.printVGroup,
        .openTabBox = c.printOpenTabBox,
        .closeBox = c.printCloseBox,
        .addButton = c.printButton,
        .addCheckButton = c.printCheckButton,
        .addVerticalSlider = c.printVerticalSlider,
        .addHorizontalSlider = c.printHorizontalSlider,
        .addNumEntry = c.printNumEntry,
        .addHorizontalBargraph = c.printHorizontalBargraph,
        .addVerticalBargraph = c.printVerticalBargraph,
        .declare = c.printDeclare,
    };

    // "add controls handling methods"
    c.buildUserInterfacemydsp(mydsp, @ptrCast(&ui_glue));
    const ctrl_list = c.newControl(null, null, 0, 0, 0, 0);
    defer c.freeControls(ctrl_list);
    c.initControl(ctrl_list);

    var ctrl_glue = c.UIGlue{
        .uiInterface = ctrl_list,
        .openHorizontalBox = c.ignoreHGroup,
        .openVerticalBox = c.ignoreVGroup,
        .openTabBox = c.ignoreOpenTabBox,
        .closeBox = c.ignoreCloseBox,
        .addButton = c.addButton,
        .addCheckButton = c.addCheckButton,
        .addVerticalSlider = c.addVerticalSlider,
        .addHorizontalSlider = c.addHorizontalSlider,
        .addNumEntry = c.addNumEntry,
        .addHorizontalBargraph = c.addHorizontalBargraph,
        .addVerticalBargraph = c.addVerticalBargraph,
        .declare = c.ignoreDeclare,
    };

    // "get all controls"
    c.buildUserInterfacemydsp(mydsp, @ptrCast(&ctrl_glue));

    // "print all labels"
    c.printControls(ctrl_list);

    // "set a control using its label"
    c.setParamValue(ctrl_list, "Foo", 0.0);
    c.setParamValue(ctrl_list, "Bar", 20);

    // "compute one buffer"
    const inputs = try alloc.alloc([*]c.FAUSTFLOAT, @intCast(c.getNumInputsmydsp(mydsp)));
    defer alloc.free(inputs);
    const outputs = try alloc.alloc([*]c.FAUSTFLOAT, @intCast(c.getNumOutputsmydsp(mydsp)));
    defer alloc.free(outputs);
    for (inputs, 0..) |_, i| {
        const slice = try alloc.alloc(c.FAUSTFLOAT, BUFFER_SIZE);
        inputs[i] = slice.ptr;
    }
    defer for (inputs) |ptr| {
        const slice = ptr[0..BUFFER_SIZE];
        alloc.free(slice);
    };
    for (outputs, 0..) |_, i| {
        const slice = try alloc.alloc(c.FAUSTFLOAT, BUFFER_SIZE);
        outputs[i] = slice.ptr;
    }
    defer for (outputs) |ptr| {
        const slice = ptr[0..BUFFER_SIZE];
        alloc.free(slice);
    };
    // at this point, we should have filled to_free
    c.computemydsp(mydsp, BUFFER_SIZE, @ptrCast(inputs), @ptrCast(outputs));

    // "print output buffers"
    for (0..BUFFER_SIZE) |frame| {
        for (0..outputs.len) |chan| {
            try stdout.print("Audio output chan: {} sample: {d:.6}\n", .{ chan, outputs[chan][frame] });
            try bw.flush();
        }
    }

    bw.flush() catch |err| switch (err) {
        else => _ = 0,
    };
    stdout.print("Hello, world!\n", .{}) catch |err| switch (err) {
        else => _ = 0,
    };
}
