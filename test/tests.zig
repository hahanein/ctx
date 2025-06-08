const std = @import("std");
const alloc = std.testing.allocator;
const Child = std.process.Child;

const exe_path = "zig-out/bin/ctx";

fn setup() void {
    const dir = std.testing.tmpDir(.{});
    std.fs.Dir.setAsCwd(dir);
}

test "usage message with correct exit code" {
    setup();

    const result = try Child.run(.{ .allocator = alloc, .argv = &.{exe_path} });
    defer alloc.free(result.stdout);
    defer alloc.free(result.stderr);

    try std.testing.expect(result.term == .Exited and result.term.Exited == 2);
    try std.testing.expect(std.mem.containsAtLeast(u8, result.stderr, 1, "ctx - A command line tool for building prompt context files"));
}

