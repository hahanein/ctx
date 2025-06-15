const std = @import("std");

const Context = @This();

/// A set of paths.
pub const PathSet = std.StringHashMap(void);

allocator: std.mem.Allocator,
paths: PathSet,
merge_base: std.ArrayList(u8),
workspace_root: []u8,

/// Initialize a new context.
pub fn init(allocator: std.mem.Allocator) Context {
    return .{
        .allocator = allocator,
        .paths = PathSet.init(allocator),
        .merge_base = std.ArrayList(u8).init(allocator),
        .workspace_root = std.fs.cwd().realpathAlloc(allocator, ".") catch unreachable,
    };
}

/// Deinitialize the context.
pub fn deinit(self: *Context) void {
    var it = self.paths.keyIterator();
    while (it.next()) |path| self.allocator.free(path.*);
    self.paths.deinit();
    self.merge_base.deinit();
    self.allocator.free(self.workspace_root);
}

/// Add paths to the context.
pub fn add(self: *Context, paths: []const []const u8) !void {
    for (paths) |path| _ = try self.paths.put(try self.relative(path), {});
}

/// Remove paths from the context.
pub fn rm(self: *Context, paths: []const []const u8) !void {
    for (paths) |path| if (self.paths.fetchRemove(try self.relative(path))) |pair| self.allocator.free(pair.key);
}

/// Compute the path relative to the workspace root.
fn relative(self: *Context, path: []const u8) ![]u8 {
    const cwd = try std.fs.cwd().realpathAlloc(self.allocator, ".");
    defer self.allocator.free(cwd);
    const resolved = if (std.fs.path.isAbsolute(path)) try self.allocator.dupe(u8, path) else try std.fs.path.join(self.allocator, &.{ cwd, path });
    defer self.allocator.free(resolved);
    return try std.fs.path.relative(self.allocator, self.workspace_root, resolved);
}

const magic = 0x4354_5800; // "CTX\0"
const version = 4;
const file_path = ".ctx";

/// Walk upwards until we find a directory that contains ".ctx".
/// Returns the absolute path of that directory.
fn findWorkspaceRoot(allocator: std.mem.Allocator) ![]u8 {
    var abs = try std.fs.cwd().realpathAlloc(allocator, ".");
    errdefer allocator.free(abs);

    var len: usize = abs.len;
    while (true) {
        var dir = try std.fs.openDirAbsolute(abs[0..len], .{});
        defer dir.close();

        if (dir.access(file_path, .{})) {
            // We found the workspace root..
            const out = try allocator.dupe(u8, abs[0..len]);
            allocator.free(abs);
            return out;
        } else |err| switch (err) {
            error.FileNotFound => {
                // Keep climbing..
            },
            else => return err,
        }

        // Trim trailing "/"..
        while (len > 1 and abs[len - 1] == '/') len -= 1;

        // Lop off the last path segment but stop if we are at the real root..
        const idx = std.mem.lastIndexOfScalar(u8, abs[0..len], '/') orelse break;

        // Keep the leading "/"..
        len = if (idx == 0) 1 else idx;
    }

    return error.WorkspaceFileNotFound;
}

/// Parse a context from a file.
pub fn load(allocator: std.mem.Allocator) !Context {
    const workspace_root = try findWorkspaceRoot(allocator);

    var workspace_dir = try std.fs.openDirAbsolute(workspace_root, .{});
    defer workspace_dir.close();

    const file = try workspace_dir.openFile(file_path, .{});
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
        .workspace_root = workspace_root,
    };
}
/// Write the context to a file.
pub fn save(self: *const Context) !void {
    var workspace_dir = try std.fs.openDirAbsolute(self.workspace_root, .{});
    defer workspace_dir.close();

    const file = try workspace_dir.createFile(file_path, .{ .truncate = true });
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

