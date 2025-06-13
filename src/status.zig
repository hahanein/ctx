const std = @import("std");

const Context = @import("Context.zig");
const renderer = @import("renderer.zig");
const diff = @import("diff.zig");
const Ignore = @import("Ignore.zig");

pub fn write(writer: anytype, ctx: *Context, ignore: *const Ignore, allocator: std.mem.Allocator) !void {
    {
        var counter = TokenCounter().init();
        try renderer.write(counter.writer(), ctx, ignore, allocator);
        try std.fmt.format(writer, "Estimated token count: {}\n", .{counter.tokens()});
    }

    {
        try std.fmt.format(writer, "Merge base: {s}\n", .{ctx.merge_base.items});
        _ = try writer.write("Modified:\n");
        var it = try diff.PathIterator().init(ctx.merge_base.items, allocator);
        while (try it.next()) |path| {
            if (try ignore.isIgnored(path)) continue;
            try std.fmt.format(writer, "\t{s}\n", .{path});
        }
    }

    {
        _ = try writer.write("Paths:\n");
        var it = ctx.paths.keyIterator();
        while (it.next()) |path| {
            if (try ignore.isIgnored(path.*)) continue;
            try std.fmt.format(writer, "\t{s}\n", .{path.*});
        }
    }
}

fn TokenCounter() type {
    return struct {
        count: usize = 0,

        pub fn init() @This() {
            return .{};
        }

        pub fn tokens(self: *@This()) usize {
            // One token generally corresponds to about 4 characters of text
            // for common English text. We add 3 to round up.
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

