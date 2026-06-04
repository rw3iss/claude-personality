---
description: Manage speech personality profiles — make Claude talk like a pirate, a preacher, a rapper, etc. (speech only; never affects actual work)
argument-hint: "[user] on|off | [user] set <profile> | list | create <name> <text...> | status"
allowed-tools: Bash(bash:*), Read
---

# /personality

Manage personality mode. All state changes are performed by the manager script; your job is to relay its output and synchronize the **current session**.

## Result

!`bash "$HOME/.claude/personality/src/personality.sh" $ARGUMENTS`

## Instructions

1. Present the script result above to the user, cleaned up for readability. If it reported an error, explain it briefly and suggest the correct usage.
2. Then scan the result for a `SESSION:` trailer line and act on it **immediately, in this session**:
   - `SESSION: ADOPT <path>` — Read the profile file at `<path>` and adopt its persona starting with your very next sentence. The persona applies to conversational prose ONLY: tone, vocabulary, phrasing. It must never change how you process requests — reasoning, code, file edits, shell commands, tool use, and technical accuracy remain completely normal, and code blocks / file contents / command output stay persona-free.
   - `SESSION: DROP` — Immediately drop any active personality persona (whether loaded by this command or by memory at session start) and speak in your normal voice for the rest of the session.
   - No `SESSION:` line — informational command (`list`, `status`, `create`); just present the output. After a successful `create`, briefly show the new profile's text.
3. Confirm in one short line what changed (e.g. "Pirate persona active for this project — all sessions here will load it." or "Personality off — back to normal speech.").

## Notes

- `user`-prefixed subcommands affect the **user default** (all projects); unprefixed `on|off|set` affect the **current project** (`./.claude/personality.json` + `./CLAUDE.md`).
- A project profile always overrides the user default; a project with `"enabled": false` disables personality entirely for that project.
