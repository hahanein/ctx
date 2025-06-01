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

| Command                 | Description         |
| ----------------------- | ------------------- |
| `init`                  | Create new context  |
| `add [<pathspec>...]`   | Add files           |
| `rm [<pathspec>...]`    | Remove files        |
| `merge-base [<commit>]` | Set merge base      |
| `show`                  | Show context        |
| `status`                | Show context status |
| `help`                  | Show help message   |

Exit codes: `0` success, `1` failure, `2` usage error.

## Tab completion

To enable tab completion, either source [`ctx-prompt.bash`](./ctx-prompt.bash) or move it to `/etc/bash_completion.d`.

## License

MIT.
