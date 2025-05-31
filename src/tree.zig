const std = @import("std");

/// Write the list of files in the current git repository to the given writer.
pub fn write(writer: anytype, allocator: std.mem.Allocator) !void {
    var child = std.process.Child.init(&.{ "git", "ls-tree", "-r", "--name-only", "HEAD" }, allocator);
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Ignore;

    try child.spawn();

    const stdout = child.stdout orelse unreachable;
    const reader = stdout.reader();

    var fifo = std.fifo.LinearFifo(u8, .{ .Static = 4096 }).init();
    try fifo.pump(reader, writer);

    _ = try child.wait();
}

