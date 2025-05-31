const std = @import("std");

pub const file_name = ".ctx";

pub const Context = struct {
    files: std.StringHashMap(void),

    pub fn init(allocator: *std.mem.Allocator) Context {
        return Context{ .files = std.StringHashMap(void).init(allocator) };
    }

    pub fn deinit(self: *Context) void {
        self.files.deinit();
    }

    pub fn add(self: *Context, files: []const []const u8) !void {
        for (files) |file| {
            try self.files.put(file, {});
        }
    }

    pub fn rm(self: *Context, files: []const []const u8) void {
        for (files) |file| {
            _ = self.files.remove(file);
        }
    }

    pub fn write(self: *Context) !void {
        const file = try std.fs.cwd().createFile(file_name, .{ .truncate = true });
        defer file.close();

        var writer = std.json.StringifyWriter.init(file.writer());
        try writer.beginObject();

        var it = self.files.iterator();
        while (it.next()) |entry| {
            try writer.objectField(entry.key_ptr.*);
            try writer.writeNull();
        }

        try writer.endObject();
    }

    pub fn read(self: *Context, allocator: *std.mem.Allocator) !void {
        const file = std.fs.cwd().openFile(file_name, .{}) catch return;
        defer file.close();

        const contents = try file.readToEndAlloc(allocator, 1 << 20);
        defer allocator.free(contents);

        const parsed = try std.json.parseFromSlice(std.json.Value, allocator, contents, .{});
        defer parsed.deinit();

        const obj = parsed.value.object orelse return error.InvalidFormat;

        for (obj.items) |item| {
            try self.files.put(item.key, {});
        }
    }
};
