# claude-personality

A Claude Code `/personality` slash command that loads speech-only persona profiles. See README.md for usage.

## Architecture

- `personality.md` — the slash command. Runs the manager script via inline `!` bash at load time, relays output, and acts on `SESSION: ADOPT <path>` / `SESSION: DROP` trailer lines to sync the live session.
- `src/personality.sh` — all real work: flat-JSON config read/write, profile validation/creation, and CLAUDE.md memory-block insertion/removal. Pure bash + awk/sed, no jq/python dependency.
- `profiles/*.md` — one persona per file. Format: `# Title`, blank line, `> one-line description` (parsed by `list`), persona instructions, and a closing "speech only" guard line.
- `config/config.json` — user-scope `{enabled, profile}`; gitignored, auto-created by the script.
- `install.sh` — links the repo to `~/.claude/personality` and ONLY `personality.md` into `~/.claude/commands/personality.md`. Never link the whole repo under `commands/` — Claude Code registers every `.md` there as a slash command, turning each profile into a junk command.
- Project scope state lives in the *consuming* project: `./.claude/personality.json` (config) and `./CLAUDE.md` (memory block).

## Conventions

- Memory blocks are always wrapped in `<!-- personality-mode:start -->` / `<!-- personality-mode:end -->` markers — never write personality content to a CLAUDE.md outside those markers, and removal must delete the whole marked range.
- Precedence: project profile > user default; project `enabled: false` disables personality entirely for that project. The user-scope memory block text encodes these rules — keep them in sync if either changes.
- Script output is the user-facing result; the only machine-readable contract is the optional final `SESSION:` line. Don't add other structured output without updating `personality.md`.
- Shell style: bash, `set -euo pipefail`, tabs for indentation.

## Testing changes

Run the script directly from a scratch directory (it treats `$PWD` as the project root):

```bash
cd "$(mktemp -d)" && bash ~/Sites/tools/skills/personality/src/personality.sh status
```

Exercise `set`/`on`/`off` there and inspect `./CLAUDE.md` and `./.claude/personality.json`. For user-scope commands, note they edit the real `~/.claude/CLAUDE.md` — back it up first when testing.
