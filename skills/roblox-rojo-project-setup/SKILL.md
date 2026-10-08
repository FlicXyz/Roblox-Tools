---
name: roblox-rojo-project-setup
description: "Use when starting a Roblox project that syncs with Rojo, or adopting one, especially when an agent will build it test-first or drive Studio through an MCP server - setting up Rokit, Rojo, Lune, luau-lsp, Selene or StyLua; choosing what Rojo may sync in a place another person also builds in; unit tests that cannot load a module outside Studio; `rojo` not recognized; the Rojo plugin not connecting or syncing the wrong project; scripts in Studio not matching the files on disk."
---

# Roblox Rojo project setup

## Overview

Sets up a Roblox project so that most of its logic is tested without Studio and the rest is verified by a play test.

**Core principle:** decide at setup which code must run outside the engine, and enforce that by structure: how modules require each other, and which types shared config may hold. Without it, test-first work has nothing to stand on and every check becomes a manual play test.

Commands are for Windows with PowerShell, where they were run. Adjust paths and shells elsewhere.

## What only the human can do

- Click **Connect** in the Rojo plugin. No tool can press it.
- Restart Studio after the plugin is installed.
- Publish the place, and turn on API access for data stores.

Ask for Connect in your first message, with the port, then keep working. Steps 2 to 5 need no Studio. Never sit waiting for the click.

## Steps

Do them in order. Each has a result you can check.

### 1. Preflight

Find out what exists before installing or writing anything.

- **Machine:** which tools are installed, whether the project already has a toolchain file, which Rojo ports are in use. Commands: `references/install-and-serve.md`, section 1.
- **Studio**, when a Studio MCP server is attached: the Rojo plugin's version, who owns the place, and the place settings code depends on (streaming, avatar type, chat version). Snippet: `references/studio.md`, section 1.
- **Ask the user once:** does anyone else build in this place (map, models, UI)? Their containers must never be synced. Write the answer into the project's CLAUDE.md.

### 2. Toolchain, pinned to the plugin

Install Rokit, then add Rojo, luau-lsp, Lune, StyLua and Selene. Load `references/install-and-serve.md` section 2 before the first `rokit` command: the trust step and the PATH step both trip up a first install otherwise.

The Rojo CLI and the Studio plugin must be the same version.

- Plugin already installed (step 1 found a version): pin the CLI to it, `rokit add rojo-rbx/rojo@<plugin version>`.
- No plugin yet: add the latest CLI, then `rojo plugin install`, which installs the matching plugin.

### 3. Project file: scripts only

Copy the template (`assets/project/` beside this file) into the project folder:

```powershell
Copy-Item -Recurse -Force "<this skill's folder>\assets\project\*" .
```

Its `default.project.json` names three script containers and nothing else: `ReplicatedStorage.Shared`, `ServerScriptService.Server`, `StarterPlayerScripts.Client`. Rojo only manages what the tree names, and `$ignoreUnknownInstances` leaves every other child of those services alone. `Workspace`, `Lighting` and a teammate's folders are never touched.

Do **not** use the project file `rojo init` writes in a place that already has content. It also maps `Workspace`, `Lighting` and `SoundService` and sets their properties.

Set `name` to something specific. Add `servePort` and `servePlaceIds` in step 6. Run `git init` if the folder is not a repository yet.

### 4. The module rule

Every module is one of two kinds. Decide when the file is created.

| | Pure | Engine-bound |
|---|---|---|
| Uses | numbers, strings, tables | `game`, services, Instances, engine types |
| Requires others by | string path: `require("./Config/GameConfig")` | instance: `require(ReplicatedStorage.Shared.Formulas)` |
| Verified by | a spec in `tests/`, written first | a play test (step 8) |
| Lives in | `src/shared`, `src/server/Lib` | everywhere else |

- A pure module may only require pure modules.
- Shared config that pure modules read holds plain data only. Values that need `Vector3`, `Color3` or `Enum` go in a separate config module that only engine-bound code requires.
- Put as much logic as possible in pure modules: formulas, costs, rolls, save-data shaping, rate limits, geometry on plain numbers. Engine-bound code should mostly call them.

The template's `src/shared/Formulas.luau`, `src/shared/Config/GameConfig.luau` and `tests/Formulas.spec.luau` show the pattern. Replace them with the project's first real module, spec first.

String requires were only run from plain `.luau` files. Try one before relying on a pure module written as a folder with `init.luau`.

### 5. The check command

```powershell
lune run check
```

It builds the sourcemap, type checks `src` with luau-lsp against Roblox's type definitions, lints with Selene, checks formatting with StyLua, and runs the specs under Lune. The first run downloads the type definitions, so it needs the network.

Expect `All checks passed.` and a test count above zero. `lune run test <name>` runs only the specs whose file name contains `<name>`. Run the check before saying any work is done, and before every commit.

### 6. Serve and connect

Give the project its own port, lock it to its place, start the server in a window that outlives the session, and confirm which project is answering. Then hand the user the Connect steps. Commands: `references/install-and-serve.md`, sections 3 and 4.

### 7. Confirm the sync landed

After the user connects, compare each script's `Source` length in Studio with the file's byte count on disk. They must be equal. Snippet: `references/studio.md`, section 2.

Do this before every play test, not only the first. A stopped server leaves Studio half-synced with no warning.

### 8. Verify engine-bound code by a play test

Start play, run Luau on the server and the client, read the Output. The template's server and client scripts each print one line; seeing both is the first proof the loop works. Recipe and the tools' limits: `references/studio.md`, section 3. Load it before the first play test.

### 9. Record and commit

Write into the project's CLAUDE.md: the commands (`lune run check`, the serve command and port), the module rule, "edit on disk, never in Studio", and which containers belong to someone else. Commit `rokit.toml`, the project file, `src/`, `tests/`, `.lune/` and the config files.

Then report to the user: what is installed and at which versions, the port, what is running and in which window, and what they still have to do (restart VS Code, click Connect, publish and send the place ID).

## Done when

Check each line against what you saw, not what you expect.

- [ ] `lune run check` printed `All checks passed.` with a test count above zero.
- [ ] One spec was seen failing before its code was written.
- [ ] The server on the project's port reports this project's name.
- [ ] Script lengths in Studio equal the byte counts on disk.
- [ ] A play test showed the server and client start lines in the Output.
- [ ] CLAUDE.md holds the commands, the port and the module rule.

Name to the user any line you could not check. Do not report the setup as finished while one is open.

## Traps

| Trap | What happens | Fix |
|---|---|---|
| Engine type in config a pure module reads | The spec cannot load: `attempt to index nil with 'new'` | Move the value to a config module only engine-bound code requires |
| Waiting for Connect | Work stalls on a click | Ask at the start, then do steps 2 to 5 |
| Pushing scripts into Studio by hand while waiting | When Rojo connects midway, later hand writes replace its synced copies | `references/studio.md`, section 4, before any hand write |
| Tagged templates parked in storage | `CollectionService:GetTagged` also returns instances in `ServerStorage` and `ReplicatedStorage` | One helper that keeps only `instance:IsDescendantOf(workspace)` |
| Table with gaps in its number keys | It survives neither a data store nor a remote | Keep the set in memory, convert to a sorted list at the boundary, unit test the round trip |
| Project file edited while the server runs | The server keeps serving the old tree | Restart `rojo serve`, ask the user to reconnect |
| A synced instance changes class (ModuleScript to Folder) | Live sync leaves the stale instance | Delete it in Studio, then reconnect |
| Two projects on the default port | Studio connects to the wrong one and overwrites the place's scripts | Own `servePort` and `servePlaceIds` (step 6) |
| Zero specs matched | Would read as "0 failed" | The template's runner exits 1 instead; keep that |

## References

- `references/install-and-serve.md`: load before the first `rokit` command, before starting or checking a server, and whenever `rojo` is not recognized or the plugin will not connect.
- `references/studio.md`: load before any call to a Studio MCP tool, before the first play test, and before writing anything into Studio by hand.
