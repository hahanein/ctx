const std = @import("std");

const context = @import("context.zig");
const diff = @import("diff.zig");
const tree = @import("tree.zig");

/// Write the context to the given writer.
pub fn write(writer: anytype, ctx: *context.Context, allocator: std.mem.Allocator) !void {
    // Write diff
    if (ctx.merge_base.len > 0) {
        try writer.writeAll("# Diff\n\n```diff\n");
        try diff.write(writer, ctx.merge_base, allocator);
        try writer.writeAll("```\n\n");
    }

    // Write directory overview
    try writer.writeAll("# Directory view\n\n```\n");
    try tree.write(writer, allocator);
    try writer.writeAll("```\n\n");

    // Write files
    try writer.writeAll("# Files\n\n");

    var clone = try ctx.paths.clone();
    defer clone.deinit();
    if (ctx.merge_base.len > 0) {
        var it = try diff.PathIterator().init(ctx.merge_base, allocator);
        while (try it.next()) |path| _ = try clone.put(path, {});
    }

    var it = clone.keyIterator();
    while (it.next()) |path| {
        var file = try std.fs.cwd().openFile(path.*, .{});
        defer file.close();

        const extension = std.fs.path.extension(path.*);
        const tag = if (extension.len == 0) "text" else extension[1..];

        try std.fmt.format(writer, "```{s} path={s}\n", .{ tag, path.* });

        const reader = file.reader();

        var fifo = std.fifo.LinearFifo(u8, .{ .Static = 4096 }).init();
        try fifo.pump(reader, writer);

        try writer.writeAll("```\n\n");
    }
}

