const std = @import("std");
const allocator = std.testing.allocator;
const build_options = @import("build_options");
const Runner = @import("Runner.zig");

test "usage message with correct exit code" {
    var runner = try Runner.init(allocator);
    defer runner.deinit();

    const result = try runner.ctx(&.{});
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    try std.testing.expect(result.term == .Exited and result.term.Exited == 2);
    try std.testing.expect(std.mem.containsAtLeast(u8, result.stderr, 1, "ctx - A command line tool for building prompt context files"));
}

test "print version" {
    var runner = try Runner.init(allocator);
    defer runner.deinit();

    const result = try runner.ctx(&.{"version"});
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    const want = "ctx version v" ++ build_options.version;
    try std.testing.expect(std.mem.containsAtLeast(u8, result.stdout, 1, want));
}

test "print modified" {
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

    try runner.writeFile(".ctxignore", ""); // FIXME(BW): Must be removed with #6

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

    try std.testing.expect(result.term == .Exited and result.term.Exited == 0);
    try std.testing.expect(std.mem.containsAtLeast(u8, result.stdout, 1, want));
}

