# ctx

A small CLI for building prompt context files for large-language models.

## Build

```bash
zig build -Doptimize=ReleaseFast
```

## Typical workflow

```bash
ctx init                      # Create .ctx in the current repo
ctx add src/*.zig README.md   # Register files or directories
ctx show | wl-copy            # Copy Markdown context to clipboard
```

## Commands

| Command       | Description                |
| ------------- | -------------------------- |
| `init`        | create a new `.ctx` file   |
| `add <path>…` | add one or more paths      |
| `rm <path>…`  | remove paths               |
| `show`        | print the stored context   |
| `status`      | show differences (planned) |
| `help`        | display usage              |

Exit codes: `0` success, `1` failure, `2` usage error.

## License

MIT.
