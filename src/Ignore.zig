const std = @import("std");

const Ignore = @This();

const c = @cImport({
    @cInclude("fnmatch.h");
});

allocator: std.mem.Allocator,
patterns: [][:0]const u8,

/// Load patterns from a given file.
pub fn parse(file_path: []const u8, allocator: std.mem.Allocator) !Ignore {
    var file = try std.fs.cwd().openFile(file_path, .{});

    defer file.close();

    var buffered_reader = std.io.bufferedReader(file.reader());
    var reader = buffered_reader.reader();

    var patterns = std.ArrayList([:0]const u8).init(allocator);
    while (try reader.readUntilDelimiterOrEofAlloc(allocator, '\n', 1024)) |line| {
        defer allocator.free(line);
        const trimmed = std.mem.trim(u8, line, " \t\r\n");
        if (trimmed.len == 0 or trimmed[0] == '#') continue;
        const copy = try allocator.dupeZ(u8, trimmed);
        try patterns.append(copy);
    }

    return .{ .allocator = allocator, .patterns = try patterns.toOwnedSlice() };
}

/// Release all memory.
pub fn deinit(self: *Ignore) void {
    for (self.patterns) |pattern| self.allocator.free(pattern);
    self.allocator.free(self.patterns);
}

/// True if `path` matches any stored pattern (first match wins).
pub fn isIgnored(self: *const Ignore, path: []const u8) !bool {
    const copy = try self.allocator.dupeZ(u8, path);
    defer self.allocator.free(copy);
    for (self.patterns) |pattern| if (c.fnmatch(pattern, copy, c.FNM_PATHNAME) == 0) return true;
    return false;
}

