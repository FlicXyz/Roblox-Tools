# Roblox-Tools

Claude Code skills for Roblox development.

## Skills

| Skill | What it does |
|---|---|
| [roblox-rojo-project-setup](skills/roblox-rojo-project-setup/SKILL.md) | Sets up a Rojo project so logic can be unit tested outside Studio: tools pinned with Rokit, a project file that syncs scripts only, a rule for which modules must stay engine-free, one check command (types, lint, format, tests), and a play-test recipe for the rest. Includes a project template, and the install, port and connect steps for Windows. |

## Install

Copy a skill folder into `~/.claude/skills/` (all projects) or `<project>/.claude/skills/` (one project):

```powershell
Copy-Item -Recurse skills\roblox-rojo-project-setup "$env:USERPROFILE\.claude\skills\"
```

Start a new Claude Code session afterwards so the skill loads.

## What has been tested

- The project template was copied into an empty folder and `lune run check` passed there. A failing spec, a filter matching no specs, and an engine type in shared config each failed the run as the skill says.
- The install and serve commands were run on Windows, except the Rokit download.
- The Studio snippets type-check against Roblox's type definitions but were not run in Studio. The skill has not yet been used end to end on a new project.
