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

pub const FileSystemContext = struct {
    context: Context,

    pub fn init(allocator: std.mem.Allocator) FileSystemContext {
        return .{
            .context = Context.init(allocator),
        };
    }

    pub fn show(self: *FileSystemContext, writer: anytype, allocator: std.mem.Allocator) !void {
        // Write diff
        if (self.context.merge_base.len > 0) {
            try writer.writeAll("# Diff\n\n```diff\n");
            try diff.write(writer, self.context.merge_base, allocator);
            try writer.writeAll("```\n\n");
        }

        // Write directory overview
        try writer.writeAll("# Directory view\n\n```\n");
        try tree.write(writer, allocator);
        try writer.writeAll("```\n\n");

        // Write files
        try writer.writeAll("# Files\n\n");

        var clone = try self.context.paths.clone();
        if (self.context.merge_base.len > 0) {
            var it_ = try diff.PathIterator().init(self.context.merge_base, allocator);
            while (try it_.next()) |path| _ = try clone.put(path, {});
        }

        var it = clone.keyIterator();
        while (it.next()) |path| {
            var file = try std.fs.cwd().openFile(path.*, .{});
            defer file.close();

            const extension = std.fs.path.extension(path.*);
            const tag = if (extension.len == 0) "text" else extension[1..];

            try std.fmt.format(writer, "```{s} path={s}\n", .{ tag, path.* });

            var reader = file.reader();
            var buffer: [1024]u8 = undefined;

            while (true) {
                const bytes_read = try reader.read(&buffer);
                if (bytes_read == 0) break;
                try writer.writeAll(buffer[0..bytes_read]);
            }

            try writer.writeAll("```\n\n");
        }
    }
};

