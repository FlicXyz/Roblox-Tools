# Install, serve and connect

Windows, PowerShell. Sections 1 and 3 and the `rokit` commands in section 2 were run as written. The Rokit download in section 2 was not re-run, because Rokit was already installed; if it fails, read the release page and fix this file.

## 1. Machine preflight

Run from the project folder.

```powershell
Test-Path "$env:USERPROFILE\.rokit\bin\rokit.exe"
Get-ChildItem -Name *.project.json, rokit.toml, aftman.toml, foreman.toml -ErrorAction SilentlyContinue
Test-Path "$env:LOCALAPPDATA\Roblox\Plugins\RojoManagedPlugin.rbxm"
Get-NetTCPConnection -State Listen -LocalPort (34870..34899) -ErrorAction SilentlyContinue | Select-Object LocalPort, OwningProcess
Get-CimInstance Win32_Process -Filter "Name='rojo.exe'" | Select-Object ProcessId, CommandLine
```

- `aftman.toml` or `foreman.toml` means the project uses another toolchain manager. Ask before switching it to Rokit.
- Note which ports are taken. Every Rojo server defaults to 34872.
- A `rojo sourcemap ... --watch` process holds no port. Leave it alone.
- The plugin file existing says a plugin is installed, not which version. The version comes from Studio (`studio.md`, section 1).

## 2. Rokit and the tools

Skip the install if `rokit.exe` exists.

```powershell
$release = Invoke-RestMethod https://api.github.com/repos/rojo-rbx/rokit/releases/latest
$asset = $release.assets | Where-Object { $_.name -like "*windows-x86_64*" } | Select-Object -First 1
$zip = Join-Path $env:TEMP "rokit.zip"
Invoke-WebRequest $asset.browser_download_url -OutFile $zip
Expand-Archive $zip -DestinationPath (Join-Path $env:TEMP "rokit") -Force
& (Join-Path $env:TEMP "rokit\rokit.exe") self-install
```

It prints nothing on success. Confirm `~\.rokit\bin\rokit.exe` exists.

**PATH.** `self-install` adds `~\.rokit\bin` to the user PATH, but this shell and every open VS Code terminal keep the old PATH until VS Code is fully restarted. For this session:

```powershell
$env:Path = "$env:USERPROFILE\.rokit\bin;$env:Path"
```

**Add the tools**, from the project folder:

```powershell
rokit init                              # creates rokit.toml; skip if it exists
rokit trust rojo-rbx/rojo               # trust first, for each tool
rokit add rojo-rbx/rojo@<version>       # the plugin's version; leave out @<version> for the latest
rokit trust JohnnyMorganz/luau-lsp;  rokit add JohnnyMorganz/luau-lsp
rokit trust lune-org/lune;           rokit add lune-org/lune
rokit trust JohnnyMorganz/StyLua;    rokit add JohnnyMorganz/StyLua
rokit trust Kampfkarren/selene;      rokit add Kampfkarren/selene
rojo --version
```

**Trust.** `rokit add` on a tool that is not trusted fails with `The following tool has not been marked as trusted`, because its prompt cannot be answered in a shell with no keyboard. The hint it prints repeats the failing command. Run `rokit trust <owner/tool>` first.

**Tools only resolve inside a project.** Outside a folder with a `rokit.toml` (or below one), `rojo` fails with `Failed to find tool 'rojo' in any project manifest file`. Run tools from the project folder.

Add Wally (`UpliftGames/wally`) only when the project uses packages.

**Plugin.** When step 1 found no plugin:

```powershell
rojo plugin install
```

Studio loads plugins at startup. Tell the user to restart Studio if it is open.

## 3. Port, place lock, server

### Own port and place lock

Add to the project file:

```json
{
  "name": "my-game",
  "servePort": 34873,
  "servePlaceIds": [1234567890],
  "tree": { "...": "..." }
}
```

- **`name`** is what the plugin and the server report. Make it specific.
- **`servePort`:** an unused port from the preflight. One port per project file. A repo with several places has several project files and several ports.
- **`servePlaceIds`:** Rojo then refuses to sync into any other place. A place has an ID only once it is published. Until then leave the field out, and ask the user for the ID after they publish.

Why: with two projects on 34872, Studio can connect to the wrong server, and the first sync replaces that place's scripts with the other project's. The files on disk are fine; the Studio copy is not.

### Start the server so it outlives the session

A server started as a background task of the agent dies with the session. Start it in its own minimized window:

```powershell
Start-Process -FilePath "cmd.exe" `
  -ArgumentList '/k', 'title Rojo - <project> <port> && rojo serve default.project.json' `
  -WorkingDirectory "<project folder>" -WindowStyle Minimized
```

`rojo serve` reads the port from `servePort`. Add `--port <port>` only when the project file has none.

### Confirm which project is answering

An open port proves nothing about whose server it is. Read the server's own answer. It is MessagePack, so strip the binary:

```bash
curl -s -m 3 http://127.0.0.1:<port>/api/rojo | tr -c '[:print:]' ' ' | tr -s ' '
```

The output contains `serverVersion <version>` and `projectName <name>`. Both must be the ones you expect. No output means no server on that port.

If another project's server holds the port, tell the user, then find and stop it:

```powershell
Get-NetTCPConnection -State Listen -LocalPort <port> | Select-Object OwningProcess
Get-CimInstance Win32_Process -Filter "Name='rojo.exe'" | Select-Object ProcessId, CommandLine
Stop-Process -Id <pid>
```

### Sourcemap for the editor

With the Luau Language Server extension, run a watcher in another window so autocomplete follows the files:

```powershell
rojo sourcemap default.project.json --output sourcemap.json --include-non-scripts --watch
```

## 4. Connect Studio: what to tell the user

Fill in the real port.

1. Open the place in Studio. Restart Studio first if the plugin was just installed.
2. **Plugins** tab, **Rojo**: check the address is `localhost` and the port is **<port>**, then **Connect**.
3. Accept the change list. `Shared`, `Server` and `Client` appear under ReplicatedStorage, ServerScriptService and StarterPlayerScripts.
4. Keep the "Rojo - <project>" window open while working. Closing it stops the sync and loses nothing; run the same command and reconnect.

Tell them once:

- Sync is one way, disk to Studio. Scripts edited in Studio are overwritten.
- The first Connect replaces whatever is already in the three mapped containers. Copy out anything they need first.
- Rojo does not save the place. They still save and publish from Studio.
- Data stores work in Studio only after the place is published and **Game Settings > Security > Enable Studio Access to API Services** is on.

## 5. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `rojo` is not recognized, in VS Code | VS Code kept the PATH from before Rokit was installed | Quit every VS Code window and reopen. For now: `$env:Path = "$env:USERPROFILE\.rokit\bin;$env:Path"` |
| `Failed to find tool 'rojo' in any project manifest file` | The shell is not inside a folder with `rokit.toml` | Run from the project folder |
| `tool has not been marked as trusted` | The trust prompt cannot run without a keyboard | `rokit trust <owner/tool>`, then `rokit add` again |
| No Rojo button in Studio | Plugin installed while Studio was open | Restart Studio. Check `RojoManagedPlugin.rbxm` exists |
| Connect fails | No server, wrong port, version mismatch, or the firewall | Run the `/api/rojo` check. Compare `serverVersion` with the plugin's version. Restart the server window. Allow `rojo.exe` through the firewall |
| Connect refused with a place ID message | `servePlaceIds` does not list this place | Check the user opened the right place, or correct the ID |
| Studio shows another project's scripts | Another project's server was on the port | Stop it, start the right one, confirm `projectName`, Connect and accept. Then set `servePort` and `servePlaceIds` |
| Server gone after a while | It was a background task of a session that ended | Start it with `Start-Process` (section 3) |
| New folders in the project file do not appear | A running server does not re-read the project file | Restart the server, ask the user to reconnect |
