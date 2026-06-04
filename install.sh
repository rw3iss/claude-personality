#!/usr/bin/env bash
#
# install.sh — link this repo into ~/.claude/commands/personality so the
# /personality slash command is available in Claude Code.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
TARGET="$HOME/.claude/commands/personality"

mkdir -p "$HOME/.claude/commands"

if [ -L "$TARGET" ]; then
	current="$(readlink -f "$TARGET")"
	if [ "$current" = "$REPO_DIR" ]; then
		echo "Already installed: $TARGET -> $REPO_DIR"
		exit 0
	fi
	echo "ERROR: $TARGET is a symlink to $current. Remove it first." >&2
	exit 1
elif [ -e "$TARGET" ]; then
	echo "ERROR: $TARGET already exists. Remove or back it up first." >&2
	exit 1
fi

ln -s "$REPO_DIR" "$TARGET"
chmod +x "$REPO_DIR/src/personality.sh"
echo "Installed: $TARGET -> $REPO_DIR"
echo "The /personality command is now available in Claude Code (restart sessions to pick it up)."
echo "Try: /personality list"
