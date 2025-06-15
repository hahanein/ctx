const std = @import("std");
const Child = std.process.Child;

const Runner = @This();

const exe_path = "zig-out/bin/ctx";

allocator: std.mem.Allocator,
tmp_dir: std.testing.TmpDir,
exe_abs_path: []u8,

pub fn init(allocator: std.mem.Allocator) !Runner {
    return .{
        .allocator = allocator,
        .tmp_dir = std.testing.tmpDir(.{}),
        .exe_abs_path = try std.fs.realpathAlloc(allocator, exe_path),
    };
}

pub fn deinit(self: *Runner) void {
    self.allocator.free(self.exe_abs_path);
    self.tmp_dir.cleanup();
}

/// Runs a dash command in the temporary directory.
pub fn dash(self: *const Runner, command_string: []const u8) !void {
    const result = try Child.run(.{ .argv = &.{ "dash", "-c", command_string }, .cwd_dir = self.tmp_dir.dir, .allocator = self.allocator });
    defer self.allocator.free(result.stdout);
    defer self.allocator.free(result.stderr);
    std.testing.expect(result.term == .Exited and result.term.Exited == 0) catch |err| {
        std.debug.print("stdout: {s}\n", .{result.stdout});
        std.debug.print("stderr: {s}\n", .{result.stderr});
        return err;
    };
}

/// Runs a ctx command in the temporary directory and returns the result.
pub fn ctx(self: *const Runner, argv: []const []const u8) !Child.RunResult {
    var argv_ = try self.allocator.alloc([]const u8, 1 + argv.len);
    defer self.allocator.free(argv_);
    argv_[0] = self.exe_abs_path;
    @memcpy(argv_[1..], argv);
    return Child.run(.{ .argv = argv_, .cwd_dir = self.tmp_dir.dir, .allocator = self.allocator });
}

