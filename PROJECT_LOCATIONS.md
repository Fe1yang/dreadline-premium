# Where the buy-once build lives

Hand this file to any agent working on the game: it is the only source of truth for paths and
repos.

## Project folders

| What | Path |
|---|---|
| **Buy-once build (what the user plays)** | `C:\Users\user\Documents\kimi\tasks\2026-11-10\dreadline-premium` |
| IAP build, packaging clone (git → Dead_Frontier) | `C:\Users\user\Documents\kimi\tasks\2026-11-06\12-50-12-52283f1e\df-backup` |
| IAP build, original working copy | `C:\Users\user\Documents\kimi\tasks\2026-11-02\20-32-30-26dbcd78` |

The buy-once build is a **separate copy**, not a branch: no store, no IAP, coins + silver economy,
rewarded ads kept, every player starts at zero.

## GitHub

| Repo | URL | Remote name |
|---|---|---|
| Buy-once (public) | https://github.com/Fe1yang/dreadline-premium | `origin` |
| IAP | https://github.com/Fe1yang/Dead_Frontier | `origin` |

Both use `main`. Commits are made with:

```
git -c user.name="Nightfall Studio" -c user.email="dev@nightfall.local" commit -m "..."
```

## Tools

| Tool | Path |
|---|---|
| Godot 4.7.2 console | `C:\Users\user\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe` |
| Blender 5.2 | `C:\Program Files\Blender Foundation\Blender 5.2\blender.exe` |
| Python | `C:\Users\user\.dsh\dsh-runtimes\dsh-primary-runtime\dependencies\python\python.exe` |

## Build rules

- Builds are **only** made when the user asks (`构建` / `推送新版N`), and every build must upload to
  TestFlight automatically (GitHub Actions on the macOS runner, tag `build-*`).
- Bump `application/version` in `export_presets.cfg` before every tag: a duplicate
  CFBundleVersion makes the upload fail.
- Check build status from `https://api.github.com/repos/Fe1yang/Dead_Frontier/actions/runs` and its
  `/jobs`, never from memory.

## Running the game locally

```
& $godot --headless --audio-driver Dummy --path <project> --quit-after 3   # parse check only
& $godot --audio-driver Dummy --path <project> --script res://tools/<probe>.gd   # screenshots
```

`PERF_TRACE=1` turns on the frame watchdog: any frame over 50 ms prints
`HITCH <ms> state=… z=… p=… fx=… c=… b=…` plus `SPAWN`/`CRATE`/`WAVE` timings.
