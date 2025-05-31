const std = @import("std");

const context = @import("./context.zig");

const file_name = ".ctx";
const magic = 0x4354_5800; // "CTX\0"
const version = 2;

/// Writes the context to the file.
pub fn write(ctx: *const context.Context) !void {
    const file = try std.fs.cwd().createFile(file_name, .{ .truncate = true });
    defer file.close();
    const w = file.writer();

    // header
    try w.writeInt(u32, magic, std.builtin.Endian.little); // magic
    try w.writeByte(version); // version
    try w.writeByte(if (ctx.branch == null) 0 else 1);

    // optional branch
    if (ctx.branch) |b| {
        try w.writeInt(u32, @intCast(b.len), std.builtin.Endian.little);
        try w.writeAll(b);
    }

    // paths
    try w.writeInt(u32, @intCast(ctx.paths.count()), std.builtin.Endian.little);
    var it = ctx.paths.keyIterator();
    while (it.next()) |path| {
        try w.writeInt(u32, @intCast(path.*.len), std.builtin.Endian.little);
        try w.writeAll(path.*);
    }
}

/// Reads the context from the file.
pub fn read(ctx: *context.Context, allocator: std.mem.Allocator) !void {
    const file = std.fs.cwd().openFile(file_name, .{}) catch return;
    defer file.close();
    const r = file.reader();

    // validate header
    const file_magic = try r.readInt(u32, std.builtin.Endian.little);
    if (file_magic != magic) return error.InvalidFormat;
    const version_ = try r.readByte();
    if (version_ != version) return error.UnsupportedVersion;
    const has_branch = try r.readByte() != 0;

    // reset context
    ctx.paths.clearRetainingCapacity();
    ctx.branch = null;

    // branch
    if (has_branch) {
        const b_len = try r.readInt(u32, std.builtin.Endian.little);
        const buf = try allocator.alloc(u8, b_len);
        try r.readNoEof(buf);
        ctx.branch = buf;
    }

    // paths
    const count = try r.readInt(u32, std.builtin.Endian.little);
    var i: u32 = 0;
    while (i < count) : (i += 1) {
        const n_len = try r.readInt(u32, std.builtin.Endian.little);
        const path = try allocator.alloc(u8, n_len);
        try r.readNoEof(path);
        _ = try ctx.paths.put(path, {});
    }
}

