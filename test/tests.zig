const std = @import("std");
const allocator = std.testing.allocator;
const Child = std.process.Child;
const build_options = @import("build_options");

const exe_path = "zig-out/bin/ctx";

test "usage message with correct exit code" {
    const tmp_dir = std.testing.tmpDir(.{});
    const exe_abs_path = try std.fs.realpathAlloc(allocator, exe_path);
    defer allocator.free(exe_abs_path);

    const result = try Child.run(.{ .argv = &.{exe_abs_path}, .cwd_dir = tmp_dir.dir, .allocator = allocator });
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    try std.testing.expect(result.term == .Exited and result.term.Exited == 2);
    try std.testing.expect(std.mem.containsAtLeast(u8, result.stderr, 1, "ctx - A command line tool for building prompt context files"));
}

test "print version" {
    const result = try Child.run(.{ .argv = &.{ exe_path, "version" }, .allocator = allocator });
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    const want = "ctx version v" ++ build_options.version;
    try std.testing.expect(std.mem.containsAtLeast(u8, result.stdout, 1, want));
}

const Environment = struct {
    allocator: std.mem.Allocator,
    tmp_dir: std.testing.TmpDir,
    exe_abs_path: []u8,
    pub fn init(allocator_: std.mem.Allocator) !Environment {
        return .{
            .allocator = allocator_,
            .tmp_dir = std.testing.tmpDir(.{}),
            .exe_abs_path = try std.fs.realpathAlloc(allocator_, exe_path),
        };
    }
    pub fn deinit(self: *Environment) void {
        self.allocator.free(self.exe_abs_path);
        self.tmp_dir.cleanup();
    }
    /// Runs a command in the temporary directory.
    pub fn run(self: *const Environment, argv: []const []const u8) !void {
        const result = try Child.run(.{ .argv = argv, .cwd_dir = self.tmp_dir.dir, .allocator = self.allocator });
        defer allocator.free(result.stdout);
        defer allocator.free(result.stderr);
        std.testing.expect(result.term == .Exited and result.term.Exited == 0) catch |err| {
            std.debug.print("stdout: {s}\n", .{result.stdout});
            std.debug.print("stderr: {s}\n", .{result.stderr});
            return err;
        };
    }
    /// Runs a command in the temporary directory and returns the result.
    pub fn ctx(self: *const Environment, argv: []const []const u8) !Child.RunResult {
        var argv_ = try self.allocator.alloc([]const u8, 1 + argv.len);
        defer self.allocator.free(argv_);
        argv_[0] = self.exe_abs_path;
        @memcpy(argv_[1..], argv);
        return Child.run(.{ .argv = argv_, .cwd_dir = self.tmp_dir.dir, .allocator = self.allocator });
    }
    /// Writes a file to the temporary directory.
    pub fn writeFile(self: *const Environment, path: []const u8, data: []const u8) !void {
        const file = try self.tmp_dir.dir.createFile(path, .{ .truncate = true });
        defer file.close();
        try file.writeAll(data);
    }
};

test "print modified" {
    var environment = try Environment.init(allocator);
    defer environment.deinit();

    try environment.run(&.{ "git", "config", "--global", "user.email", "you@example.com" });
    try environment.run(&.{ "git", "config", "--global", "user.name", "Your Name" });

    try environment.writeFile("birds", "sparrow robin");
    try environment.writeFile("flowers", "rose tulip");
    try environment.run(&.{ "git", "init" });
    try environment.run(&.{ "git", "add", "birds" });
    try environment.run(&.{ "git", "add", "flowers" });
    try environment.run(&.{ "git", "commit", "-m", "initial commit" });

    try environment.writeFile("birds", "cardinal");
    try environment.writeFile("flowers", "orchid lily");
    try environment.run(&.{ "git", "add", "birds" });
    try environment.run(&.{ "git", "add", "flowers" });
    try environment.run(&.{ "git", "commit", "-m", "update birds and flowers" });

    var result = try environment.ctx(&.{"init"});
    allocator.free(result.stdout);
    allocator.free(result.stderr);

    try environment.writeFile(".ctxignore", ""); // FIXME(BW): Must be removed

    result = try environment.ctx(&.{ "merge-base", "HEAD~1" });
    allocator.free(result.stdout);
    allocator.free(result.stderr);

    result = try environment.ctx(&.{"status"});
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    const want = try std.mem.replaceOwned(u8, allocator,
        \\Estimated token count: 71
        \\Merge base: HEAD~1
        \\Modified:
        \\[TAB]birds
        \\[TAB]flowers
        \\Paths:
    , "[TAB]", "\t");
    defer allocator.free(want);

    try std.testing.expect(result.term == .Exited and result.term.Exited == 0);
    try std.testing.expect(std.mem.containsAtLeast(u8, result.stdout, 1, want));
}

