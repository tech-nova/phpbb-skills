#!/usr/bin/env bash
# Verify vendor exclusion without requiring an installed phpBB board.
set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
script="$here/../phpbb/scripts/find-event.sh"
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT

# A parent directory named vendor must not hide the selected source tree.
root="$fixture/vendor/phpbb tree"
mkdir -p "$root/docs" "$root/vendor/package" "$root/includes/vendor/package"
: > "$root/docs/events.md"

write_event() {
	printf '/**\n * @event %s\n */\ntrigger_event();\n' "$2" > "$1"
}

write_event "$root/core.php" core.example
write_event "$root/vendor/package/event.php" core.vendor_only
write_event "$root/includes/vendor/package/event.php" core.nested_vendor_only

output=$(bash "$script" vendor_only "$root")
[[ "$output" == *$'## PHP events   (source: @event docblocks in the tree)\n\n(no matches)' ]]
[[ "$output" != *'### core.'* ]]

output=$(bash "$script" example "$root")
[[ "$output" == *'### core.example'* ]]
[[ "$output" == *'File: core.php:2'* ]]
[[ "$output" == *'trigger_event();'* ]]

# Duplicate annotations in dependencies must not affect core source lookup.
write_event "$root/vendor/package/duplicate.php" core.example
output=$(bash "$script" example "$root")
[[ "$output" == *'File: core.php:2'* ]]
[[ "$output" != *'File: vendor/'* ]]

output=$(bash "$script" missing_event "$root")
[[ "$output" == *$'## PHP events   (source: @event docblocks in the tree)\n\n(no matches)' ]]

printf 'find-event vendor regression checks passed\n'
