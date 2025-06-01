const std = @import("std");

const context = @import("context.zig");
const renderer = @import("renderer.zig");

pub fn write(writer: anytype, ctx: *context.Context, allocator: std.mem.Allocator) !void {
    var counter = CountingWriter().init();
    try renderer.write(counter.writer(), ctx, allocator);
    try std.fmt.format(writer, "Estimated tokens: {}\n", .{counter.tokens()});
}

fn CountingWriter() type {
    return struct {
        count: usize = 0,

        pub fn init() @This() {
            return .{};
        }

        pub fn tokens(self: *@This()) usize {
            return self.count / 4;
        }

        pub fn writeImpl(self: *@This(), data: []const u8) error{}!usize {
            self.count += data.len;
            return data.len;
        }

        pub fn writer(self: *@This()) std.io.Writer(*@This(), error{}, writeImpl) {
            return .{ .context = self };
        }
    };
}

