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
    /// Replace underscore with dash in enum field names to get command names.
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

/// Execute command with arguments.
fn execute(command: Command, arguments: []const []const u8, allocator: std.mem.Allocator) !void {
    const stdout = std.io.getStdOut();
    defer stdout.close();
    const writer = stdout.writer();
    switch (command) {
        .init => {
            var ctx = Context.init(allocator);
            defer ctx.deinit();

            try ctx.save();
        },
        .show => {
            var ignore = try Ignore.load(allocator);
            defer ignore.deinit();

            var ctx = try Context.load(allocator);
            defer ctx.deinit();

            try renderer.write(writer, &ctx, &ignore, allocator);
        },
        .add => {
            var ctx = try Context.load(allocator);
            defer ctx.deinit();

            try ctx.add(arguments);
            try ctx.save();
        },
        .rm => {
            var ctx = try Context.load(allocator);
            defer ctx.deinit();

            ctx.rm(arguments);
            try ctx.save();
        },
        .merge_base => {
            var ctx = try Context.load(allocator);
            defer ctx.deinit();

            ctx.merge_base.clearRetainingCapacity();
            if (arguments.len > 0) try ctx.merge_base.appendSlice(arguments[0]);
            try ctx.save();
        },
        .status => {
            var ignore = try Ignore.load(allocator);
            defer ignore.deinit();

            var ctx = try Context.load(allocator);
            defer ctx.deinit();

            try status.write(writer, &ctx, &ignore, allocator);
        },
        .version => {
            try writer.print("ctx version v{s}\n", .{build_options.version});
        },
        .help => {
            _ = try writer.write(usage);
        },
    }
}

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

    const arguments = try std.process.argsAlloc(allocator);
    if (arguments.len < 2) {
        std.debug.print(usage, .{});
        std.process.exit(StatusCodes.usage);
    }

    const command_bytes = arguments[1];
    const command_arguments = arguments[2..];
    const command = Command.parse(command_bytes) catch {
        std.debug.print("Unknown command: {s}\n{s}", .{ command_bytes, usage });
        std.process.exit(StatusCodes.usage);
    };

    execute(command, command_arguments, allocator) catch |err| switch (err) {
        error.WorkspaceFileNotFound => {
            std.debug.print("Fatal: not a ctx workspace\n", .{});
            std.process.exit(StatusCodes.failure);
        },
        else => return err,
    };

    std.process.exit(StatusCodes.success);
}

