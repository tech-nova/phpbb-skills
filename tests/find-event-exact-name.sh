#!/usr/bin/env bash
# Verify literal event-name matching without requiring a phpBB installation.
set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
script="$here/../phpbb/scripts/find-event.sh"
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/docs"
: > "$fixture/docs/events.md"

# A regex wildcard would select this earlier, unrelated docblock.
cat > "$fixture/events.php" <<'PHP'
/**
 * Wrong contract
 * @event coreXexample
 */
trigger_event('coreXexample');
/**
 * Correct contract
 * @event core.example
 */
trigger_event('core.example');
/**
 * Longer event name
 * @event core.example_extra
 */
trigger_event('core.example_extra');
PHP

output=$(bash "$script" '^core.example$' "$fixture")
[[ "$output" == *'File: events.php:8'* ]]
[[ "$output" == *'Correct contract'* ]]
[[ "$output" == *"trigger_event('core.example');"* ]]
[[ "$output" != *'Wrong contract'* ]]
[[ "$output" != *'Longer event name'* ]]

# User-supplied fragments still select the whole matching event family.
output=$(bash "$script" example "$fixture")
[[ "$output" == *'### core.example'* ]]
[[ "$output" == *'### core.example_extra'* ]]
[[ "$output" == *'File: events.php:13'* ]]

# File lookup must also ignore a wildcard-like annotation in another file.
printf '/**\n * @event coreXfile_event\n */\ntrigger_event();\n' > "$fixture/decoy.php"
printf '/**\n * @event core.file_event\n */\ntrigger_event();\n' > "$fixture/correct.php"
output=$(bash "$script" file_event "$fixture")
[[ "$output" == *'File: correct.php:2'* ]]
[[ "$output" != *'coreXfile_event'* ]]

printf 'find-event exact-name regression checks passed\n'
