# ctx

A command line tool for building prompt context files for large-language models.

## Build

```bash
zig build -Doptimize=ReleaseFast
```

## Typical workflow

```bash
ctx init                      # Create .ctx in the current repo
ctx add src/*.zig README.md   # Register files or directories
ctx merge-base main           # Register merge base to base diff on
ctx show | wl-copy            # Copy Markdown context to clipboard
```

## Commands

| Command                 | Description              |
| ----------------------- | ------------------------ |
| `init`                  | Create a new `.ctx` file |
| `add [<pathspec>...]`   | Add one or more files    |
| `rm [<pathspec>...]`    | Remove files             |
| `merge-base [<commit>]` | Set a merge base         |
| `show`                  | Print the stored context |
| `help`                  | Display usage            |

Exit codes: `0` success, `1` failure, `2` usage error.

## License

MIT.
