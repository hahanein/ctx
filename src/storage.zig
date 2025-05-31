const std = @import("std");
const context = @import("./context.zig");

const file_name = ".ctx";

/// Write the context to the file.
pub fn write(ctx: *const context.Context) !void {
    const file = try std.fs.cwd().createFile(file_name, .{ .truncate = true });
    defer file.close();

    const writer = file.writer();

    if (ctx.branch) |b| {
        try writer.print("branch: {s}\n", .{b});
    }

    if (ctx.files.count() > 0) {
        try writer.writeAll("files:\n");
        var it = ctx.files.keyIterator();
        while (it.next()) |s| {
            try writer.writeAll(s.*);
            try writer.writeByte('\n');
        }
    }
}

/// Read the context from the file.
pub fn read(ctx: *context.Context, allocator: *std.mem.Allocator) !void {
    const file = std.fs.cwd().openFile(file_name, .{}) catch return;
    defer file.close();

    var buf_reader = std.io.bufferedReader(file.reader());
    const reader = buf_reader.reader();

    ctx.files.clearRetainingCapacity();
    ctx.branch = null;

    var line = std.ArrayList(u8).init(allocator);
    defer line.deinit();
    const writer = line.writer();

    var in_files = false;
    while (reader.streamUntilDelimiter(writer, '\n', null)) {
        if (line.len == 0) {
            continue;
        } else if (std.mem.startsWith(u8, line, "branch:")) {
            const rest = std.mem.trimLeft(u8, line["branch:".len..], " \t");
            ctx.branch = rest;
            in_files = false;
        } else if (std.mem.eql(u8, line, "files:")) {
            in_files = true;
        } else if (in_files) {
            _ = try ctx.files.put(line, {});
        } else {
            return error.InvalidFormat; // stray line before "files:"
        }
    }
}

