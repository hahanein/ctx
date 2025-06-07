const Context = @This();

const std = @import("std");

const diff = @import("diff.zig");

paths: std.StringHashMap(void),
merge_base: []const u8 = "",

/// Initialize a new context.
pub fn init(allocator: std.mem.Allocator) Context {
    return .{
        .paths = std.StringHashMap(void).init(allocator),
        .merge_base = "",
    };
}

/// Add paths to the context.
pub fn add(self: *Context, paths: []const []const u8) !void {
    for (paths) |path| _ = try self.paths.put(path, {});
}

/// Remove paths from the context.
pub fn rm(self: *Context, paths: []const []const u8) void {
    for (paths) |path| _ = self.paths.remove(path);
}

