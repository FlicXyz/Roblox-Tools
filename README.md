# Roblox-Tools

Claude Code skills for Roblox development.

## Skills

| Skill | What it does |
|---|---|
| [roblox-rojo-project-setup](skills/roblox-rojo-project-setup/SKILL.md) | Sets up Rokit + Rojo on Windows, scaffolds the project, gives it its own port and place lock, starts `rojo serve` so it outlives the session, and walks through connecting Studio. |

## Install

Copy a skill folder into `~/.claude/skills/` (all projects) or `<project>/.claude/skills/` (one project):

```powershell
Copy-Item -Recurse skills\roblox-rojo-project-setup "$env:USERPROFILE\.claude\skills\"
```

Start a new Claude Code session afterwards so the skill loads.
