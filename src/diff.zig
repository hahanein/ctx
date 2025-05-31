const std = @import("std");

/// Write the diff to the given writer.
pub fn write(writer: anytype, merge_base: []const u8, allocator: std.mem.Allocator) !void {
    var child = std.process.Child.init(&.{ "git", "diff", "--relative", "--minimal", "--cached", "--merge-base", merge_base }, allocator);
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Ignore;

    try child.spawn();

    const stdout = child.stdout orelse unreachable;
    const reader = stdout.reader();

    var fifo = std.fifo.LinearFifo(u8, .{ .Static = 4096 }).init();
    try fifo.pump(reader, writer);

    _ = try child.wait();
}

/// An iterator over the paths in the diff.
pub fn PathIterator() type {
    return struct {
        child: std.process.Child,
        buf_read: std.io.BufferedReader(4096, std.fs.File.Reader),
        line: std.ArrayList(u8),
        allocator: std.mem.Allocator,
        done: bool = false,

        pub fn init(merge_base: []const u8, allocator: std.mem.Allocator) !@This() {
            var child = std.process.Child.init(
                &.{ "git", "diff", "--relative", "--name-only", "--minimal", "--cached", "--merge-base", merge_base },
                allocator,
            );
            child.stdout_behavior = .Pipe;
            child.stderr_behavior = .Ignore;

            try child.spawn();

            const stdout = child.stdout orelse unreachable;
            const buf_read = std.io.bufferedReader(stdout.reader());
            const line = std.ArrayList(u8).init(allocator);

            return .{
                .child = child,
                .buf_read = buf_read,
                .line = line,
                .allocator = allocator,
            };
        }

        /// Return the next path (owned slice) or `null` at EOF.
        pub fn next(self: *@This()) !?[]const u8 {
            if (self.done) return null;

            // The Reader is created on demand from the live buf_read.
            self.buf_read.reader().streamUntilDelimiter(self.line.writer(), '\n', null) catch |err| switch (err) {
                error.EndOfStream => {
                    _ = try self.child.wait();
                    self.done = true;
                    return null;
                },
                else => return err,
            };

            // Trim trailing newline if present.
            if (self.line.items.len > 0 and self.line.items[self.line.items.len - 1] == '\n') {
                self.line.items.len -= 1;
            }

            // Turn the ArrayList into an owned slice and hand it off.
            return try self.line.toOwnedSlice();
        }
    };
}

