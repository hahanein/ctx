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

    try runner.dash(
        \\ git init
        \\ git config user.email you@example.com
        \\ git config user.name "Your Name"
        \\ echo "sparrow robin" > birds
        \\ echo "rose tulip" > flowers
        \\ git add birds flowers
        \\ git commit -m "initial commit"
        \\ echo "cardinal" > birds
        \\ echo "orchid lily" > flowers
        \\ git add birds flowers
        \\ git commit -m "update birds and flowers"
        \\
        \\ ctx init
        \\ ctx merge-base HEAD~1
    );

    const result = try runner.ctx(&.{"status"});
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    const want = try std.mem.replaceOwned(u8, allocator,
        \\Estimated token count: 57
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

    try runner.dash(
        \\ git init
        \\ git config user.email you@example.com
        \\ git config user.name "Your Name"
        \\ echo "sparrow robin" > birds
        \\ git add birds
        \\ git commit -m "initial commit"
        \\ echo "cardinal" > birds
        \\ git add birds
        \\
        \\ ctx init
        \\ ctx merge-base HEAD
    );

    {
        const result = try runner.ctx(&.{"status"});
        defer allocator.free(result.stdout);
        defer allocator.free(result.stderr);

        const want = try std.mem.replaceOwned(u8, allocator,
            \\Estimated token count: 46
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

    try runner.dash(
        \\ echo "birds" > .ctxignore
    );

    {
        const result = try runner.ctx(&.{"status"});
        defer allocator.free(result.stdout);
        defer allocator.free(result.stderr);

        const want =
            \\Estimated token count: 37
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

    try runner.dash(
        \\ git init
        \\ git config user.email you@example.com
        \\ git config user.name "Your Name"
        \\ git config diff.mnemonicPrefix false
        \\ echo "sparrow\nrobin\n" > birds
        \\ git add birds
        \\ git commit -m "initial commit"
        \\ echo "sparrow\ncardinal\n" > birds
        \\ git add birds
        \\
        \\ ctx init
        \\ ctx merge-base HEAD
    );

    const result = try runner.ctx(&.{"show"});
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    const want =
        \\# Diff
        \\
        \\```diff
        \\diff --git a/birds b/birds
        \\index 9bdcdf2..c99a016 100644
        \\--- a/birds
        \\+++ b/birds
        \\@@ -1,3 +1,3 @@
        \\ sparrow
        \\-robin
        \\+cardinal
        \\ 
        \\```
        \\
        \\# Files
        \\
        \\```text path=birds
        \\sparrow
        \\cardinal
        \\
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

