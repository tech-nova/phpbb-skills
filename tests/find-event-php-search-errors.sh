#!/usr/bin/env bash
# Verify PHP event discovery distinguishes grep failures from no matches.
set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
script="$here/../phpbb/scripts/find-event.sh"
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/docs"
: > "$fixture/docs/events.md"

# No PHP files, and PHP files with no matching events, are valid empty results.
output=$(bash "$script" example "$fixture" 2> "$fixture/error")
[[ ! -s "$fixture/error" ]]
[[ "$output" == *$'## PHP events   (source: @event docblocks in the tree)\n\n(no matches)' ]]
printf '<?php\n' > "$fixture/empty.php"
output=$(bash "$script" example "$fixture" 2> "$fixture/error")
[[ ! -s "$fixture/error" ]]
[[ "$output" == *$'## PHP events   (source: @event docblocks in the tree)\n\n(no matches)' ]]

printf '/**\n * @event core.example\n */\ntrigger_event();\n' > "$fixture/event.php"
output=$(bash "$script" example "$fixture" 2> "$fixture/error")
[[ ! -s "$fixture/error" ]]
[[ "$output" == *'### core.example'* ]]
[[ "$output" == *'File: event.php:2'* ]]
output=$(bash "$script" missing_event "$fixture" 2> "$fixture/error")
[[ ! -s "$fixture/error" ]]
[[ "$output" == *$'## PHP events   (source: @event docblocks in the tree)\n\n(no matches)' ]]

# An empty template catalogue leaves regex validation to the PHP name filter.
if output=$(bash "$script" '[' "$fixture" 2> "$fixture/error"); then
	echo 'Invalid PHP search regex unexpectedly succeeded' >&2
	exit 1
fi
[[ -s "$fixture/error" ]]
[[ "$output" != *$'## PHP events   (source: @event docblocks in the tree)\n\n(no matches)' ]]

# A scan error must fail even if another file supplies a matching event.
printf '<?php\n' > "$fixture/unreadable.php"
chmod 000 "$fixture/unreadable.php"
if [[ -r "$fixture/unreadable.php" ]]; then
	echo 'Unreadable-file regression requires a user without read bypass privileges' >&2
	exit 1
fi
if output=$(bash "$script" example "$fixture" 2> "$fixture/error"); then
	echo 'Unreadable PHP source unexpectedly succeeded' >&2
	exit 1
fi
[[ -s "$fixture/error" ]]
[[ "$output" != *'### core.example'* ]]
[[ "$output" != *$'## PHP events   (source: @event docblocks in the tree)\n\n(no matches)' ]]

printf 'find-event PHP search error regression checks passed\n'
