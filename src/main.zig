const std = @import("std");
const context = @import("context.zig");
const storage = @import("storage.zig");

const usage =
    \\ctx - A git-style command line tool
    \\
    \\Usage: ctx <command> [arguments]
    \\
    \\Commands:
    \\  init             Create new context
    \\  add <file>...    Add files
    \\  rm <file>...     Remove files
    \\  help             Show this help message
    \\
;

const status = struct {
    pub const success = 0;
    pub const failure = 1;
    pub const usage = 2;
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();

    const alloc = arena.allocator();
    const args = try std.process.argsAlloc(alloc);

    if (args.len < 2) {
        std.debug.print("{s}", .{usage});
        std.process.exit(status.usage);
    }

    const command = args[1];
    if (std.mem.eql(u8, command, "init")) {
        try storage.write(&context.Context.init(alloc));
    } else if (std.mem.eql(u8, command, "add")) {
        @panic("TODO: not implemented yet");
    } else if (std.mem.eql(u8, command, "rm")) {
        @panic("TODO: not implemented yet");
    } else if (std.mem.eql(u8, command, "help")) {
        std.debug.print("{s}", .{usage});
    } else {
        std.debug.print("Unknown command: {s}\n{s}", .{ command, usage });
        std.process.exit(status.usage);
    }
}

