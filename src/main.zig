const std = @import("std");
const context = @import("context.zig");
const storage = @import("storage.zig");

/// Usage message
const usage =
    \\ctx - A command line tool for building prompt context files for
    \\large-language models.
    \\
    \\Usage: ctx <command> [arguments]
    \\
    \\Commands:
    \\  init                   Create new context
    \\  show                   Show context
    \\  add [<pathspec>...]    Add files
    \\  rm [<pathspec>...]     Remove files
    \\  merge-base [<commit>]  Set merge base
    \\  help                   Show this help message
    \\
;

/// Exit status codes
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

    const allocator = arena.allocator();
    const args = try std.process.argsAlloc(allocator);

    if (args.len < 2) {
        std.debug.print("{s}", .{usage});
        std.process.exit(status.usage);
    }

    const command = args[1];
    if (std.mem.eql(u8, command, "init")) {
        try storage.write(&context.Context.init(allocator));
    } else if (std.mem.eql(u8, command, "show")) {
        var ctx = context.FileSystemContext.init(allocator);
        try storage.read(&ctx.context, allocator);
        const stdout = std.io.getStdOut();
        try ctx.show(stdout.writer(), allocator);
    } else if (std.mem.eql(u8, command, "add")) {
        var ctx = context.Context.init(allocator);
        try storage.read(&ctx, allocator);
        try ctx.add(args[2..]);
        try storage.write(&ctx);
    } else if (std.mem.eql(u8, command, "rm")) {
        var ctx = context.Context.init(allocator);
        try storage.read(&ctx, allocator);
        ctx.rm(args[2..]);
        try storage.write(&ctx);
    } else if (std.mem.eql(u8, command, "merge-base")) {
        var ctx = context.Context.init(allocator);
        try storage.read(&ctx, allocator);
        ctx.merge_base = if (args.len > 2) args[2] else "";
        try storage.write(&ctx);
    } else if (std.mem.eql(u8, command, "help")) {
        std.debug.print("{s}", .{usage});
    } else {
        std.debug.print("Unknown command: {s}\n{s}", .{ command, usage });
        std.process.exit(status.usage);
    }
}

