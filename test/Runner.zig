const std = @import("std");
const Child = std.process.Child;

const Runner = @This();

allocator: std.mem.Allocator,
tmp_dir: std.testing.TmpDir,
env_map: std.process.EnvMap,
path: []u8,

pub fn init(allocator: std.mem.Allocator) !Runner {
    const current_path = try std.process.getEnvVarOwned(allocator, "PATH");
    defer allocator.free(current_path);

    const bin_path = try std.fs.realpathAlloc(allocator, "zig-out/bin");
    defer allocator.free(bin_path);

    {
        // Open the directory you want to list. "." means “current working dir”.
        var dir = try std.fs.cwd().openDir(bin_path, .{});
        defer dir.close();

        // Create an iterator. `.max_depth = 1` means “don’t recurse”.
        var it = try dir.iterate(allocator, .{ .max_depth = 1 });
        defer it.deinit();

        std.debug.print("All files in zig-out/bin\n", .{});
        while (try it.next()) |entry| {
            // entry.kind is .file, .dir, .sym_link, …
            std.debug.print("{s}\n", .{entry.path});
        }
    }

    const path = try std.mem.concat(allocator, u8, &.{ current_path, ":", bin_path });

    var env_map = std.process.EnvMap.init(allocator);
    try env_map.put("PATH", path);

    return .{
        .allocator = allocator,
        .tmp_dir = std.testing.tmpDir(.{}),
        .path = path,
        .env_map = env_map,
    };
}

pub fn deinit(self: *Runner) void {
    self.allocator.free(self.path);
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

