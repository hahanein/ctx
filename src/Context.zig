const std = @import("std");

const Context = @This();

/// A set of paths.
pub const PathSet = std.StringHashMap(void);

allocator: std.mem.Allocator,
paths: PathSet,
merge_base: std.ArrayList(u8),

/// Initialize a new context.
pub fn init(allocator: std.mem.Allocator) Context {
    return .{ .allocator = allocator, .paths = PathSet.init(allocator), .merge_base = std.ArrayList(u8).init(allocator) };
}

/// Deinitialize the context.
pub fn deinit(self: *Context) void {
    var it = self.paths.keyIterator();
    while (it.next()) |path| self.allocator.free(path.*);
    self.paths.deinit();
    self.merge_base.deinit();
}

/// Add paths to the context.
pub fn add(self: *Context, paths: []const []const u8) !void {
    for (paths) |path| _ = try self.paths.put(path, {});
}

/// Remove paths from the context.
pub fn rm(self: *Context, paths: []const []const u8) void {
    for (paths) |path| _ = self.paths.remove(path);
}

const magic = 0x4354_5800; // "CTX\0"
const version = 4;

/// Parse a context from a file.
pub fn parseFile(file_path: []const u8, allocator: std.mem.Allocator) !Context {
    const file = try std.fs.cwd().openFile(file_path, .{});
    defer file.close();
    const reader = file.reader();

    // validate header
    const file_magic = try reader.readInt(u32, std.builtin.Endian.little);
    if (file_magic != magic) return error.InvalidFormat;
    const version_ = try reader.readByte();
    if (version_ != version) return error.UnsupportedVersion;

    // merge base
    const b_len = try reader.readInt(u32, std.builtin.Endian.little);
    const merge_base = try allocator.alloc(u8, b_len);
    try reader.readNoEof(merge_base);

    // paths
    var paths = PathSet.init(allocator);
    var remaining = try reader.readInt(u64, std.builtin.Endian.little);
    while (remaining > 0) : (remaining -= 1) {
        const n_len = try reader.readInt(u32, std.builtin.Endian.little);
        const path = try allocator.alloc(u8, n_len);
        try reader.readNoEof(path);
        _ = try paths.put(path, {});
    }

    return .{
        .allocator = allocator,
        .paths = paths,
        .merge_base = std.ArrayList(u8).fromOwnedSlice(allocator, merge_base),
    };
}

/// Write the context to a file.
pub fn writeFile(self: *const Context, file_path: []const u8) !void {
    const file = try std.fs.cwd().createFile(file_path, .{ .truncate = true });
    defer file.close();
    const writer = file.writer();

    // header
    try writer.writeInt(u32, magic, std.builtin.Endian.little); // magic
    try writer.writeByte(version); // version

    // merge base
    const merge_base_len32 = std.math.cast(u32, self.merge_base.items.len) orelse return error.StringTooLong;
    try writer.writeInt(u32, merge_base_len32, std.builtin.Endian.little);
    try writer.writeAll(self.merge_base.items);

    // paths
    try writer.writeInt(u64, @intCast(self.paths.count()), std.builtin.Endian.little);
    var it = self.paths.keyIterator();
    while (it.next()) |path| {
        const len32 = std.math.cast(u32, path.*.len) orelse return error.StringTooLong;
        try writer.writeInt(u32, len32, std.builtin.Endian.little);
        try writer.writeAll(path.*);
    }
}

