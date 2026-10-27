#!/usr/bin/env bash
# Verify PHP event annotations accept trailing spaces, tabs, and CRLF.
set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
script="$here/../phpbb/scripts/find-event.sh"
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/docs"
: > "$fixture/docs/events.md"

for suffix in '' '   ' $'\t' $' \t' $'\r'; do
	printf '/**%s\n * Example contract%s\n * @event core.example%s\n */%s\ntrigger_event();%s\n' \
		"$suffix" "$suffix" "$suffix" "$suffix" "$suffix" > "$fixture/event.php"
	if output=$(bash "$script" '^core.example$' "$fixture"); then
		[[ "$output" == *'### core.example'* ]]
		[[ "$output" == *'File: event.php:3'* ]]
		[[ "$output" == *'Example contract'* ]]
		[[ "$output" == *'trigger_event();'* ]]
	else
		echo 'Event lookup unexpectedly failed' >&2
		exit 1
	fi
done

# End-of-name matching must not select a longer annotation on an earlier line.
cat > "$fixture/event.php" <<'PHP'
/**
 * Longer contract
 * @event core.example_extra
 */
trigger_event();
/**
 * Exact contract
 * @event core.example
 */
trigger_event();
PHP
output=$(bash "$script" '^core.example$' "$fixture")
[[ "$output" == *'File: event.php:8'* ]]
[[ "$output" == *'Exact contract'* ]]
[[ "$output" != *'Longer contract'* ]]

printf 'find-event annotation whitespace regression checks passed\n'
