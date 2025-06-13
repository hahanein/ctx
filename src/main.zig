const std = @import("std");
const build_options = @import("build_options");

const Context = @import("Context.zig");
const Ignore = @import("Ignore.zig");
const renderer = @import("renderer.zig");
const status = @import("status.zig");

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
    \\  status                 Show context status
    \\  version                Show version information
    \\  help                   Show this help message
    \\
;

const exit = struct {
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
        std.process.exit(exit.usage);
    }

    const cmd = args[1];
    const cmd_args = args[2..];
    if (std.mem.eql(u8, cmd, "init")) {
        try Context.init(allocator).writeFile(".ctx");
    } else if (std.mem.eql(u8, cmd, "show")) {
        var ignore = try Ignore.parseFromFile(".ctxignore", allocator);
        var ctx = try Context.parseFromFile(".ctx", allocator);
        const stdout = std.io.getStdOut();
        try renderer.write(stdout.writer(), &ctx, &ignore, allocator);
    } else if (std.mem.eql(u8, cmd, "add")) {
        var ctx = try Context.parseFromFile(".ctx", allocator);
        try ctx.add(cmd_args);
        try ctx.writeFile(".ctx");
    } else if (std.mem.eql(u8, cmd, "rm")) {
        var ctx = try Context.parseFromFile(".ctx", allocator);
        ctx.rm(cmd_args);
        try ctx.writeFile(".ctx");
    } else if (std.mem.eql(u8, cmd, "merge-base")) {
        var ctx = try Context.parseFromFile(".ctx", allocator);
        ctx.merge_base.clearRetainingCapacity();
        if (args.len > 2) try ctx.merge_base.appendSlice(args[2]);
        try ctx.writeFile(".ctx");
    } else if (std.mem.eql(u8, cmd, "status")) {
        var ignore = try Ignore.parseFromFile(".ctxignore", allocator);
        var ctx = try Context.parseFromFile(".ctx", allocator);
        const stdout = std.io.getStdOut();
        try status.write(stdout.writer(), &ctx, &ignore, allocator);
    } else if (std.mem.eql(u8, cmd, "version")) {
        std.debug.print("ctx version v{s}\n", .{build_options.version});
    } else if (std.mem.eql(u8, cmd, "help")) {
        std.debug.print("{s}", .{usage});
    } else {
        std.debug.print("Unknown command: {s}\n{s}", .{ cmd, usage });
        std.process.exit(exit.usage);
    }

    std.process.exit(exit.success);
}

