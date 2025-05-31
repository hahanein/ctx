const std = @import("std");

pub const Context = struct {
    files: std.StringHashMap(void),
    branch: ?[]const u8 = null,

    pub fn init(alloc: std.mem.Allocator) Context {
        return .{
            .files = std.StringHashMap(void).init(alloc),
            .branch = null,
        };
    }

    pub fn merge(self: *Context, branch: []const u8) void {
        self.branch = branch;
    }

    pub fn merge_abort(self: *Context) void {
        self.branch = null;
    }

    pub fn add(self: *Context, paths: []const []const u8) !void {
        for (paths) |p| _ = try self.files.put(p, {});
    }

    pub fn rm(self: *Context, paths: []const []const u8) void {
        for (paths) |p| _ = self.files.remove(p);
    }
};

