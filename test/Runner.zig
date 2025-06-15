const std = @import("std");
const Child = std.process.Child;

const Runner = @This();

allocator: std.mem.Allocator,
tmp_dir: std.testing.TmpDir,
env_map: std.process.EnvMap,

pub fn init(allocator: std.mem.Allocator) !Runner {
    var env_map = try std.process.getEnvMap(allocator);

    const current_path = env_map.get("PATH") orelse return error.MissingPathEnvVar;

    const bin_path = try std.fs.realpathAlloc(allocator, "zig-out/bin");
    defer allocator.free(bin_path);

    const path = try std.mem.concat(allocator, u8, &.{ current_path, ":", bin_path });
    defer allocator.free(path);

    try env_map.put("PATH", path);

    return .{
        .allocator = allocator,
        .tmp_dir = std.testing.tmpDir(.{}),
        .env_map = env_map,
    };
}

pub fn deinit(self: *Runner) void {
    self.env_map.deinit();
    self.tmp_dir.cleanup();
}

/// Runs a dash command in the temporary directory.
pub fn dash(self: *const Runner, command_string: []const u8) !void {
    const result = try Child.run(.{
        .env_map = &self.env_map,
        .argv = &.{ "dash", "-c", command_string },
        .cwd_dir = self.tmp_dir.dir,
        .allocator = self.allocator,
    });

    defer self.allocator.free(result.stdout);
    defer self.allocator.free(result.stderr);

    std.testing.expect(result.term == .Exited and result.term.Exited == 0) catch |err| {
        std.debug.print("stdout: {s}\n", .{result.stdout});
        std.debug.print("stderr: {s}\n", .{result.stderr});
        return err;
    };
}

/// Runs a command in the temporary directory and returns the result.
pub fn run(self: *const Runner, argv: []const []const u8) !Child.RunResult {
    return Child.run(.{
        .env_map = &self.env_map,
        .argv = argv,
        .cwd_dir = self.tmp_dir.dir,
        .allocator = self.allocator,
    });
}

