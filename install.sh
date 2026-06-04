#!/usr/bin/env bash
#
# install.sh — wire claude-personality into Claude Code.
#
# Two modes:
#   Local  (run from a clone):    symlink the clone -> ~/.claude/personality
#   Remote (piped, no clone):     clone/update the repo into ~/.claude/personality
#
# One-line install (no clone needed):
#   curl -fsSL https://raw.githubusercontent.com/rw3iss/claude-personality/main/install.sh | bash
#
# Re-running the one-liner updates an existing install (git pull).
#
# Either way, only the command file is linked under ~/.claude/commands/ —
# Claude Code registers every .md in that tree as a slash command, so linking
# the whole repo there would turn each profile/README into a junk command.
#
# Env overrides:
#   PERSONALITY_REPO  clone URL   (default: https://github.com/rw3iss/claude-personality.git)
#   PERSONALITY_DIR   install dir (default: ~/.claude/personality)

set -euo pipefail

REPO_URL="${PERSONALITY_REPO:-https://github.com/rw3iss/claude-personality.git}"
DATA_DIR="${PERSONALITY_DIR:-$HOME/.claude/personality}"
CMD_LINK="$HOME/.claude/commands/personality.md"

# Local mode when the script lives inside a checkout; remote mode when piped
# (BASH_SOURCE is empty or not a real file under curl | bash).
SRC="${BASH_SOURCE[0]:-}"
LOCAL_DIR=""
if [ -n "$SRC" ] && [ -f "$SRC" ]; then
	dir="$(cd "$(dirname "$SRC")" && pwd -P)"
	[ -f "$dir/personality.md" ] && LOCAL_DIR="$dir"
fi

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

if [ -n "$LOCAL_DIR" ]; then
	# Dev install: link the checkout in place.
	link "$LOCAL_DIR" "$DATA_DIR"
else
	# Remote install: clone fresh, or update an existing clone (also follows a
	# dev-install symlink so the one-liner doubles as the update command).
	command -v git >/dev/null 2>&1 || { echo "ERROR: git is required." >&2; exit 1; }
	if [ -d "$DATA_DIR/.git" ] || { [ -L "$DATA_DIR" ] && [ -d "$(readlink -f "$DATA_DIR")/.git" ]; }; then
		echo "Updating existing install at $DATA_DIR..."
		git -C "$DATA_DIR" pull --ff-only
	elif [ -e "$DATA_DIR" ]; then
		echo "ERROR: $DATA_DIR exists but is not a git clone. Remove or back it up first." >&2
		exit 1
	else
		git clone "$REPO_URL" "$DATA_DIR"
	fi
fi

link "$DATA_DIR/personality.md" "$CMD_LINK"
chmod +x "$DATA_DIR/src/personality.sh"

echo
echo "The /personality command is now available in Claude Code (restart sessions to pick it up)."
echo "Try: /personality list"
