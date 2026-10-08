---
name: roblox-rojo-project-setup
description: Set up a new or existing Roblox project for Rojo on Windows - install Rokit, trust and add Rojo (plus optional StyLua/Lune/Wally), install the Rojo Studio plugin, scaffold with rojo init, give the project its own port and place lock, start rojo serve so it outlives the Claude session, and walk the user through connecting Studio. Use when the user asks to "set up Rojo", "start a new Roblox project", "connect Studio to VS Code", or when rojo serve / the Rojo plugin won't connect, syncs the wrong project, or `rojo` is not recognized.
---

# Roblox Rojo project setup

Gets a Roblox project syncing from disk into Studio with Rojo, and avoids the problems hit in earlier setups: Rokit's trust prompt, VS Code not seeing the new PATH, two projects fighting over port 34872, and a server that dies with the Claude session.

The user works on **Windows** with VS Code + the Claude Code extension, PowerShell as the shell, and projects under `C:\Users\<user>\Desktop\Roblox Games\<Project>`. Adjust paths if that differs.

## Ground rules

- **Run commands yourself** unless the user asks to approve each one. Stop and ask only on an error you can't fix or a step that needs them.
- **Things only the user can do:** click **Connect** in the Rojo plugin, restart Studio, turn on Studio settings, publish places. Say clearly when you're waiting on one of these.
- **Sync is one-way (disk → Studio).** Code edited inside Studio is overwritten. Tell the user once.
- Rojo does **not** save the place. The user still saves/publishes from Studio.

## 1. Preflight

Check what's already there before installing anything:

```powershell
Test-Path "$env:USERPROFILE\.rokit\bin\rokit.exe"
Get-ChildItem -Name *.project.json, rokit.toml, aftman.toml, foreman.toml -ErrorAction SilentlyContinue
Test-Path "$env:LOCALAPPDATA\Roblox\Plugins\RojoManagedPlugin.rbxm"
Get-NetTCPConnection -State Listen -LocalPort 34870..34899 -ErrorAction SilentlyContinue | Select-Object LocalPort, OwningProcess
```

- If `aftman.toml` or `foreman.toml` exists, the project uses another toolchain manager. Ask before switching it to Rokit.
- Note which Rojo ports are taken. Other projects' servers will matter in step 6.

## 2. Install Rokit (skip if present)

Rokit has no package-manager install on Windows. Download the release and self-install:

```powershell
$release = Invoke-RestMethod https://api.github.com/repos/rojo-rbx/rokit/releases/latest
$asset = $release.assets | Where-Object { $_.name -like "*windows-x86_64*" } | Select-Object -First 1
$zip = Join-Path $env:TEMP "rokit.zip"
Invoke-WebRequest $asset.browser_download_url -OutFile $zip
Expand-Archive $zip -DestinationPath (Join-Path $env:TEMP "rokit") -Force
& (Join-Path $env:TEMP "rokit\rokit.exe") self-install
```

It prints nothing on success. Verify that `~\.rokit\bin\rokit.exe` exists.

**PATH:** `self-install` adds `~\.rokit\bin` to the user PATH, but the current shell and **every VS Code terminal** keep the old PATH until VS Code is fully restarted. For the rest of this session, prepend it yourself:

```powershell
$env:Path = "$env:USERPROFILE\.rokit\bin;$env:Path"
```

## 3. Add Rojo (and optional tools)

From the project folder:

```powershell
rokit init                      # creates rokit.toml (skip if it exists)
rokit trust rojo-rbx/rojo       # REQUIRED first - see below
rokit add rojo-rbx/rojo
rojo --version
```

**Trust step:** `rokit add` on an untrusted tool fails with `ERROR The following tool has not been marked as trusted` because the trust prompt can't be answered in a non-interactive shell. Its hint just repeats the failing command. Run `rokit trust <tool>` first, then `add`.

Optional tools, each needing `trust` then `add`:

| Tool | Rokit id | Use |
|---|---|---|
| StyLua | `JohnnyMorganz/StyLua` | formatter (`stylua src`) |
| Lune | `lune-org/lune` | run pure Luau tests outside Studio |
| Wally | `UpliftGames/wally` | packages such as ProfileStore |
| Selene | `Kampfkarren/selene` | linter |

Add these only if the user wants them or the project plan calls for them.

## 4. Install the Studio plugin

```powershell
rojo plugin install
Test-Path "$env:LOCALAPPDATA\Roblox\Plugins\RojoManagedPlugin.rbxm"
```

Studio loads plugins at startup. If Studio is already open, tell the user to **restart it**.

## 5. Scaffold the project

For a new project:

```powershell
rojo init        # Place project: default.project.json, src/{client,server,shared}, .gitignore, README.md
```

- `rojo init` also runs `git init`. Mention this to the user.
- It leaves existing files such as a plan doc alone, but check `git status` afterwards.
- Default mapping: `src/shared` → `ReplicatedStorage.Shared`, `src/server` → `ServerScriptService.Server`, `src/client` → `StarterPlayer.StarterPlayerScripts.Client`. `init.server.luau` / `init.client.luau` become the parent script.
- `sourcemap.json` is already gitignored. Keep it that way.

For an existing Studio place with no files yet, scaffold the same way, then tell the user that the first Connect will **replace** the scripts in the mapped containers with what's on disk. They should export or copy anything they need first.

## 6. Give the project its own port and lock it to its place

Every Rojo project defaults to **port 34872**. With two projects open, Studio can connect to the wrong server and the first sync overwrites that place's scripts with the other project's. The files on disk are fine, but the Studio copy is clobbered. Prevent it in the project file:

```json
{
  "name": "Vending Empire (School)",
  "servePort": 34873,
  "servePlaceIds": [1234567890],
  "tree": { "...": "..." }
}
```

- **`name`** is the label the Rojo plugin and `/api/rojo` report. Make it specific.
- **`servePort`:** pick an unused port from preflight. Use one port per project, or per place if a repo has several `*.project.json` files (e.g. `default` 34872, `mall` 34873, `tokyo` 34874).
- **`servePlaceIds`:** Rojo then refuses to sync into any other place. The place ID only exists once the place is published. Until then, leave this out and tell the user to send you the ID after publishing.

Record the port in the project's CLAUDE.md so future sessions use it.

## 7. Start the server so it survives the session

A `rojo serve` started as a Claude background task dies when the session ends or hits its time limit. Start it in its own minimized window instead:

```powershell
Start-Process -FilePath "cmd.exe" `
  -ArgumentList '/k', 'title Rojo - <Project> <port> && rojo serve default.project.json --port <port>' `
  -WorkingDirectory "<project folder>" -WindowStyle Minimized
```

Then verify **which project** is answering, not just that the port is open. Rojo 7.7 returns MessagePack, so strip the binary:

```bash
curl -s -m 3 http://127.0.0.1:<port>/api/rojo | tr -c '[:print:]' ' ' | grep -o "projectName [A-Za-z0-9 ()+-]*"
```

If the port belongs to another project's server, find and stop that server and tell the user:

```powershell
Get-NetTCPConnection -State Listen -LocalPort <port> | Select-Object OwningProcess
Get-CimInstance Win32_Process -Filter "Name='rojo.exe'" | Select-Object ProcessId, CommandLine
Stop-Process -Id <pid>
```

Leave `rojo sourcemap ... --watch` processes alone. They don't hold ports.

**Sourcemap (for luau-lsp autocomplete):** if the user has the Luau Language Server extension, run a watcher in another window:

```powershell
rojo sourcemap default.project.json --output sourcemap.json --include-non-scripts --watch
```

## 8. Connect Studio (user steps)

Give the user this, filled in with the real port:

1. Open the place in Studio. A new Baseplate is fine for a fresh project. Restart Studio if the plugin was just installed.
2. **Plugins** tab → **Rojo** → check that the address is `localhost` and the port is **<port>** → **Connect**.
3. Accept the change list. Your `src` folders appear under ReplicatedStorage / ServerScriptService / StarterPlayerScripts.
4. Keep the "Rojo - <Project>" window open while working. Closing it stops sync, but nothing is lost. Run the same command again and reconnect.

If the project will use DataStores/ProfileStore, also tell them to enable **Game Settings → Security → Enable Studio Access to API Services**. This only works after the place is published.

## 9. Finish

- Write or update the project's **CLAUDE.md** with the tooling (Rokit-pinned tools, the project's port, the serve command, "edit on disk, never in Studio") and the folder → instance mapping.
- Commit `rokit.toml`, the project file(s), `src/`, `.gitignore` and CLAUDE.md.
- Report: what's installed (with versions), the port, what's running and in which window, and what the user still has to do (restart VS Code, click Connect, publish and send the place ID).

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `rojo : The term 'rojo' is not recognized` in VS Code | VS Code kept the PATH from before Rokit was installed | Fully quit VS Code (all windows) and reopen. Right now: `$env:Path = "$env:USERPROFILE\.rokit\bin;$env:Path"` |
| `tool has not been marked as trusted` | Rokit trust prompt can't run non-interactively | `rokit trust <owner/tool>`, then `rokit add` again |
| No Rojo button in Studio | Plugin installed while Studio was open | Restart Studio. Check `RojoManagedPlugin.rbxm` exists |
| Connect fails | Server not running, wrong port, or Windows Firewall | Check with the `/api/rojo` curl. Restart the serve window. Allow `rojo.exe` through the firewall |
| Studio shows another project's scripts | Another project's server was on the same port | Stop that server, start the right one, verify `projectName`, Connect and accept. Then add `servePort` / `servePlaceIds` (step 6) |
| Server gone after a while | It was a Claude background task | Restart with `Start-Process` (step 7) |
| New remotes/instances in the project file don't appear | Project-file changes need a server restart | Restart `rojo serve`, then reconnect |
| Need code in Studio but the user can't click Connect now | The plugin's Connect needs a human | Ask them to click Connect. Don't hand-copy sources into Studio unless the user asks. |
