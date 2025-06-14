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

const Command = enum {
    init,
    show,
    add,
    rm,
    merge_base,
    status,
    version,
    help,
    /// Replace dash with underscore in enum field names to get command names.
    fn format(comptime src: []const u8) [src.len]u8 {
        var buf: [src.len]u8 = undefined;
        for (src, 0..) |char, i| buf[i] = if (char == '_') '-' else char;
        return buf;
    }
    /// Parse command name from bytes.
    pub fn parse(bytes: []u8) !Command {
        inline for (std.meta.fields(Command)) |command| {
            const command_name = comptime format(command.name);
            if (std.mem.eql(u8, &command_name, bytes)) {
                return @enumFromInt(command.value);
            }
        }

        return error.UnknownCommand;
    }
};

const StatusCodes = struct {
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
        std.process.exit(StatusCodes.usage);
    }

    const command_bytes = args[1];
    const arguments = args[2..];
    const command = Command.parse(command_bytes) catch {
        std.debug.print("Unknown command: {s}\n{s}", .{ command_bytes, usage });
        std.process.exit(StatusCodes.usage);
    };

    switch (command) {
        .init => {
            var ctx = Context.init(allocator);
            defer ctx.deinit();

            try ctx.writeFile(".ctx");
        },
        .show => {
            var ignore = try Ignore.parseFile(".ctxignore", allocator);
            defer ignore.deinit();

            var ctx = try Context.parseFile(".ctx", allocator);
            defer ctx.deinit();

            const stdout = std.io.getStdOut();
            try renderer.write(stdout.writer(), &ctx, &ignore, allocator);
        },
        .add => {
            var ctx = try Context.parseFile(".ctx", allocator);
            defer ctx.deinit();

            try ctx.add(arguments);
            try ctx.writeFile(".ctx");
        },
        .rm => {
            var ctx = try Context.parseFile(".ctx", allocator);
            defer ctx.deinit();

            ctx.rm(arguments);
            try ctx.writeFile(".ctx");
        },
        .merge_base => {
            var ctx = try Context.parseFile(".ctx", allocator);
            defer ctx.deinit();

            ctx.merge_base.clearRetainingCapacity();
            if (args.len > 2) try ctx.merge_base.appendSlice(args[2]);
            try ctx.writeFile(".ctx");
        },
        .status => {
            var ignore = try Ignore.parseFile(".ctxignore", allocator);
            defer ignore.deinit();

            var ctx = try Context.parseFile(".ctx", allocator);
            defer ctx.deinit();

            const stdout = std.io.getStdOut();
            try status.write(stdout.writer(), &ctx, &ignore, allocator);
        },
        .version => {
            std.debug.print("ctx version v{s}\n", .{build_options.version});
        },
        .help => {
            std.debug.print("{s}", .{usage});
        },
    }

    std.process.exit(StatusCodes.success);
}

