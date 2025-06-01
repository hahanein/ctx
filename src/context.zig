const std = @import("std");

const tree = @import("tree.zig");
const diff = @import("diff.zig");

pub const Context = struct {
    paths: std.StringHashMap(void),
    merge_base: []const u8 = "",

    pub fn init(allocator: std.mem.Allocator) Context {
        return .{
            .paths = std.StringHashMap(void).init(allocator),
            .merge_base = "",
        };
    }

    pub fn add(self: *Context, paths: []const []const u8) !void {
        for (paths) |path| _ = try self.paths.put(path, {});
    }

    pub fn rm(self: *Context, paths: []const []const u8) void {
        for (paths) |path| _ = self.paths.remove(path);
    }
};

