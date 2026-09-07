#!/usr/bin/env python3
"""Print one phpBB table's definition from install/schemas/schema.json.

Usage: table-schema.py <table> [--root PATH]
The table name may be given with or without the phpbb_ prefix.
"""
import argparse
import json
import os
import sys

FALLBACK_ROOT = "/src/phpbb/phpBB3"


def find_root(start):
    d = os.path.abspath(start)
    while True:
        if os.path.isfile(os.path.join(d, "common.php")) and os.path.isfile(
            os.path.join(d, "includes", "constants.php")
        ):
            return d
        parent = os.path.dirname(d)
        if parent == d:
            break
        d = parent
    if os.path.isfile(os.path.join(FALLBACK_ROOT, "common.php")):
        return FALLBACK_ROOT
    return None


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("table")
    ap.add_argument("--root", default=None)
    args = ap.parse_args()

    root = args.root or find_root(os.getcwd())
    if not root:
        print("table-schema: no phpBB root found", file=sys.stderr)
        return 1

    path = os.path.join(root, "install", "schemas", "schema.json")
    with open(path) as fh:
        schema = json.load(fh)

    name = args.table if args.table in schema else "phpbb_" + args.table
    if name not in schema:
        print(
            "table-schema: unknown table %r (try one of: %s ...)"
            % (args.table, ", ".join(sorted(schema)[:5])),
            file=sys.stderr,
        )
        return 1

    table = schema[name]
    print("TABLE %s   (%s)" % (name, os.path.relpath(path, root)))
    print()
    width = max(len(c) for c in table["COLUMNS"])
    for col, spec in table["COLUMNS"].items():
        col_type = spec[0]
        default = spec[1]
        extra = " ".join(str(x) for x in spec[2:])
        default_str = "NULL" if default is None else repr(default)
        print("  %-*s  %-14s default=%-10s %s" % (width, col, col_type, default_str, extra))
    print()
    print("  PRIMARY KEY: %s" % table.get("PRIMARY_KEY"))
    for key, spec in table.get("KEYS", {}).items():
        print("  KEY %s: %s" % (key, spec))
    return 0


if __name__ == "__main__":
    sys.exit(main())
