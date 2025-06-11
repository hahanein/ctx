const std = @import("std");

const Context = @import("Context.zig");
const diff = @import("diff.zig");
const Ignore = @import("Ignore.zig");

/// Write the context to the given writer.
pub fn write(writer: anytype, ctx: *Context, ignore: *const Ignore, allocator: std.mem.Allocator) !void {
    // Write diff
    if (ctx.merge_base.len > 0) {
        try writer.writeAll("# Diff\n\n```diff\n");
        try diff.write(writer, ctx.merge_base, ignore, allocator);
        try writer.writeAll("```\n\n");
    }

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
        if (try ignore.isIgnored(path.*)) continue;

        var file = std.fs.cwd().openFile(path.*, .{}) catch {
            try std.fmt.format(writer, "**Deleted:** `{s}`\n\n", .{path.*});
            continue;
        };

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

