#!/usr/bin/env bash
# Look up phpBB events by name fragment, in both catalogues.
#   template events -> docs/events.md
#   PHP events      -> @event docblocks above trigger_event() call sites
# Usage: find-event.sh <pattern> [phpbb_root]
set -uo pipefail

if [ $# -lt 1 ]; then
	echo "usage: find-event.sh <pattern> [phpbb_root]" >&2
	exit 2
fi

pattern=$1
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
if [ $# -ge 2 ]; then
	root=$2
else
	root=$("$here/phpbb-root.sh" | sed -n 's/^root=//p')
fi
[ -n "$root" ] || exit 1

echo "## Template events   (source: docs/events.md)"
echo
found=$(awk -v pat="$pattern" '
	/^===$/ { if (prev ~ pat) { print prev; print "==="; show=1 } else show=0; next }
	show && /^$/ { show=0; print ""; next }
	show { print }
	{ prev = $0 }
' "$root/docs/events.md")
if [ -n "$found" ]; then printf '%s\n' "$found"; else echo "(no matches)"; echo; fi

echo "## PHP events   (source: @event docblocks in the tree)"
echo
names=$(grep -rho "@event core\.[a-z_0-9]*" --include=*.php "$root" 2>/dev/null \
	| grep -v "/vendor/" | sed 's/@event //' | sort -u | grep -- "$pattern")
if [ -z "$names" ]; then
	echo "(no matches)"
	exit 0
fi
for name in $names; do
	file=$(grep -rl "@event $name\$" --include=*.php "$root" 2>/dev/null | grep -v "/vendor/" | head -1)
	[ -n "$file" ] || continue
	line=$(grep -n "@event $name\$" "$file" | head -1 | cut -d: -f1)
	echo "### $name"
	echo "File: ${file#$root/}:$line"
	# print the docblock (walk back to /**) and the call site that follows
	awk -v ln="$line" '
		NR <= ln && /\/\*\*/ { start = NR }
		NR >= ln && /trigger_event\(/ && !stop { stop = NR }
		{ lines[NR] = $0 }
		END { for (i = start; i <= stop; i++) print lines[i] }
	' "$file"
	echo
done
