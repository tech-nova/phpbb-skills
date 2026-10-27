#!/usr/bin/env bash
# Verify source paths are relative to the literal root directory.
set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
script="$here/../phpbb/scripts/find-event.sh"
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT

for directory in 'board[3.3]' 'board*' 'board?' 'board space'; do
	root="$fixture/$directory"
	mkdir -p "$root/docs" "$root/includes"
	: > "$root/docs/events.md"
	printf '/**\n * @event core.example\n */\ntrigger_event();\n' > "$root/includes/events.php"
	output=$(bash "$script" example "$root")
	if [[ "$output" != *'File: includes/events.php:2'* ]]; then
		printf 'Incorrect relative source path for root: %s\n%s\n' "$directory" "$output" >&2
		exit 1
	fi
	[[ "$output" == *'### core.example'* ]]
	[[ "$output" == *'trigger_event();'* ]]
done

printf 'find-event relative-path regression checks passed\n'
