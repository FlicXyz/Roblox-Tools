# Working in Studio through an MCP server

Tool names are those of Roblox's Studio MCP server (`list_roblox_studios`, `get_studio_state`, `search_game_tree`, `execute_luau`, `start_stop_play`, `get_console_output`, `screen_capture`, the input tools). With another server, use its equivalents.

**How far to trust this file.** Everything here was seen in real sessions. None of it was re-run when the file was written, because no Studio was open. Tools change: when a call behaves differently from what is written, trust what you see, tell the user, and correct this file.

Call `list_roblox_studios` at the start of every turn. The Studio id changes when Studio is reopened, and several Studios may be open.

## 1. Studio preflight

**Plugin version.** Search the tree under `PluginGuiService`. The Rojo plugin's panel is named `Rojo <version>`, for example `Rojo 7.7.0`. No such panel means no plugin, or Studio was not restarted after the install.

**Place facts.** Run in the Edit datamodel. Each line reports `unreadable` instead of failing, because property names change between Studio versions.

```luau
local out = {}
local function try(label: string, read: () -> any)
	local ok, value = pcall(read)
	table.insert(out, label .. " = " .. (if ok then tostring(value) else "unreadable"))
end

try("PlaceId", function() return game.PlaceId end)
try("GameId", function() return game.GameId end)
try("CreatorType", function() return game.CreatorType end)
try("CreatorId", function() return game.CreatorId end)
try("StreamingEnabled", function() return workspace.StreamingEnabled end)
try("Avatar", function() return game:GetService("StarterPlayer").GameSettingsAvatar end)
try("ChatVersion", function() return game:GetService("TextChatService").ChatVersion end)
try("CharacterAutoLoads", function() return game:GetService("Players").CharacterAutoLoads end)
try("MaxPlayers", function() return game:GetService("Players").MaxPlayers end)

return table.concat(out, "\n")
```

What to do with the answers:

- `PlaceId = 0`: the place is not published. `servePlaceIds` and data stores wait until it is.
- `CreatorId` is not the user: the place belongs to someone else or a group. Ask what you may sync.
- `StreamingEnabled = true`: client code must wait for instances and must not assume the whole map exists.
- `Avatar`: write for the rig type the place actually spawns.

Then look at what already sits in `ReplicatedStorage`, `ServerScriptService` and `StarterPlayerScripts`. Anything named `Shared`, `Server` or `Client` will be replaced by the first sync.

## 2. Confirm the sync landed

Run in the Edit datamodel:

```luau
local parents: { [string]: Instance } = {
	Shared = game:GetService("ReplicatedStorage"),
	Server = game:GetService("ServerScriptService"),
	Client = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"),
}

local out, missing = {}, {}
for name, parent in parents do
	local root = parent:FindFirstChild(name)
	if not root then
		table.insert(missing, name)
		continue
	end
	local list = root:GetDescendants()
	table.insert(list, root)
	for _, instance in list do
		if instance:IsA("LuaSourceContainer") then
			table.insert(out, #(instance :: any).Source .. " " .. instance:GetFullName())
		end
	end
end
table.sort(out)
return string.format(
	"%d scripts, missing containers: %s\n%s",
	#out,
	if #missing > 0 then table.concat(missing, ", ") else "none",
	table.concat(out, "\n")
)
```

On disk, from the project folder:

```bash
find src -name '*.luau' -exec wc -c {} +
```

Every script's number must equal its file's byte count, and the script count must equal the file count. `init.server.luau`, `init.client.luau` and `init.luau` are the script named after their folder.

- A missing container: Rojo has not connected. Ask for Connect.
- A count that differs: that script is stale. Make Rojo send it again by changing the file on disk and changing it back a few seconds later, then re-check.
- Every number slightly too small: the files have CRLF line endings. The template's `.gitattributes` keeps them LF; apply it and re-save.

## 3. Play test recipe

1. `get_studio_state`. If a play session is already running that you did not start, do not stop it. The user or another session may be using it.
2. `start_stop_play` to start, then `get_studio_state` again. A start sent right after a stop sometimes does not take.
3. `get_console_output`. Look for the server and client start lines, and for errors.
4. `execute_luau` on the Server or Client datamodel to read state and drive the game.
5. Stop play. Report what you saw, with the Output lines that prove it.

Limits that change how you test:

- **`execute_luau` has its own module cache.** `require` on a game module returns a fresh copy, not the running one. Read live state through attributes, instances and the game's own remotes, never through a module's local tables.
- **The sandbox:** no HTTP requests, no data stores, and it cannot parent a script into the game. It can create other instances, set attributes, and write `Source` on a script that exists.
- **Remotes:** sessions disagree on whether the tool may call them from the Client datamodel. Try once. If it is refused, drive the game with real input.
- **Input tools work only on the running game**, never on Studio's own windows. That is why Connect needs the human.
- **Mouse clicks do not press GuiButtons.** On the Client: set `GuiService.SelectedObject` to the button, send the Return key, then set it back to `nil`.
- **Chat cannot be typed.** On the Client, inside `task.spawn`: `TextChatService.TextChannels.RBXGeneral:SendAsync("/command")`.
- **ProximityPrompts appear only when their part is on screen.** Walk the character so the part is in front of the camera first.
- **Screen captures:** send one at a time, and expect about two seconds of delay. An effect shorter than that cannot be photographed; sample properties each frame and log them.
- **Only solo play can be started.** A test that needs two players is the user's to run. Say so; do not report it as done.
- **Test commands that change saved data change the user's real save.** Say what you changed.

## 4. Writing scripts into Studio by hand

Default: do not. Ask for Connect and work on the steps that need no Studio.

Do it only when the user asks, or a play test cannot wait for them. Then:

1. **Before every single hand write**, check whether Rojo has connected: run the section 2 snippet. If any script you did not write is there, Rojo is connected. Stop writing by hand at once.
2. Write only the scripts still missing. Write the file's exact bytes: no stripped comments, no reformatting.
3. **After Rojo connects**, run section 2 across every script and fix each mismatch the way that section says.

Why: a hand write made after Rojo connects replaces Rojo's fresh copy with yours. Nothing reports it. The copies then differ from disk until someone notices an edit that changed nothing.
