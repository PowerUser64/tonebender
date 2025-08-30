const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const clap_bindings = b.dependency("clap_bindings", .{});

    const lib = b.addSharedLibrary(.{
        .name = "clap-demo",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    lib.root_module.addImport(
        "clap-bindings",
        clap_bindings.module("clap-bindings"),
    );

    const wio = b.dependency("wio", .{
        .target = target,
        .optimize = optimize,
    });

    const wio_backend_mod = b.addModule("WioBackend", .{
        .root_source_file = b.path("src/wio/WioBackend.zig"),
        .optimize = optimize,
        .target = target,
    });
    wio_backend_mod.addImport("wio", wio.module("wio"));

    const zgl = b.dependency("zgl", .{
        .target = target,
        .optimize = optimize,
    });
    wio_backend_mod.addImport("zgl", zgl.module("zgl"));

    const dvui_dep = b.dependency("dvui", .{
        .target = target,
        .optimize = optimize,
        .backend = .custom,
    });
    const dvui_mod = dvui_dep.module("dvui");
    @import("dvui").linkBackend(dvui_mod, wio_backend_mod);
    lib.root_module.addImport("dvui", dvui_mod);

    const package_step = createPackageStep(b, lib);
    b.default_step = package_step;

    /////////////////////////////////////////////////////////

    const demo_exe = b.addExecutable(.{
        .name = "wio-demo",
        .root_source_file = b.path("src/wio/demo.zig"),
        .target = target,
        .optimize = optimize,
    });
    const demo_run = b.addRunArtifact(demo_exe);
    const demo_step = b.step("wio-demo", "run wio backend demo");
    demo_step.dependOn(&demo_run.step);

    demo_exe.root_module.addImport("dvui", dvui_mod);
}

// technically you should not need this, but not all daws accept the plugin when
// it's not a package, at least on MacOS. i mainly use a mac and have not yet
// figured out what the requirements are, if there are any, for daws on other
// operating systems but i figure it's nice to rename the lib either way, so it
// does that too.
fn createPackageStep(b: *std.Build, lib: *std.Build.Step.Compile) *std.Build.Step {
    const package_step = b.step("package", "package the clap plugin");
    const clap_name = b.fmt("{s}.clap", .{lib.name});
    switch (lib.rootModuleTarget().os.tag) {
        .macos => {
            const info_plist = b.fmt(
                info_plist_format,
                .{
                    .version = "1.0.0",
                    .region = "English",
                    .executable = clap_name,
                    .identifier = b.fmt("com.interpunct.clap.{s}", .{lib.name}),
                    .name = clap_name,
                },
            );

            const write_files = b.addWriteFiles();
            write_files.step.dependOn(&lib.step);
            write_files.step.name = "MacOS Package";
            _ = write_files.add("Contents/Info.plist", info_plist);
            _ = write_files.add("Contents/PkgInfo", "BNDL????");
            _ = write_files.addCopyFile(
                lib.getEmittedBin(),
                b.fmt("Contents/MacOS/{s}", .{clap_name}),
            );

            const install = b.addInstallDirectory(.{
                .source_dir = write_files.getDirectory(),
                .install_dir = .lib,
                .install_subdir = clap_name,
            });
            package_step.dependOn(&install.step);
        },
        else => {
            const install = b.addInstallLibFile(lib.getEmittedBin(), clap_name);
            package_step.dependOn(&install.step);
        },
    }

    return package_step;
}

const info_plist_format =
    \\<?xml version="1.0" encoding="UTF-8"?>
    \\<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    \\<plist version="1.0">
    \\  <dict>
    \\    <key>CFBundleShortVersionString</key>
    \\    <string>{[version]s}</string>
    \\    <key>CFBundleVersion</key>
    \\    <string>{[version]s}</string>
    \\    <key>CFBundleDevelopmentRegion</key>
    \\    <string>{[region]s}</string>
    \\    <key>CFBundleExecutable</key>
    \\    <string>{[executable]s}</string>
    \\    <key>CFBundleIdentifier</key>
    \\    <string>{[identifier]s}</string>
    \\    <key>CFBundleName</key>
    \\    <string>{[name]s}</string>
    \\    <key>CFBundlePackageType</key>
    \\    <string>BNDL</string>
    \\    <key>CFBundleSignature</key>
    \\    <string>????</string>
    \\    <key>CSResourcesFileMapped</key>
    \\    <true/>
    \\    <key>NSHumanReadableCopyright</key>
    \\    <string></string>
    \\  </dict>
    \\</plist>
    \\
;
