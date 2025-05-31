const std = @import("std");
const context = @import("context.zig");

const usage =
    \\ctx - A git-style command line tool
    \\
    \\Usage: ctx <command> [arguments]
    \\
    \\Commands:
    \\  init             Create new context
    \\  add <file>...    Add files
    \\  help             Show this help message
    \\
;

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        std.debug.print("{s}", .{usage});
        return;
    }

    const command = args[1];
    if (std.mem.eql(u8, command, "init")) {
        try handleInit(allocator);
    } else if (std.mem.eql(u8, command, "add")) {
        if (args.len < 3) {
            std.debug.print("Error: no files specified\nUsage: ctx add <file>...\n", .{});
            return;
        }
        try handleAdd(allocator, args[2..]);
    } else if (std.mem.eql(u8, command, "help") or std.mem.eql(u8, command, "-h") or std.mem.eql(u8, command, "--help")) {
        std.debug.print("{s}", .{usage});
    } else {
        std.debug.print("Unknown command: {s}\n{s}", .{ command, usage });
    }
}

fn handleInit(allocator: *std.mem.Allocator) !void {
    var ctx = context.Context.init(allocator);
    defer ctx.deinit();

    try ctx.write();
}

fn handleAdd(allocator: *std.mem.Allocator, files: []const []const u8) !void {
    var ctx = context.Context.init(allocator);
    defer ctx.deinit();

    _ = ctx.read(allocator) catch {};

    try ctx.add(files);
    try ctx.write();

    for (files) |file| {
        std.debug.print("Adding file: {s}\n", .{file});
    }
}
