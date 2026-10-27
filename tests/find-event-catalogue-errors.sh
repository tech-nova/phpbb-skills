#!/usr/bin/env bash
# Distinguish failed template-catalogue searches from valid empty results.
set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
script="$here/../phpbb/scripts/find-event.sh"
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/docs"

# A missing catalogue must fail and retain the reader's diagnostic.
if output=$(bash "$script" example "$fixture" 2> "$fixture/error"); then
	echo 'Missing catalogue unexpectedly succeeded' >&2
	exit 1
fi
[[ -s "$fixture/error" ]]
[[ "$output" != *'(no matches)'* ]]
[[ "$output" != *'## PHP events'* ]]

cat > "$fixture/docs/events.md" <<'CATALOGUE'
example_template_event
===
Purpose: Example template contract.

CATALOGUE

# A valid match still prints the catalogue entry.
output=$(bash "$script" example "$fixture" 2> "$fixture/error")
[[ ! -s "$fixture/error" ]]
[[ "$output" == *'example_template_event'* ]]
[[ "$output" == *'Purpose: Example template contract.'* ]]
[[ "$output" == *'## PHP events'* ]]

# An invalid catalogue regex must fail rather than masquerade as no matches.
if output=$(bash "$script" '[' "$fixture" 2> "$fixture/error"); then
	echo 'Invalid catalogue regex unexpectedly succeeded' >&2
	exit 1
fi
[[ -s "$fixture/error" ]]
[[ "$output" != *'(no matches)'* ]]
[[ "$output" != *'## PHP events'* ]]

# No match and an empty catalogue are both successful searches.
output=$(bash "$script" missing_event "$fixture" 2> "$fixture/error")
[[ ! -s "$fixture/error" ]]
[[ "$output" == *'(no matches)'* ]]
[[ "$output" == *'## PHP events'* ]]
: > "$fixture/docs/events.md"
output=$(bash "$script" example "$fixture" 2> "$fixture/error")
[[ ! -s "$fixture/error" ]]
[[ "$output" == *'(no matches)'* ]]
[[ "$output" == *'## PHP events'* ]]

printf 'find-event catalogue error regression checks passed\n'
