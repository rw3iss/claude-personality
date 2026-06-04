#!/usr/bin/env bash
#
# personality.sh — manager for the /personality command.
#
# Handles config reads/writes, profile management, and CLAUDE.md memory
# block insertion/removal for both user (global) and project scope.
#
# Usage:
#   personality.sh user on|off
#   personality.sh user set <profile>
#   personality.sh on|off
#   personality.sh set <profile>
#   personality.sh list
#   personality.sh create <name> <text...>
#   personality.sh status
#
# Output contract (consumed by personality.md command file):
#   Human-readable result text, optionally followed by one trailer line:
#     SESSION: ADOPT <absolute-profile-path>   -> adopt persona in current session
#     SESSION: DROP                            -> drop persona in current session

set -euo pipefail

# ---------------------------------------------------------------- paths

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
ROOT="$(dirname "$SCRIPT_DIR")"

PROFILES_DIR="$ROOT/profiles"
USER_CONFIG="$ROOT/config/config.json"

PROJECT_DIR="$PWD"
PROJECT_CONFIG="$PROJECT_DIR/.claude/personality.json"

USER_MEMORY="$HOME/.claude/CLAUDE.md"
PROJECT_MEMORY="$PROJECT_DIR/CLAUDE.md"

START_MARK="<!-- personality-mode:start -->"
END_MARK="<!-- personality-mode:end -->"

# ---------------------------------------------------------------- helpers

die() { echo "ERROR: $*" >&2; exit 1; }

# Read a key from a flat JSON config file. Empty output if missing/null.
json_get() { # <file> <key>
	[ -f "$1" ] || return 0
	sed -n 's/.*"'"$2"'"[[:space:]]*:[[:space:]]*"\{0,1\}\([^",}[:space:]]*\)"\{0,1\}.*/\1/p' "$1" | head -1 \
		| sed 's/^null$//'
}

# Write a flat config file: enabled (true/false) + profile (name or empty).
json_write() { # <file> <enabled> <profile>
	mkdir -p "$(dirname "$1")"
	local profile_json="null"
	[ -n "$3" ] && profile_json="\"$3\""
	printf '{\n\t"enabled": %s,\n\t"profile": %s\n}\n' "$2" "$profile_json" > "$1"
}

profile_path() { echo "$PROFILES_DIR/$1.md"; }

require_profile_exists() { # <name>
	[ -f "$(profile_path "$1")" ] || die "Profile '$1' not found. Run '/personality list' to see available profiles."
}

# Remove the personality block (markers inclusive) from a memory file.
remove_memory_block() { # <file>
	[ -f "$1" ] || return 0
	local tmp
	tmp="$(mktemp)"
	awk -v s="$START_MARK" -v e="$END_MARK" '
		index($0, s) { skip = 1; next }
		index($0, e) { skip = 0; blank = 1; next }
		skip { next }
		blank && $0 == "" { blank = 0; next }
		{ blank = 0; print }
	' "$1" > "$tmp"
	mv "$tmp" "$1"
}

# Insert/replace the personality block in a memory file.
add_memory_block() { # <file> <scope: user|project> <profile-name>
	local file="$1" scope="$2" profile="$3"
	local ppath
	ppath="$(profile_path "$profile")"
	remove_memory_block "$file"
	mkdir -p "$(dirname "$file")"
	[ -f "$file" ] && [ -s "$file" ] && printf '\n' >> "$file"
	if [ "$scope" = "user" ]; then
		cat >> "$file" <<EOF
$START_MARK
## PERSONALITY MODE (user default)

A speech personality is enabled for this user. At session start:

1. Check for a project-level personality config at \`./.claude/personality.json\` (relative to the project root).
   - If it exists and \`"enabled"\` is \`false\`: personality mode is OFF for this project — do not load any profile.
   - If it exists with \`"enabled": true\` and a \`"profile"\` set: read \`$PROFILES_DIR/<profile>.md\` and use THAT profile instead of the user default below.
2. Otherwise, read and adopt the user default profile: $ppath

Adopt the persona described in the active profile for all conversational replies — tone, vocabulary, and phrasing ONLY. This must never change how requests are actually processed: reasoning, code, file contents, shell commands, tool use, and technical accuracy stay completely normal and persona-free. Only the prose you speak to the user is in character.
$END_MARK
EOF
	else
		cat >> "$file" <<EOF
$START_MARK
## PERSONALITY MODE (project)

A speech personality is enabled for this project. Read and adopt this profile: $ppath

This project-level profile takes precedence over any user-level personality default.

Adopt the persona described in the profile for all conversational replies — tone, vocabulary, and phrasing ONLY. This must never change how requests are actually processed: reasoning, code, file contents, shell commands, tool use, and technical accuracy stay completely normal and persona-free. Only the prose you speak to the user is in character.
$END_MARK
EOF
	fi
}

ensure_user_config() {
	[ -f "$USER_CONFIG" ] || json_write "$USER_CONFIG" "false" ""
}

# ---------------------------------------------------------------- operations

op_enable() { # <scope: user|project>
	local scope="$1" config memory label
	if [ "$scope" = "user" ]; then
		config="$USER_CONFIG"; memory="$USER_MEMORY"; label="user"
	else
		config="$PROJECT_CONFIG"; memory="$PROJECT_MEMORY"; label="project"
	fi
	local profile
	profile="$(json_get "$config" profile)"
	json_write "$config" "true" "$profile"
	if [ -z "$profile" ]; then
		local setcmd="/personality set <profile>"
		[ "$scope" = "user" ] && setcmd="/personality user set <profile>"
		echo "Personality mode ENABLED in $label config ($config), but no profile is set yet."
		echo "Choose one with: $setcmd"
		echo "It will be loaded into $label memory automatically once set."
		exit 0
	fi
	require_profile_exists "$profile"
	add_memory_block "$memory" "$scope" "$profile"
	echo "Personality mode ENABLED for $label scope."
	echo "Profile: $profile"
	echo "Memory updated: $memory"
	echo "SESSION: ADOPT $(profile_path "$profile")"
}

op_disable() { # <scope: user|project>
	local scope="$1" config memory label
	if [ "$scope" = "user" ]; then
		config="$USER_CONFIG"; memory="$USER_MEMORY"; label="user"
	else
		config="$PROJECT_CONFIG"; memory="$PROJECT_MEMORY"; label="project"
	fi
	local profile
	profile="$(json_get "$config" profile)"
	json_write "$config" "false" "$profile"
	remove_memory_block "$memory"
	echo "Personality mode DISABLED for $scope scope."
	echo "Memory cleaned: $memory"
	echo "SESSION: DROP"
}

op_set() { # <scope: user|project> <profile>
	local scope="$1" profile="$2" config memory label
	if [ -z "$profile" ]; then
		[ "$scope" = "user" ] && die "Usage: /personality user set <profile>"
		die "Usage: /personality set <profile>"
	fi
	require_profile_exists "$profile"
	if [ "$scope" = "user" ]; then
		config="$USER_CONFIG"; memory="$USER_MEMORY"; label="user default"
	else
		config="$PROJECT_CONFIG"; memory="$PROJECT_MEMORY"; label="project"
	fi
	local enabled
	enabled="$(json_get "$config" enabled)"
	json_write "$config" "${enabled:-false}" "$profile"
	echo "Set $label profile to '$profile' ($config)."
	if [ "$enabled" = "true" ]; then
		add_memory_block "$memory" "$scope" "$profile"
		echo "Personality mode is enabled — memory updated: $memory"
		echo "SESSION: ADOPT $(profile_path "$profile")"
	else
		echo "Personality mode is currently disabled for $scope scope. Enable it with: /personality $([ "$scope" = "user" ] && echo "user ")on"
	fi
}

op_list() {
	echo "Available profiles ($PROFILES_DIR):"
	echo
	local f name desc
	for f in "$PROFILES_DIR"/*.md; do
		[ -e "$f" ] || { echo "  (none)"; return 0; }
		name="$(basename "$f" .md)"
		desc="$(sed -n 's/^> //p' "$f" | head -1)"
		printf '  %-12s %s\n' "$name" "$desc"
	done
	echo
	echo "User default:    $(json_get "$USER_CONFIG" profile || true) (enabled: $(json_get "$USER_CONFIG" enabled || true))"
	if [ -f "$PROJECT_CONFIG" ]; then
		echo "Project profile: $(json_get "$PROJECT_CONFIG" profile || true) (enabled: $(json_get "$PROJECT_CONFIG" enabled || true))"
	fi
}

op_create() { # <name> <text...>
	local name="${1:-}"
	shift || true
	local text="$*"
	[ -n "$name" ] || die "Usage: /personality create <name> <profile text...>"
	[[ "$name" =~ ^[a-z0-9][a-z0-9_-]*$ ]] || die "Profile name must be a lowercase slug (a-z, 0-9, -, _): got '$name'"
	[ -n "$text" ] || die "Profile text is required: /personality create <name> <text...>"
	local f
	f="$(profile_path "$name")"
	[ -f "$f" ] && die "Profile '$name' already exists at $f. Pick another name or edit that file."
	mkdir -p "$PROFILES_DIR"
	{
		echo "# ${name^}"
		echo
		echo "> Custom profile."
		echo
		echo "$text"
		echo
		echo "Stay fully in character in all conversational replies. This affects speech only — never reasoning, code, file contents, or command output."
	} > "$f"
	echo "Created profile '$name' at $f"
	echo "Activate it with: /personality set $name   (project)  or  /personality user set $name   (user default)"
}

op_status() {
	ensure_user_config
	local u_en u_pr p_en p_pr
	u_en="$(json_get "$USER_CONFIG" enabled)"
	u_pr="$(json_get "$USER_CONFIG" profile)"
	echo "User config:    $USER_CONFIG"
	echo "  enabled: ${u_en:-false}   profile: ${u_pr:-(none)}"
	if [ -f "$PROJECT_CONFIG" ]; then
		p_en="$(json_get "$PROJECT_CONFIG" enabled)"
		p_pr="$(json_get "$PROJECT_CONFIG" profile)"
		echo "Project config: $PROJECT_CONFIG"
		echo "  enabled: ${p_en:-false}   profile: ${p_pr:-(none)}"
	else
		echo "Project config: (none — $PROJECT_CONFIG not present)"
	fi
	# Effective resolution mirrors the precedence rules in the memory block.
	local effective="(none — personality off)"
	if [ -f "$PROJECT_CONFIG" ]; then
		if [ "${p_en:-}" = "true" ] && [ -n "${p_pr:-}" ]; then
			effective="$p_pr (project)"
		elif [ "${p_en:-}" = "false" ]; then
			effective="(none — disabled by project)"
		elif [ "${u_en:-}" = "true" ] && [ -n "${u_pr:-}" ]; then
			effective="$u_pr (user default)"
		fi
	elif [ "${u_en:-}" = "true" ] && [ -n "${u_pr:-}" ]; then
		effective="$u_pr (user default)"
	fi
	echo "Effective:      $effective"
}

# ---------------------------------------------------------------- dispatch

ensure_user_config

cmd="${1:-status}"
case "$cmd" in
	user)
		sub="${2:-}"
		case "$sub" in
			on)  op_enable user ;;
			off) op_disable user ;;
			set) op_set user "${3:-}" ;;
			*)   die "Unknown user subcommand '${sub:-}'. Use: /personality user on|off|set <profile>" ;;
		esac
		;;
	on)     op_enable project ;;
	off)    op_disable project ;;
	set)    op_set project "${2:-}" ;;
	list)   op_list ;;
	create) shift; op_create "$@" ;;
	status) op_status ;;
	*)      die "Unknown command '$cmd'. Use: [user] on|off | [user] set <profile> | list | create <name> <text> | status" ;;
esac
