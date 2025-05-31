const std = @import("std");

pub fn write(writer: anytype, branch: []const u8, allocator: std.mem.Allocator) !void {
    var child = std.process.Child.init(&.{ "git", "diff", "--minimal", "--cached", "merge-base", branch }, allocator);
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Ignore;

    try child.spawn();

    const stdout = child.stdout.?;
    var reader = stdout.reader();

    var buf: [4096]u8 = undefined;

    while (true) {
        const read_len = try reader.read(&buf);
        if (read_len == 0) break;
        try writer.writeAll(buf[0..read_len]);
    }

    _ = try child.wait();
}

