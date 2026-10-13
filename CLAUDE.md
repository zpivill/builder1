# builder1

Roblox game managed with Rojo; all code lives in files. Tools are pinned in `rokit.toml` (Rojo, Selene, StyLua, Lune) — run `rokit install` on a new machine.

## Layout
- `src/shared` → ReplicatedStorage.Shared (ModuleScripts used by both sides)
- `src/server` → ServerScriptService.Server (`init.server.luau` entry)
- `src/client` → StarterPlayer.StarterPlayerScripts.Client (`init.client.luau` entry)
- `tests/` → not synced. `*.spec.luau` files run under Lune via `tests/run.luau`. Only test pure-logic modules (no Roblox APIs).
- `default.project.json` → Rojo mapping. `build/` is generated output.

## The one command
```
./check.ps1
```
Runs rojo build, selene lint, stylua format check, and Lune tests. Must pass before committing. Fix formatting with `stylua src tests`.
