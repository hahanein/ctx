const std = @import("std");

const tree = @import("tree.zig");

pub const Context = struct {
    paths: std.StringHashMap(void),
    branch: ?[]const u8 = null,

    pub fn init(allocator: std.mem.Allocator) Context {
        return .{
            .paths = std.StringHashMap(void).init(allocator),
            .branch = null,
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
        // Write directory overview
        try writer.writeAll("# Directory view\n\n```\n");
        try tree.write(writer, allocator);
        try writer.writeAll("```\n\n");

        // Write files
        try writer.writeAll("# Files\n\n");

        var it = self.context.paths.keyIterator();
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

