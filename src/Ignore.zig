const std = @import("std");

const Ignore = @This();

const c = @cImport({
    @cInclude("fnmatch.h");
});

allocator: std.mem.Allocator,
patterns: [][:0]const u8,

/// Free all allocated memory.
pub fn deinit(self: *Ignore) void {
    for (self.patterns) |pattern| self.allocator.free(pattern);
}

const file_path = ".ctxignore";

/// Load patterns from a given file.
pub fn load(allocator: std.mem.Allocator) !Ignore {
    var file = std.fs.cwd().openFile(file_path, .{}) catch {
        // When the file does not exist, return an empty ignore list.
        return .{ .allocator = allocator, .patterns = &.{} };
    };

    defer file.close();

    var buffered_reader = std.io.bufferedReader(file.reader());
    var reader = buffered_reader.reader();

    var patterns = std.ArrayList([:0]const u8).init(allocator);
    while (try reader.readUntilDelimiterOrEofAlloc(allocator, '\n', 1024)) |line| {
        const trimmed = std.mem.trim(u8, line, " \t\r\n");
        if (trimmed.len == 0 or trimmed[0] == '#') continue;
        const copy = try allocator.dupeZ(u8, trimmed);
        try patterns.append(copy);
    }

    return .{ .allocator = allocator, .patterns = try patterns.toOwnedSlice() };
}

/// True if `path` matches any stored pattern (first match wins).
pub fn isIgnored(self: *const Ignore, path: []const u8) !bool {
    const copy = try self.allocator.dupeZ(u8, path);
    defer self.allocator.free(copy);
    for (self.patterns) |pattern| if (c.fnmatch(pattern, copy, c.FNM_PATHNAME) == 0) return true;
    return false;
}

