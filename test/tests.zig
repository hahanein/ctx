const std = @import("std");
const allocator = std.testing.allocator;
const build_options = @import("build_options");
const Runner = @import("Runner.zig");

test "print usage message and exit with usage error status" {
    var runner = try Runner.init(allocator);
    defer runner.deinit();

    const result = try runner.ctx(&.{});
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    const want = "ctx - A command line tool for building prompt context files";

    std.testing.expect(result.term == .Exited and result.term.Exited == 2) catch |err| {
        std.debug.print("stdout: {s}\n", .{result.stdout});
        std.debug.print("stderr: {s}\n", .{result.stderr});
        return err;
    };

    std.testing.expect(std.mem.containsAtLeast(u8, result.stderr, 1, want)) catch |err| {
        std.debug.print("stdout: {s}\n", .{result.stdout});
        std.debug.print("stderr: {s}\n", .{result.stderr});
        return err;
    };
}

test "print version" {
    var runner = try Runner.init(allocator);
    defer runner.deinit();

    const result = try runner.ctx(&.{"version"});
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    const want = "ctx version v" ++ build_options.version;

    std.testing.expect(std.mem.containsAtLeast(u8, result.stdout, 1, want)) catch |err| {
        std.debug.print("stdout: {s}\n", .{result.stdout});
        std.debug.print("stderr: {s}\n", .{result.stderr});
        return err;
    };
}

test "print modified files" {
    var runner = try Runner.init(allocator);
    defer runner.deinit();

    try runner.run(&.{ "git", "init" });
    try runner.run(&.{ "git", "config", "user.email", "you@example.com" });
    try runner.run(&.{ "git", "config", "user.name", "Your Name" });

    try runner.writeFile("birds", "sparrow robin");
    try runner.writeFile("flowers", "rose tulip");
    try runner.run(&.{ "git", "add", "birds", "flowers" });
    try runner.run(&.{ "git", "commit", "-m", "initial commit" });

    try runner.writeFile("birds", "cardinal");
    try runner.writeFile("flowers", "orchid lily");
    try runner.run(&.{ "git", "add", "birds", "flowers" });
    try runner.run(&.{ "git", "commit", "-m", "update birds and flowers" });

    var result = try runner.ctx(&.{"init"});
    allocator.free(result.stdout);
    allocator.free(result.stderr);

    result = try runner.ctx(&.{ "merge-base", "HEAD~1" });
    allocator.free(result.stdout);
    allocator.free(result.stderr);

    result = try runner.ctx(&.{"status"});
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    const want = try std.mem.replaceOwned(u8, allocator,
        \\Estimated token count: 71
        \\Merge base: HEAD~1
        \\Modified:
        \\{Tab}birds
        \\{Tab}flowers
        \\Paths:
    , "{Tab}", "\t");
    defer allocator.free(want);

    std.testing.expect(result.term == .Exited and result.term.Exited == 0) catch |err| {
        std.debug.print("stdout: {s}\n", .{result.stdout});
        std.debug.print("stderr: {s}\n", .{result.stderr});
        return err;
    };

    std.testing.expect(std.mem.containsAtLeast(u8, result.stdout, 1, want)) catch |err| {
        std.debug.print("stdout: {s}\n", .{result.stdout});
        std.debug.print("stderr: {s}\n", .{result.stderr});
        return err;
    };
}

test "respect ignore file and not print modified file" {
    var runner = try Runner.init(allocator);
    defer runner.deinit();

    try runner.run(&.{ "git", "init" });
    try runner.run(&.{ "git", "config", "user.email", "you@example.com" });
    try runner.run(&.{ "git", "config", "user.name", "Your Name" });

    try runner.writeFile("birds", "sparrow robin");
    try runner.run(&.{ "git", "add", "birds" });
    try runner.run(&.{ "git", "commit", "-m", "initial commit" });

    try runner.writeFile("birds", "cardinal");
    try runner.run(&.{ "git", "add", "birds" });

    {
        const result = try runner.ctx(&.{"init"});
        defer allocator.free(result.stdout);
        defer allocator.free(result.stderr);
    }

    {
        const result = try runner.ctx(&.{ "merge-base", "HEAD" });
        defer allocator.free(result.stdout);
        defer allocator.free(result.stderr);
    }

    {
        const result = try runner.ctx(&.{"status"});
        defer allocator.free(result.stdout);
        defer allocator.free(result.stderr);

        const want = try std.mem.replaceOwned(u8, allocator,
            \\Estimated token count: 59
            \\Merge base: HEAD
            \\Modified:
            \\{Tab}birds
            \\Paths:
        , "{Tab}", "\t");
        defer allocator.free(want);

        std.testing.expect(result.term == .Exited and result.term.Exited == 0) catch |err| {
            std.debug.print("stdout: {s}\n", .{result.stdout});
            std.debug.print("stderr: {s}\n", .{result.stderr});
            return err;
        };

        std.testing.expect(std.mem.containsAtLeast(u8, result.stdout, 1, want)) catch |err| {
            std.debug.print("stdout: {s}\n", .{result.stdout});
            std.debug.print("stderr: {s}\n", .{result.stderr});
            return err;
        };
    }

    try runner.writeFile(".ctxignore", "birds");

    {
        const result = try runner.ctx(&.{"status"});
        defer allocator.free(result.stdout);
        defer allocator.free(result.stderr);

        const want =
            \\Estimated token count: 51
            \\Merge base: HEAD
            \\Modified:
            \\Paths:
        ;

        std.testing.expect(result.term == .Exited and result.term.Exited == 0) catch |err| {
            std.debug.print("stdout: {s}\n", .{result.stdout});
            std.debug.print("stderr: {s}\n", .{result.stderr});
            return err;
        };

        std.testing.expect(std.mem.containsAtLeast(u8, result.stdout, 1, want)) catch |err| {
            std.debug.print("stdout: {s}\n", .{result.stdout});
            std.debug.print("stderr: {s}\n", .{result.stderr});
            return err;
        };
    }
}

test "print diff and current file contents" {
    var runner = try Runner.init(allocator);
    defer runner.deinit();

    try runner.run(&.{ "git", "init" });
    try runner.run(&.{ "git", "config", "user.email", "you@example.com" });
    try runner.run(&.{ "git", "config", "user.name", "Your Name" });
    try runner.run(&.{ "git", "config", "diff.mnemonicPrefix", "false" });

    try runner.writeFile("birds", "sparrow\nrobin\n");
    try runner.run(&.{ "git", "add", "birds" });
    try runner.run(&.{ "git", "commit", "-m", "initial commit" });

    try runner.writeFile("birds", "sparrow\ncardinal\n");
    try runner.run(&.{ "git", "add", "birds" });

    var result = try runner.ctx(&.{"init"});
    allocator.free(result.stdout);
    allocator.free(result.stderr);

    result = try runner.ctx(&.{ "merge-base", "HEAD" });
    allocator.free(result.stdout);
    allocator.free(result.stderr);

    result = try runner.ctx(&.{"show"});
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    const want =
        \\# Diff
        \\
        \\```diff
        \\diff --git a/birds b/birds
        \\index 739e843..ae9d5cc 100644
        \\--- a/birds
        \\+++ b/birds
        \\@@ -1,2 +1,2 @@
        \\ sparrow
        \\-robin
        \\+cardinal
        \\```
        \\
        \\# Files
        \\
        \\```text path=birds
        \\sparrow
        \\cardinal
        \\```
    ;

    std.testing.expect(result.term == .Exited and result.term.Exited == 0) catch |err| {
        std.debug.print("stdout: {s}\n", .{result.stdout});
        std.debug.print("stderr: {s}\n", .{result.stderr});
        return err;
    };

    std.testing.expect(std.mem.containsAtLeast(u8, result.stdout, 1, want)) catch |err| {
        std.debug.print("stdout: {s}\n", .{result.stdout});
        std.debug.print("stderr: {s}\n", .{result.stderr});
        return err;
    };
}

