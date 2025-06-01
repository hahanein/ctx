const std = @import("std");

const Context = @import("Context.zig");
const renderer = @import("renderer.zig");

pub fn write(writer: anytype, ctx: *Context, allocator: std.mem.Allocator) !void {
    var counter = TokenCounter().init();
    try renderer.write(counter.writer(), ctx, allocator);
    try std.fmt.format(writer, "Estimated token count: {}\n", .{counter.tokens()});
}

fn TokenCounter() type {
    return struct {
        count: usize = 0,

        pub fn init() @This() {
            return .{};
        }

        pub fn tokens(self: *@This()) usize {
            // One token generally corresponds to about 4 characters of text
            // for common English text.
            // We add 3 to round up.
            return (self.count + 3) / 4;
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

