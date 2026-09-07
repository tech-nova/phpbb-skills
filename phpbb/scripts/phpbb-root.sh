#!/usr/bin/env bash
# Locate a phpBB root and report its version and table prefix.
# Usage: phpbb-root.sh [start_dir]
# Output: three lines - root=..., version=..., prefix=...
set -euo pipefail

FALLBACK_ROOT=/src/phpbb/phpBB3

find_root() {
	local dir
	dir=$(cd "${1:-$PWD}" 2>/dev/null && pwd) || return 1
	while [ -n "$dir" ]; do
		if [ -f "$dir/common.php" ] && [ -f "$dir/includes/constants.php" ]; then
			printf '%s\n' "$dir"
			return 0
		fi
		[ "$dir" = "/" ] && break
		dir=$(dirname "$dir")
	done
	return 1
}

root=$(find_root "${1:-$PWD}" || true)
if [ -z "$root" ]; then
	if [ -f "$FALLBACK_ROOT/common.php" ]; then
		root=$FALLBACK_ROOT
	else
		echo "phpbb-root: no phpBB root found from ${1:-$PWD} and no reference tree at $FALLBACK_ROOT" >&2
		exit 1
	fi
fi

version=$(sed -n "s/.*define('PHPBB_VERSION', *'\([^']*\)').*/\1/p" "$root/includes/constants.php" | head -1)
prefix=unknown
if [ -f "$root/config.php" ]; then
	p=$(sed -n "s/.*\$table_prefix *= *'\([^']*\)'.*/\1/p" "$root/config.php" | head -1)
	[ -n "$p" ] && prefix=$p
fi

echo "root=$root"
echo "version=${version:-unknown}"
echo "prefix=$prefix"
