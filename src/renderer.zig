const std = @import("std");

const Context = @import("Context.zig");
const diff = @import("diff.zig");
const Ignore = @import("Ignore.zig");

/// Write the context to the given writer.
pub fn write(writer: anytype, ctx: *Context, ignore: *const Ignore, allocator: std.mem.Allocator) !void {
    // Write diff
    if (ctx.merge_base.items.len > 0) {
        try writer.writeAll("# Diff\n\n```diff\n");
        try diff.write(writer, ctx.merge_base.items, ignore, allocator);
        try writer.writeAll("```\n\n");
    }

    // Write files
    try writer.writeAll("# Files\n\n");

    {
        // Write files computed from diff..
        var it = try diff.PathIterator().init(ctx.merge_base.items, allocator);
        while (try it.next()) |path| {
            // Skip files that are specified in the context paths as we will
            // print them below.
            if (ctx.paths.contains(path)) continue;
            if (try ignore.isIgnored(path)) continue;
            try writeFile(writer, path);
        }
    }

    {
        // Write files added by user..
        var it = ctx.paths.keyIterator();
        while (it.next()) |path| {
            if (try ignore.isIgnored(path.*)) continue;
            try writeFile(writer, path.*);
        }
    }
}

/// Write the file at the given path to the given writer.
fn writeFile(writer: anytype, path: []const u8) !void {
    var file = std.fs.cwd().openFile(path, .{}) catch {
        try std.fmt.format(writer, "**Deleted:** `{s}`\n\n", .{path});
        return;
    };

    defer file.close();

    const extension = std.fs.path.extension(path);
    const tag = if (extension.len == 0) "text" else extension[1..];

    try std.fmt.format(writer, "```{s} path={s}\n", .{ tag, path });

    const reader = file.reader();

    var fifo = std.fifo.LinearFifo(u8, .{ .Static = 4096 }).init();
    try fifo.pump(reader, writer);

    try writer.writeAll("```\n\n");
}

