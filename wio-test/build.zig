const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        // .root_source_file = b.path("src/test-zgl.zig"),
        .target = target,
        .optimize = optimize,
    });

    const wio_backend_mod = b.createModule(.{
        .root_source_file = b.path("src/WioBackend.zig"),
        .target = target,
        .optimize = optimize,
    });

    const gl_bindings = @import("zigglgen").generateBindingsModule(b, .{
        .api = .gl,
        .version = .@"4.6",
        .profile = .core,
    });
    wio_backend_mod.addImport("gl", gl_bindings);
    // exe_mod.addImport("gl", gl_bindings);

    const wio = b.dependency("wio", .{
        .target = target,
        .optimize = optimize,
    });
    wio_backend_mod.addImport("wio", wio.module("wio"));
    // exe_mod.addImport("wio", wio.module("wio"));

    const dvui_dep = b.dependency("dvui", .{
        .target = target,
        .optimize = optimize,
        .backend = .custom,
    });
    const dvui_mod = dvui_dep.module("dvui");
    @import("dvui").linkBackend(dvui_mod, wio_backend_mod);
    exe_mod.addImport("dvui", dvui_mod);
    exe_mod.addImport("backend", wio_backend_mod);

    const exe = b.addExecutable(.{
        .name = "wio_test",
        .root_module = exe_mod,
    });
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
