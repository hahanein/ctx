const std = @import("std");

const manifest: struct {
    name: enum { ctx },
    version: []const u8,
    fingerprint: u64,
    minimum_zig_version: []const u8,
    paths: []const []const u8,
} = @import("build.zig.zon");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.resolveTargetQuery(.{
        .cpu_arch = .x86_64,
        .os_tag = .linux,
        .abi = .musl,
    });

    // Make version available in our modules..
    const options = b.addOptions();
    options.addOption([]const u8, "version", manifest.version);

    const exe = b.addExecutable(.{
        .name = "ctx",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    exe.root_module.addOptions("build_options", options);
    exe.linkLibC();
    b.installArtifact(exe);

    {
        // Run the app..
        const run_cmd = b.addRunArtifact(exe);
        run_cmd.step.dependOn(b.getInstallStep());
        if (b.args) |args| run_cmd.addArgs(args);
        const run_step = b.step("run", "Run the app");
        run_step.dependOn(&run_cmd.step);
    }

    {
        // Run integration tests..

        const tests = b.addTest(.{
            .root_source_file = b.path("test/tests.zig"),
            .target = target,
            .optimize = optimize,
        });

        tests.root_module.addOptions("build_options", options);

        const tests_cmd = b.addRunArtifact(tests);
        tests_cmd.step.dependOn(b.getInstallStep());

        const tests_step = b.step("test", "Run integration tests");
        tests_step.dependOn(&tests_cmd.step);
        tests_step.dependOn(&exe.step);
    }
}

