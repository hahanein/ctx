const std = @import("std");
const alloc = std.testing.allocator;
const Child = std.process.Child;
const build_options = @import("build_options");

const exe_path = "zig-out/bin/ctx";

test "usage message with correct exit code" {
    const tmp_dir = std.testing.tmpDir(.{});
    const exe_abs_path = try std.fs.realpathAlloc(alloc, exe_path);
    defer alloc.free(exe_abs_path);

    const result = try Child.run(.{ .argv = &.{exe_abs_path}, .cwd_dir = tmp_dir.dir, .allocator = alloc });
    defer alloc.free(result.stdout);
    defer alloc.free(result.stderr);

    try std.testing.expect(result.term == .Exited and result.term.Exited == 2);
    try std.testing.expect(std.mem.containsAtLeast(u8, result.stderr, 1, "ctx - A command line tool for building prompt context files"));
}

test "print version" {
    const result = try Child.run(.{ .argv = &.{ exe_path, "version" }, .allocator = alloc });
    defer alloc.free(result.stdout);
    defer alloc.free(result.stderr);

    const want = "ctx version v" ++ build_options.version;
    try std.testing.expect(std.mem.containsAtLeast(u8, result.stderr, 1, want));
}

