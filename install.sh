#!/usr/bin/env bash
#
# install.sh — wire this repo into Claude Code:
#   ~/.claude/personality              -> repo (profiles, config, scripts)
#   ~/.claude/commands/personality.md  -> repo/personality.md (the /personality command)
#
# Only the command file goes under commands/ — Claude Code registers every .md
# in that tree as a slash command, so linking the whole repo there would turn
# each profile/README into a junk command.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
DATA_LINK="$HOME/.claude/personality"
CMD_LINK="$HOME/.claude/commands/personality.md"

link() { # <target> <linkpath>
	local target="$1" linkpath="$2"
	if [ -L "$linkpath" ]; then
		if [ "$(readlink -f "$linkpath")" = "$(readlink -f "$target")" ]; then
			echo "Already linked: $linkpath -> $target"
			return 0
		fi
		echo "ERROR: $linkpath is a symlink to $(readlink -f "$linkpath"). Remove it first." >&2
		exit 1
	elif [ -e "$linkpath" ]; then
		echo "ERROR: $linkpath already exists. Remove or back it up first." >&2
		exit 1
	fi
	ln -s "$target" "$linkpath"
	echo "Linked: $linkpath -> $target"
}

mkdir -p "$HOME/.claude/commands"
link "$REPO_DIR" "$DATA_LINK"
link "$REPO_DIR/personality.md" "$CMD_LINK"
chmod +x "$REPO_DIR/src/personality.sh"

echo
echo "The /personality command is now available in Claude Code (restart sessions to pick it up)."
echo "Try: /personality list"
