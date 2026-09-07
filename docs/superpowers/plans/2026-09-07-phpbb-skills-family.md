# phpBB Skills Family Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build six Claude Code skills in `/src/phpbb/skills` that let an agent work competently on phpBB 3.3 — data model, text-formatting pipeline, extensions, styles, and operations.

**Architecture:** Six sibling skill directories at the repository root, each a `SKILL.md` router plus `references/*.md` loaded on demand. The `phpbb` hub owns three shell/Python helper scripts that every skill calls to verify facts against a real phpBB tree instead of reciting them. Skills detect the current project's phpBB root and fall back to `/src/phpbb/phpBB3` (3.3.17) as a reference tree.

**Tech Stack:** Markdown with YAML frontmatter (Claude Code skill format), POSIX shell, Python 3 (stdlib only).

## Global Constraints

- **Skill content language: English.** Frontmatter, body, references, script help text, README. (Conversation with the user stays French; that is out of scope for these files.)
- **Target: phpBB 3.3.x.** The reference tree is `/src/phpbb/phpBB3`, version 3.3.17. Do not document 3.2-and-earlier or 4.x specifics.
- **Portability.** `/src/phpbb/phpBB3` may appear ONLY as a named fallback reference tree in `phpbb/SKILL.md` and in the scripts' fallback logic. No other absolute path in any file. Everything else is relative to a detected phpBB root.
- **No invented facts.** Every event name, method signature, column name, service id, CLI command or file path written into a skill must be verified in the reference tree first. When in doubt, tell the reader to look it up rather than guessing.
- **`SKILL.md` size: under 250 lines each.** Detail belongs in `references/`.
- **Frontmatter format:** exactly `name` and `description` keys. `name` matches the directory name. `description` starts with "Use when …" and names concrete trigger words so skill selection is precise.
- **Repository:** `/src/phpbb/skills`, git branch `materio`, no remote. Commit after every task with the trailer block shown in each Step 5.
- **No `.claude-plugin/plugin.json`.** Raw skills plus a README only.
- **Verification is manual, not unit tests.** There is no test runner in this repository. Each task's "test" step is an explicit command whose output is checked against a stated expectation. Run it and read the output; do not claim a step passed without doing so.

## Reference facts (verified 2026-09-07 against /src/phpbb/phpBB3)

Use these; do not re-derive them, but do re-verify anything you extend.

- `PHPBB_VERSION` is defined in `includes/constants.php` as `'3.3.17'`.
- A phpBB root contains both `common.php` and `includes/constants.php`.
- `install/schemas/schema.json` holds 69 tables. Each table maps to
  `{"COLUMNS": {name: [TYPE, default, extra?]}, "PRIMARY_KEY": ..., "KEYS": {...}}`.
  Types are phpBB abstractions (`ULINT`, `UINT`, `BOOL`, `VCHAR:40`,
  `VCHAR_UNI:255`, `STEXT_UNI`, `MTEXT_UNI`, `TIMESTAMP`, `TINT:3`, `USINT`).
- `docs/events.md` documents **template events only** — 526 entries. Format:
  event name on its own line, then a line of `===`, then `* Location:` (91
  entries) or `* Locations:` with `    + path` lines (435 entries), then
  `* Since:` and `* Purpose:`, sometimes `* Changed:`.
- PHP events are **not** in `docs/events.md`. There are ~518 unique
  `core.*` events, each documented in a docblock directly above its call site:
  `@event core.name`, one `@var TYPE name description` per variable, `@since`,
  optional `@changed`. The call site is
  `$vars = array('a', 'b'); extract($phpbb_dispatcher->trigger_event('core.name', compact($vars)));`
- prosilver templates use the legacy syntax `<!-- EVENT name -->`, not
  `{% EVENT name %}`. `phpbb/template/twig/lexer.php` converts legacy syntax to
  Twig, so both work; document that both exist and that prosilver uses legacy.
- `styles/prosilver/theme/stylesheet.css` imports in this exact order:
  normalize, base, utilities, common, links, content, buttons, cp, forms,
  icons, colours, responsive. (`bidi.css`, `print.css`, `tweaks.css` are
  present in the directory but not in that import list — verify how they are
  loaded before documenting them.)
- `styles/prosilver/style.cfg` keys: `name`, `copyright`, `style_version`,
  `phpbb_version`, optional `template_bitfield`, `parent`.
- The 29 CLI command names, from `setName()` calls in `phpbb/console/command/`:
  `cache:purge`, `config:delete`, `config:get`, `config:increment`,
  `config:set`, `config:set-atomic`, `cron:list`, `cron:run`, `db:list`,
  `db:migrate`, `db:revert`, `dev:migration-tips`, `extension:disable`,
  `extension:enable`, `extension:purge`, `extension:show`,
  `fixup:fix-left-right-ids`, `fixup:update-hashes`, `reparser:list`,
  `reparser:reparse`, `thumbnail:delete`, `thumbnail:generate`,
  `thumbnail:recreate`, `update:check`, `user:activate`, `user:add`,
  `user:delete`, `user:delete_id`, `user:reclean`.
- `ext/phpbb/viglink/` is a complete extension shipped with core: `ext.php`
  (extends `\phpbb\extension\base`, overrides `is_enableable()` and
  `enable_step()`), `composer.json` (`"type": "phpbb-extension"`, `extra.display-name`),
  `config/services.yml` (+ `imports:` of `cron.yml`, services tagged
  `{ name: event.listener }`), `event/listener.php` (implements
  `EventSubscriberInterface`, `getSubscribedEvents()`), five files in
  `migrations/`, `acp/`, `cron/`, `language/`, `styles/`.
- Text formatting entry points in `includes/functions_content.php`:
  `generate_text_for_display($text, $uid, $bitfield, $flags, $censor_text = true)` line 575,
  `generate_text_for_storage(&$text, &$uid, &$bitfield, &$flags, $allow_bbcode = false, $allow_urls = false, $allow_smilies = false, $allow_img_bbcode = true, $allow_flash_bbcode = true, $allow_quote_bbcode = true, $allow_url_bbcode = true, $mode = 'post')` line 694,
  `generate_text_for_edit($text, $uid, $flags)` line 777.
- `phpbb/textformatter/` interfaces: `parser_interface`, `renderer_interface`
  (`render`, `set_smilies_path`, `get_/set_viewcensors|viewflash|viewimg|viewsmilies`),
  `utils_interface` (`clean_formatting`, `generate_quote`, and more — read it),
  `cache_interface`, `acp_utils_interface`. Implementation in
  `phpbb/textformatter/s9e/`: `factory`, `parser`, `renderer`, `utils`,
  `bbcode_merger`, `link_helper`, `quote_helper`, `acp_utils`.
- `phpbb_posts` storage columns for formatted text: `post_text` (MTEXT_UNI),
  `bbcode_uid` (VCHAR:8), `bbcode_bitfield` (VCHAR:255), plus the per-post
  toggles `enable_bbcode`, `enable_smilies`, `enable_magic_url`, `enable_sig`.

## File Structure

```
/src/phpbb/skills/
  README.md                            Task 8
  phpbb/
    SKILL.md                           Task 2
    scripts/phpbb-root.sh              Task 1
    scripts/find-event.sh              Task 1
    scripts/table-schema.py            Task 1
  phpbb-data/
    SKILL.md                           Task 3
    references/tables.md               Task 3
    references/pitfalls.md             Task 3
    references/dbal.md                 Task 3
  phpbb-formatting/
    SKILL.md                           Task 4
    references/pipeline.md             Task 4
    references/pipeline-elements.md    Task 4
    references/custom-bbcodes.md       Task 4
    references/reparser.md             Task 4
  phpbb-extensions/
    SKILL.md                           Task 5
    references/anatomy.md              Task 5
    references/events.md               Task 5
    references/migrations.md           Task 5
    references/modules.md              Task 5
  phpbb-styles/
    SKILL.md                           Task 6
    references/inheritance.md          Task 6
    references/twig.md                 Task 6
    references/css.md                  Task 6
  phpbb-admin/
    SKILL.md                           Task 7
    references/cli.md                  Task 7
    references/operations.md           Task 7
```

Task 1 comes first because every later `SKILL.md` documents how to call the
scripts, and Task 2 (the hub) fixes the vocabulary and the routing table that
Tasks 3-7 must match. Tasks 3-7 are mutually independent and may run in
parallel. Task 8 is last because the README lists what exists.

---

### Task 1: Helper scripts

**Files:**
- Create: `phpbb/scripts/phpbb-root.sh`
- Create: `phpbb/scripts/find-event.sh`
- Create: `phpbb/scripts/table-schema.py`

**Interfaces:**
- Consumes: nothing.
- Produces: three executables that every later `SKILL.md` references by the
  relative path `phpbb/scripts/<name>`. Their contracts:
  - `phpbb-root.sh [start_dir]` → prints `root=<abs path>`, `version=<x.y.z>`,
    `prefix=<table prefix or unknown>` on three lines; exit 0 on success,
    exit 1 with a message on stderr if no root is found.
  - `find-event.sh <pattern> [phpbb_root]` → prints matching template events
    from `docs/events.md` under a `## Template events` heading and matching PHP
    events (docblock + call site) under `## PHP events`; exit 0 even when there
    are no matches (prints `(no matches)` under the empty heading).
  - `table-schema.py <table> [--root PATH]` → prints the table's columns,
    primary key and keys from `install/schemas/schema.json`; accepts the name
    with or without the `phpbb_` prefix; exit 1 with a message on stderr for an
    unknown table.
- All three accept an explicit root; when omitted they autodetect by walking up
  from `$PWD`, then fall back to `/src/phpbb/phpBB3`.

- [ ] **Step 1: Write the failing verification**

Create `/tmp/verify-task1.sh` (scratch, not committed) holding the checks this
task must satisfy:

```bash
#!/usr/bin/env bash
set -u
S=/src/phpbb/skills/phpbb/scripts
fail=0
chk() { if eval "$2" >/dev/null 2>&1; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }

chk "phpbb-root.sh is executable"        "test -x $S/phpbb-root.sh"
chk "find-event.sh is executable"        "test -x $S/find-event.sh"
chk "table-schema.py is executable"      "test -x $S/table-schema.py"
chk "root detection from phpBB3"         "cd /src/phpbb/phpBB3 && $S/phpbb-root.sh | grep -q '^version=3.3.17$'"
chk "root detection from a subdirectory" "cd /src/phpbb/phpBB3/phpbb/textformatter && $S/phpbb-root.sh | grep -q '^root=/src/phpbb/phpBB3$'"
chk "root fallback outside any tree"     "cd /tmp && $S/phpbb-root.sh | grep -q '^root=/src/phpbb/phpBB3$'"
chk "find-event finds a template event"  "$S/find-event.sh viewtopic_topic_title_before | grep -q 'viewtopic_body.html'"
chk "find-event finds a PHP event"       "$S/find-event.sh viewtopic_post_row_after | grep -q '@var.*topic_data'"
chk "find-event splits the two sections" "$S/find-event.sh viewtopic_post_row | grep -q '## PHP events'"
chk "find-event survives no match"       "$S/find-event.sh zzzz_no_such_event_zzzz | grep -q '(no matches)'"
chk "table-schema with prefix"           "$S/table-schema.py phpbb_posts | grep -q 'bbcode_bitfield'"
chk "table-schema without prefix"        "$S/table-schema.py posts | grep -q 'PRIMARY KEY: post_id'"
chk "table-schema unknown table exits 1" "! $S/table-schema.py no_such_table"
exit $fail
```

- [ ] **Step 2: Run it to make sure it fails**

Run: `bash /tmp/verify-task1.sh`
Expected: every line `FAIL` (the scripts do not exist yet), exit status 1.

- [ ] **Step 3: Write the three scripts**

`phpbb/scripts/phpbb-root.sh`:

```bash
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
```

`phpbb/scripts/find-event.sh`:

```bash
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
```

`phpbb/scripts/table-schema.py`:

```python
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
```

Then: `chmod +x /src/phpbb/skills/phpbb/scripts/*`

- [ ] **Step 4: Run the verification to make sure it passes**

Run: `bash /tmp/verify-task1.sh`
Expected: 13 lines all starting `ok`, exit status 0.

If `find-event.sh` misses the PHP docblock for `viewtopic_post_row_after`,
check the awk window logic against the real docblock at
`/src/phpbb/phpBB3/viewtopic.php:2227-2256` (the `@event` line itself is 2230)
before changing the test.

- [ ] **Step 5: Commit**

```bash
cd /src/phpbb/skills
git add phpbb/scripts
git commit -m "$(printf '%s\n' \
  'Add phpBB helper scripts: root detection, event lookup, table schema' '' \
  'Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>' \
  'Claude-Session: https://claude.ai/code/session_01JDw9d4GQqPiJDdVKnAdJtw')"
```

---

### Task 2: The `phpbb` hub skill

**Files:**
- Create: `phpbb/SKILL.md`

**Interfaces:**
- Consumes: the three scripts from Task 1, by relative path `scripts/<name>`.
- Produces: the shared vocabulary and the routing table that Tasks 3-7 must
  match. The exact skill names it routes to are `phpbb-data`,
  `phpbb-formatting`, `phpbb-extensions`, `phpbb-styles`, `phpbb-admin`. It
  also fixes the wording of the "verify, do not recall" rule, which every other
  `SKILL.md` restates in one line.

- [ ] **Step 1: Write the failing verification**

Create `/tmp/verify-task2.sh`:

```bash
#!/usr/bin/env bash
set -u
F=/src/phpbb/skills/phpbb/SKILL.md
fail=0
chk() { if eval "$2" >/dev/null 2>&1; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }

chk "SKILL.md exists"              "test -f $F"
chk "frontmatter name is phpbb"    "sed -n '2p' $F | grep -q '^name: phpbb$'"
chk "description starts with 'Use when'" "grep -q '^description: Use when' $F"
chk "under 250 lines"              "test \$(wc -l < $F) -lt 250"
chk "routes to all five skills"    "grep -q phpbb-data $F && grep -q phpbb-formatting $F && grep -q phpbb-extensions $F && grep -q phpbb-styles $F && grep -q phpbb-admin $F"
chk "documents all three scripts"  "grep -q phpbb-root.sh $F && grep -q find-event.sh $F && grep -q table-schema.py $F"
chk "names the reference tree"     "grep -q '/src/phpbb/phpBB3' $F"
chk "states the events.md caveat"  "grep -qi 'template events' $F && grep -q '@event' $F"
chk "has the verify-dont-recall rule" "grep -qi 'never.*from memory\|do not recall\|verify' $F"
exit $fail
```

- [ ] **Step 2: Run it to make sure it fails**

Run: `bash /tmp/verify-task2.sh`
Expected: `FAIL SKILL.md exists` and every subsequent check failing, exit 1.

- [ ] **Step 3: Write `phpbb/SKILL.md`**

Frontmatter, verbatim:

```markdown
---
name: phpbb
description: Use when working on a phpBB 3.3 forum and the specific area is not yet clear - orienting in the codebase, locating the phpBB root and version, mapping the tree, or deciding which phpBB skill applies. Routes to phpbb-data, phpbb-formatting, phpbb-extensions, phpbb-styles and phpbb-admin.
---
```

The body must contain these sections, in this order:

1. **Locate the forum first.** Run `scripts/phpbb-root.sh` and quote its
   three output lines. Explain that a phpBB root is a directory holding both
   `common.php` and `includes/constants.php`, that `PHPBB_VERSION` lives in
   `includes/constants.php`, and that the table prefix comes from
   `$table_prefix` in `config.php` (default `phpbb_`, but never assume it).
   State that when no project root is found the script falls back to the
   reference tree `/src/phpbb/phpBB3` (phpBB 3.3.17), which is a read-only
   source of truth, never an edit target.

2. **The rule: verify, do not recall.** One short paragraph. Event names,
   method signatures, column names, service ids and CLI commands must be read
   from the tree before being written down. Point at the three scripts as the
   cheap way to do it.

3. **Tree map.** A table with one row per top-level directory and its role:
   `phpbb/` (PSR-4 library, namespace `\phpbb\`), `includes/` (legacy
   procedural functions, still load-bearing — `functions_content.php`,
   `functions_posting.php`, `message_parser.php`), `config/default/container/`
   (Symfony DI wiring, `services_*.yml`), `styles/` (prosilver + `all/`),
   `ext/` (extensions, vendor/package layout, `ext/phpbb/viglink` shipped),
   `adm/` (ACP), `language/`, `install/` (`schemas/schema.json`), `docs/`,
   `bin/phpbbcli.php`, `cache/`, `store/`, `files/`, `vendor/`.

4. **Authoritative sources.** A table: what you want → where to read it.
   Template events → `docs/events.md` (526 entries, template events ONLY).
   PHP events → `@event` docblocks above `trigger_event()` in the source
   (~518 unique `core.*` names; NOT in `docs/events.md`). Schema →
   `install/schemas/schema.json`. A worked extension → `ext/phpbb/viglink/`.
   Style baseline → `styles/prosilver/`. Conventions →
   `docs/coding-guidelines.html`. Services → `config/default/container/`.

5. **The scripts.** One subsection each, with a real invocation and a trimmed
   sample of its real output. Get the samples by running the scripts; do not
   invent them.

6. **Routing table.** Five rows: skill name, when to use it, one-line summary.
   Copy the wording from the spec's roster table so the descriptions agree.

7. **Core conventions.** Short list: never patch core files (use an extension
   or a style); prefer an event over a template override; purge the cache after
   changing templates, styles, language files or services
   (`php bin/phpbbcli.php cache:purge`); schema changes go through a migration,
   never raw DDL; every user-facing string goes through a language file.

- [ ] **Step 4: Run the verification to make sure it passes**

Run: `bash /tmp/verify-task2.sh`
Expected: 9 lines all starting `ok`, exit 0.

Then run each script invocation you quoted in the file and confirm the output
you pasted matches. Run: `cd /src/phpbb/phpBB3 && /src/phpbb/skills/phpbb/scripts/phpbb-root.sh`

- [ ] **Step 5: Commit**

```bash
cd /src/phpbb/skills
git add phpbb/SKILL.md
git commit -m "$(printf '%s\n' \
  'Add the phpbb hub skill' '' \
  'Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>' \
  'Claude-Session: https://claude.ai/code/session_01JDw9d4GQqPiJDdVKnAdJtw')"
```

---

### Task 3: `phpbb-data`

**Files:**
- Create: `phpbb-data/SKILL.md`
- Create: `phpbb-data/references/tables.md`
- Create: `phpbb-data/references/pitfalls.md`
- Create: `phpbb-data/references/dbal.md`

**Interfaces:**
- Consumes: `phpbb/scripts/table-schema.py` and `phpbb/scripts/phpbb-root.sh`
  from Task 1; the tree map and "verify, do not recall" rule from Task 2.
- Produces: the canonical table groupings that `phpbb-formatting` (Task 4) and
  `phpbb-extensions` (Task 5) link to instead of restating.

- [ ] **Step 1: Write the failing verification**

Create `/tmp/verify-task3.sh`:

```bash
#!/usr/bin/env bash
set -u
D=/src/phpbb/skills/phpbb-data
fail=0
chk() { if eval "$2" >/dev/null 2>&1; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }

chk "SKILL.md exists"          "test -f $D/SKILL.md"
chk "name matches directory"   "sed -n '2p' $D/SKILL.md | grep -q '^name: phpbb-data$'"
chk "description Use when"     "grep -q '^description: Use when' $D/SKILL.md"
chk "under 250 lines"          "test \$(wc -l < $D/SKILL.md) -lt 250"
chk "tables.md exists"         "test -f $D/references/tables.md"
chk "pitfalls.md exists"       "test -f $D/references/pitfalls.md"
chk "dbal.md exists"           "test -f $D/references/dbal.md"
# every table in schema.json must be named somewhere in tables.md
python3 - "$D/references/tables.md" <<'PY' > /tmp/missing-tables.txt
import json, os, sys
schema = json.load(open("/src/phpbb/phpBB3/install/schemas/schema.json"))
doc = open(sys.argv[1]).read() if os.path.exists(sys.argv[1]) else ""
for t in sorted(schema):
    if t not in doc:
        print(t)
PY
chk "all 69 tables listed"     "test ! -s /tmp/missing-tables.txt"
chk "nested set documented"    "grep -q 'left_id' $D/references/pitfalls.md"
chk "visibility documented"    "grep -q 'post_visibility' $D/references/pitfalls.md"
chk "acl cache documented"     "grep -q 'user_permissions' $D/references/pitfalls.md"
chk "table prefix warning"     "grep -q 'table_prefix\|prefix' $D/references/pitfalls.md"
chk "dbal names real methods"  "grep -q 'sql_build_query' $D/references/dbal.md && grep -q 'sql_in_set' $D/references/dbal.md && grep -q 'sql_query_limit' $D/references/dbal.md"
chk "no stray absolute paths"  "! grep -rn '/src/phpbb' $D"
exit $fail
```

- [ ] **Step 2: Run it to make sure it fails**

Run: `bash /tmp/verify-task3.sh`
Expected: all `FAIL`, exit 1.

- [ ] **Step 3: Write the four files**

`phpbb-data/SKILL.md` frontmatter, verbatim:

```markdown
---
name: phpbb-data
description: Use when working with phpBB 3.3 data - reading or writing the schema, understanding tables like phpbb_posts, phpbb_topics, phpbb_forums, phpbb_users or the phpbb_acl_* permission tables, writing SQL or DBAL queries, or interpreting counters, visibility flags and forum tree ids.
---
```

Body: a short orientation (how to inspect a table with
`../phpbb/scripts/table-schema.py <name>`, that the prefix is configurable, the
one-line "verify, do not recall" restatement), the domain groupings with a
one-line purpose each, then links to the three references.

`references/tables.md`: every one of the 69 tables, grouped as — Content
(forums, topics, posts, attachments, poll_options, poll_votes, reports,
reports_reasons, icons, drafts, bookmarks, topics_posted, topics_track,
forums_track, topics_watch, forums_watch, forums_access), Users & auth (users,
groups, user_group, ranks, profile_fields, profile_fields_data,
profile_fields_lang, profile_lang, oauth_accounts, oauth_states, oauth_tokens,
banlist, disallow, warnings, zebra, login_attempts, bots), Permissions
(acl_options, acl_roles, acl_roles_data, acl_groups, acl_users,
moderator_cache, teampage), Sessions (sessions, sessions_keys, confirm),
Private messages (privmsgs, privmsgs_to, privmsgs_folder, privmsgs_rules,
notifications, notification_types, notification_emails, user_notifications),
Search (search_wordlist, search_wordmatch, search_results, words), System
(config, config_text, ext, extensions, extension_groups, migrations, modules,
styles, lang, log, sitelist, smilies, bbcodes). Each row: table name, one-line
purpose, the columns that matter most, and its main foreign relationships.
Generate the list from `schema.json` so none is missed — a check in Step 4
counts them.

`references/pitfalls.md`: forums as a nested set (`left_id`/`right_id`, why you
never renumber them by hand, `fixup:fix-left-right-ids`); soft delete and
approval via `post_visibility` / `topic_visibility` and the `content_visibility`
service (read `phpbb/content_visibility.php` before documenting the constants);
denormalised counters (`topic_posts_approved`, `topic_posts_unapproved`,
`topic_posts_softdeleted`, `forum_posts_approved`, `user_posts`) and that they
are maintained by the service, not by triggers; permission resolution from
`acl_options` + `acl_roles_data` + `acl_groups`/`acl_users` into the cached
`users.user_permissions` blob, and that changing ACL rows requires clearing
that cache; read tracking (`topics_track`, `forums_track`, `topics_posted`) and
the cookie-based fallback; the configurable table prefix.

`references/dbal.md`: `$db` is `\phpbb\db\driver\driver_interface`. Document
`sql_query`, `sql_query_limit`, `sql_build_query('SELECT', ...)`,
`sql_build_array`, `sql_in_set`, `sql_escape`, `sql_multi_insert`,
`sql_fetchrow`/`sql_fetchrowset`/`sql_freeresult`, `sql_transaction`,
`sql_affectedrows`, `sql_nextid`. Read `phpbb/db/driver/driver_interface.php`
and copy the real signatures. State plainly that raw PDO or `mysqli` bypasses
the abstraction and breaks on other supported drivers, and that string
interpolation into SQL without `sql_escape` / `sql_in_set` is the standard
injection bug in phpBB code.

- [ ] **Step 4: Run the verification to make sure it passes**

Run: `bash /tmp/verify-task3.sh`
Expected: 14 lines all `ok`, exit 0. The "all 69 tables listed" check is the
one that catches an incomplete `tables.md`; when it fails,
`/tmp/missing-tables.txt` names exactly which tables you left out.

Spot-check three signatures you wrote in `dbal.md` against
`/src/phpbb/phpBB3/phpbb/db/driver/driver_interface.php`.

- [ ] **Step 5: Commit**

```bash
cd /src/phpbb/skills
git add phpbb-data
git commit -m "$(printf '%s\n' \
  'Add the phpbb-data skill' '' \
  'Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>' \
  'Claude-Session: https://claude.ai/code/session_01JDw9d4GQqPiJDdVKnAdJtw')"
```

---

### Task 4: `phpbb-formatting`

**Files:**
- Create: `phpbb-formatting/SKILL.md`
- Create: `phpbb-formatting/references/pipeline.md`
- Create: `phpbb-formatting/references/pipeline-elements.md`
- Create: `phpbb-formatting/references/custom-bbcodes.md`
- Create: `phpbb-formatting/references/reparser.md`

**Interfaces:**
- Consumes: Task 2's rule and tree map; Task 3's `phpbb_posts` column
  descriptions (link to `../phpbb-data/references/tables.md`, do not restate).
- Produces: nothing other tasks depend on.

This is the skill the user cares most about. Weight it toward **reading,
rendering and transforming** existing content and toward the surrounding
pipeline elements (smilies, attachments, magic URLs, censoring). Creating
custom BBCodes and writing content programmatically are covered but shorter.

- [ ] **Step 1: Write the failing verification**

Create `/tmp/verify-task4.sh`:

```bash
#!/usr/bin/env bash
set -u
D=/src/phpbb/skills/phpbb-formatting
R=/src/phpbb/phpBB3
fail=0
chk() { if eval "$2" >/dev/null 2>&1; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }

chk "SKILL.md exists"            "test -f $D/SKILL.md"
chk "name matches directory"     "sed -n '2p' $D/SKILL.md | grep -q '^name: phpbb-formatting$'"
chk "description Use when"       "grep -q '^description: Use when' $D/SKILL.md"
chk "under 250 lines"            "test \$(wc -l < $D/SKILL.md) -lt 250"
chk "four references exist"      "test -f $D/references/pipeline.md -a -f $D/references/pipeline-elements.md -a -f $D/references/custom-bbcodes.md -a -f $D/references/reparser.md"
chk "storage quadruple named"    "grep -q bbcode_uid $D/references/pipeline.md && grep -q bbcode_bitfield $D/references/pipeline.md"
chk "read path documented"       "grep -q generate_text_for_display $D/references/pipeline.md"
chk "edit path documented"       "grep -q generate_text_for_edit $D/references/pipeline.md"
chk "write path documented"      "grep -q generate_text_for_storage $D/references/pipeline.md"
chk "raw INSERT warning"         "grep -qi 'raw sql\|INSERT' $D/references/pipeline.md"
chk "utils service named"        "grep -q 'text_formatter.utils' $D/references/pipeline.md"
chk "renderer service named"     "grep -q 'text_formatter.renderer' $D/references/pipeline.md"
chk "smilies covered"            "grep -qi smilies $D/references/pipeline-elements.md"
chk "attachments covered"        "grep -q 'attachment=' $D/references/pipeline-elements.md"
chk "magic urls covered"         "grep -q link_helper $D/references/pipeline-elements.md"
chk "censoring covered"          "grep -q 'phpbb_words\|viewcensors' $D/references/pipeline-elements.md"
chk "bbcode_match documented"    "grep -q bbcode_match $D/references/custom-bbcodes.md"
chk "reparser cli documented"    "grep -q 'reparser:reparse' $D/references/reparser.md"
chk "no stray absolute paths"    "! grep -rn '/src/phpbb' $D"
# every function named in pipeline.md must exist in the tree
chk "generate_text_for_display is real" "grep -q 'function generate_text_for_display' $R/includes/functions_content.php"
chk "text_formatter services are real"  "grep -rq 'text_formatter.utils' $R/config/default/container/"
exit $fail
```

- [ ] **Step 2: Run it to make sure it fails**

Run: `bash /tmp/verify-task4.sh`
Expected: the `$D` checks all `FAIL`, the two `$R` checks `ok`, exit 1.

- [ ] **Step 3: Write the five files**

`phpbb-formatting/SKILL.md` frontmatter, verbatim:

```markdown
---
name: phpbb-formatting
description: Use when reading, rendering, extracting or transforming phpBB post and message text - BBCode, smilies, attachments, magic URLs, word censoring, signatures, bbcode_uid and bbcode_bitfield, the s9e/TextFormatter services, or bulk reparsing with reparser:reparse.
---
```

Body: the pipeline in one diagram-free paragraph, then the decision tree —
*I want to display it* / *I want to let a user edit it* / *I want to store new
text* / *I want plain text out of it* / *I want to change formatting across the
whole board* — each branch naming the function or service and linking to the
right reference. Then the single most important warning, stated plainly: post
text in the database is **not** BBCode as typed and **not** HTML; it is an
intermediate representation keyed by `bbcode_uid`, so reading `post_text`
directly or writing it with a raw `INSERT` produces broken output.

`references/pipeline.md`:
- Storage: `post_text`, `bbcode_uid` (VCHAR:8), `bbcode_bitfield` (VCHAR:255),
  and the per-post toggles `enable_bbcode`, `enable_smilies`,
  `enable_magic_url`, `enable_sig`. Note that phpBB 3.2+ stores s9e XML in
  `post_text` for new posts while legacy rows keep the 3.0 uid format, and both
  are handled transparently by the renderer — verify this against
  `phpbb/textformatter/s9e/parser.php` and `renderer.php` before writing it.
- Reading: `generate_text_for_display($text, $uid, $bitfield, $flags, $censor_text = true)`
  in `includes/functions_content.php:575`, and the underlying
  `text_formatter.renderer` service (`render()`, `set_smilies_path()`,
  `set_viewcensors()`, `set_viewsmilies()`, `set_viewimg()`, `set_viewflash()`).
- Editing: `generate_text_for_edit($text, $uid, $flags)` at line 777 —
  returns the text as the user typed it, for a textarea.
- Writing: `generate_text_for_storage(&$text, &$uid, &$bitfield, &$flags, ...)`
  at line 694 with its full parameter list, and `submit_post()` in
  `includes/functions_posting.php` for the complete path that also updates
  counters, search index, notifications and tracking. Say explicitly which one
  to use when.
- Extracting: the `text_formatter.utils` service — read
  `phpbb/textformatter/utils_interface.php` and document each method with its
  real signature (`clean_formatting`, `generate_quote`, and the rest).
- Where the services are declared: `config/default/container/`.

`references/pipeline-elements.md`: smilies (`phpbb_smilies` columns,
`set_smilies_path()`, `smiley_text()`), attachments (`[attachment=n]` markers,
`phpbb_attachments`, `parse_attachments()` in `includes/functions_content.php`,
the `post_attachment` flag on the post row), magic URLs
(`phpbb/textformatter/s9e/link_helper.php`, `enable_magic_url`), word censoring
(`phpbb_words`, the `viewcensors` user option, `censor_text()`), signatures
(`user_sig`, `user_sig_bbcode_uid`, `user_sig_bbcode_bitfield`,
`enable_sig`). For each: how it is stored, how it is rendered, and what
breaks if you bypass it.

`references/custom-bbcodes.md`: the `phpbb_bbcodes` table columns,
`bbcode_match` / `bbcode_tpl` syntax, the available tokens — verify the real
token list in `phpbb/textformatter/acp_utils.php` / `s9e/acp_utils.php` before
listing them — how `bbcode_merger` combines the paired and unpaired forms,
adding a BBCode through the ACP versus through an extension migration, and the
requirement to reparse existing content afterwards (link to `reparser.md`).

`references/reparser.md`: what `phpbb/textreparser/` does, the shipped
reparsers, `php bin/phpbbcli.php reparser:list` and
`reparser:reparse [name] [--range-min] [--range-max] [--dry-run]` — read
`phpbb/console/command/reparser/reparse.php` for the real options — and when
reparsing is required (BBCode added or changed, smiley code changed, censor
list changed, magic URL behaviour changed).

- [ ] **Step 4: Run the verification to make sure it passes**

Run: `bash /tmp/verify-task4.sh`
Expected: 21 lines all `ok`, exit 0.

Then verify every method you listed from `utils_interface` actually exists:
`grep -n 'function' /src/phpbb/phpBB3/phpbb/textformatter/utils_interface.php`

- [ ] **Step 5: Commit**

```bash
cd /src/phpbb/skills
git add phpbb-formatting
git commit -m "$(printf '%s\n' \
  'Add the phpbb-formatting skill' '' \
  'Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>' \
  'Claude-Session: https://claude.ai/code/session_01JDw9d4GQqPiJDdVKnAdJtw')"
```

---

### Task 5: `phpbb-extensions`

**Files:**
- Create: `phpbb-extensions/SKILL.md`
- Create: `phpbb-extensions/references/anatomy.md`
- Create: `phpbb-extensions/references/events.md`
- Create: `phpbb-extensions/references/migrations.md`
- Create: `phpbb-extensions/references/modules.md`

**Interfaces:**
- Consumes: `phpbb/scripts/find-event.sh` from Task 1; Task 2's rule and
  authoritative-sources table.
- Produces: nothing other tasks depend on.

Everything in `anatomy.md` must be traceable to `ext/phpbb/viglink/`. Read
those files; do not write an extension layout from memory.

- [ ] **Step 1: Write the failing verification**

Create `/tmp/verify-task5.sh`:

```bash
#!/usr/bin/env bash
set -u
D=/src/phpbb/skills/phpbb-extensions
fail=0
chk() { if eval "$2" >/dev/null 2>&1; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }

chk "SKILL.md exists"           "test -f $D/SKILL.md"
chk "name matches directory"    "sed -n '2p' $D/SKILL.md | grep -q '^name: phpbb-extensions$'"
chk "description Use when"      "grep -q '^description: Use when' $D/SKILL.md"
chk "under 250 lines"           "test \$(wc -l < $D/SKILL.md) -lt 250"
chk "four references exist"     "test -f $D/references/anatomy.md -a -f $D/references/events.md -a -f $D/references/migrations.md -a -f $D/references/modules.md"
chk "composer type documented"  "grep -q 'phpbb-extension' $D/references/anatomy.md"
chk "ext.php documented"        "grep -q 'phpbb.extension.base\|extension\\\\base' $D/references/anatomy.md"
chk "services.yml documented"   "grep -q 'event.listener' $D/references/anatomy.md"
chk "viglink cited"             "grep -q viglink $D/references/anatomy.md"
chk "EventSubscriberInterface"  "grep -q EventSubscriberInterface $D/references/events.md"
chk "vars mechanism documented" "grep -q 'compact' $D/references/events.md && grep -q 'extract' $D/references/events.md"
chk "two catalogues explained"  "grep -q 'events.md' $D/references/events.md && grep -q '@event' $D/references/events.md"
chk "find-event.sh referenced"  "grep -q find-event.sh $D/references/events.md"
chk "depends_on documented"     "grep -q depends_on $D/references/migrations.md"
chk "effectively_installed"     "grep -q effectively_installed $D/references/migrations.md"
chk "update_schema documented"  "grep -q update_schema $D/references/migrations.md"
chk "module.add documented"     "grep -q 'module.add' $D/references/migrations.md"
chk "module info documented"    "grep -q '_info.php\|module_basename' $D/references/modules.md"
chk "no stray absolute paths"   "! grep -rn '/src/phpbb' $D"
exit $fail
```

- [ ] **Step 2: Run it to make sure it fails**

Run: `bash /tmp/verify-task5.sh`
Expected: all `FAIL`, exit 1.

- [ ] **Step 3: Write the five files**

`phpbb-extensions/SKILL.md` frontmatter, verbatim:

```markdown
---
name: phpbb-extensions
description: Use when building or modifying a phpBB 3.3 extension in ext/ - composer.json, ext.php, config/services.yml, event listeners, database migrations, ACP/UCP/MCP modules, controllers, cron tasks, language files, or enabling and purging an extension.
---
```

Body: the vendor/package layout under `ext/`, the enable/disable/purge
lifecycle and which CLI commands drive it, the "read `ext/phpbb/viglink/` as
the worked example" instruction, a checklist for creating a new extension from
scratch, and links to the four references.

`references/anatomy.md`: one section per file, each showing the real content
from viglink, trimmed. `composer.json` (`"type": "phpbb-extension"`, `require`
on `phpbb/phpbb` and `composer/installers`, `extra.display-name`,
`extra.soft-require`). `ext.php` (extends `\phpbb\extension\base`,
`is_enableable()` using `phpbb_version_compare(PHPBB_VERSION, ...)`,
`enable_step()` / `disable_step()` / `purge_step()` and their `$old_state`
protocol). `config/services.yml` (`imports:`, service definitions, argument
references `'@config'` / `'@template'`, container parameters
`'%core.root_path%'` / `'%core.php_ext%'`, the
`tags: [{ name: event.listener }]` tag). `config/routing.yml`. `config/cron.yml`.
Then the directory roles: `event/`, `migrations/`, `language/<lang>/`,
`styles/all/template/`, `acp/`, `controller/`, `cron/`, `notification/`.

`references/events.md`:
- The two catalogues and where each lives — restate the fact that
  `docs/events.md` holds template events only and PHP events live in `@event`
  docblocks. Tell the reader to use `../phpbb/scripts/find-event.sh <pattern>`.
- Subscribing: a listener implementing `EventSubscriberInterface`, its
  `getSubscribedEvents()` returning `['core.name' => 'method']`, registration
  in `services.yml` with the `event.listener` tag. Use viglink's
  `event/listener.php` as the model.
- Reading and writing event data: `$event['var']` for reads; for writes,
  `$event['var'] = $value` works only for variables the call site listed in
  `$vars`. Show the real call-site shape:
  `$vars = array('a', 'b'); extract($phpbb_dispatcher->trigger_event('core.name', compact($vars)));`
  and explain that `extract` is what makes a listener's write visible to the
  code after the call.
- Reading an event's contract: the `@var TYPE name description` lines in the
  docblock are the authoritative list, plus `@since` and `@changed`.
- Template events: prosilver uses `<!-- EVENT name -->`; the Twig form
  `{% EVENT name %}` also works because `phpbb/template/twig/lexer.php`
  converts the legacy syntax. An extension hooks one by creating
  `styles/all/template/event/<event_name>.html` — verify that path convention
  in the tree before writing it down.

`references/migrations.md`: class extends `\phpbb\db\migration\migration`,
placed in `migrations/`, namespaced `\vendor\package\migrations`.
`depends_on()` returning the migrations it needs (including a core one such as
`\phpbb\db\migration\data\v33x\v3311` — check what actually exists in
`phpbb/db/migration/data/v33x/` and cite a real class).
`effectively_installed()` for idempotence. `update_schema()` / `revert_schema()`
returning `add_columns` / `drop_columns` / `add_tables` / `drop_tables` /
`add_index` arrays — read `phpbb/db/migration/migration.php` and the tools in
`phpbb/db/tools/` for the real keys. `update_data()` / `revert_data()` with the
real operation names: `config.add`, `config.update`, `config.remove`,
`module.add`, `module.remove`, `permission.add`, `permission.set`,
`permission.role_add`, `custom` — verify the full list in
`phpbb/db/migration/tool/`. Show viglink's `viglink_data.php` as a complete
worked example. Then `php bin/phpbbcli.php db:migrate` and `db:revert`.

`references/modules.md`: ACP/UCP/MCP module classes and their `*_info.php`
companion (`module()` returning `filename`, `title`, `modes`), how
`module.add` in a migration registers them, the `$u_action` / `$this->tpl_name`
/ `$this->page_title` contract, permission constants and `$auth->acl_get()`.
Use viglink's `acp/viglink_module.php` and `acp/viglink_info.php` as the model.

- [ ] **Step 4: Run the verification to make sure it passes**

Run: `bash /tmp/verify-task5.sh`
Expected: 19 lines all `ok`, exit 0.

Then verify the migration tool operation names you listed:
`ls /src/phpbb/phpBB3/phpbb/db/migration/tool/` and confirm each name you wrote
maps to a real tool. Verify the core migration class you cited in `depends_on`
exists: `ls /src/phpbb/phpBB3/phpbb/db/migration/data/v33x/`

- [ ] **Step 5: Commit**

```bash
cd /src/phpbb/skills
git add phpbb-extensions
git commit -m "$(printf '%s\n' \
  'Add the phpbb-extensions skill' '' \
  'Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>' \
  'Claude-Session: https://claude.ai/code/session_01JDw9d4GQqPiJDdVKnAdJtw')"
```

---

### Task 6: `phpbb-styles`

**Files:**
- Create: `phpbb-styles/SKILL.md`
- Create: `phpbb-styles/references/inheritance.md`
- Create: `phpbb-styles/references/twig.md`
- Create: `phpbb-styles/references/css.md`

**Interfaces:**
- Consumes: Task 2's rule and tree map; Task 5's template-event section (link
  to `../phpbb-extensions/references/events.md` rather than restating).
- Produces: nothing other tasks depend on.

Solace at `/src/phpbb/phpbb3-style-solace` is a **case study only**. Describe
what it demonstrates (a style that overrides three templates and inherits the
other 117 from prosilver, with configuration driven by an extension) without
turning this skill into Solace documentation, and without hardcoding its path —
refer to it by name and say it is a third-party style.

- [ ] **Step 1: Write the failing verification**

Create `/tmp/verify-task6.sh`:

```bash
#!/usr/bin/env bash
set -u
D=/src/phpbb/skills/phpbb-styles
fail=0
chk() { if eval "$2" >/dev/null 2>&1; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }

chk "SKILL.md exists"          "test -f $D/SKILL.md"
chk "name matches directory"   "sed -n '2p' $D/SKILL.md | grep -q '^name: phpbb-styles$'"
chk "description Use when"     "grep -q '^description: Use when' $D/SKILL.md"
chk "under 250 lines"          "test \$(wc -l < $D/SKILL.md) -lt 250"
chk "three references exist"   "test -f $D/references/inheritance.md -a -f $D/references/twig.md -a -f $D/references/css.md"
chk "style.cfg keys documented" "grep -q 'style_version' $D/references/inheritance.md && grep -q '^.*parent' $D/references/inheritance.md"
chk "styles/all documented"    "grep -q 'styles/all' $D/references/inheritance.md"
chk "solace as case study"     "grep -qi solace $D/references/inheritance.md"
chk "legacy EVENT syntax"      "grep -q 'EVENT' $D/references/twig.md"
chk "lexer explained"          "grep -q 'lexer' $D/references/twig.md"
chk "lang function documented" "grep -q 'lang(' $D/references/twig.md"
chk "import order documented"  "grep -q 'normalize.css' $D/references/css.md && grep -q 'colours.css' $D/references/css.md && grep -q 'responsive.css' $D/references/css.md"
chk "override vs event tradeoff" "grep -qi 'override' $D/SKILL.md"
chk "cache purge mentioned"    "grep -q 'cache:purge' $D/SKILL.md"
chk "no stray absolute paths"  "! grep -rn '/src/phpbb' $D"
exit $fail
```

- [ ] **Step 2: Run it to make sure it fails**

Run: `bash /tmp/verify-task6.sh`
Expected: all `FAIL`, exit 1.

- [ ] **Step 3: Write the four files**

`phpbb-styles/SKILL.md` frontmatter, verbatim:

```markdown
---
name: phpbb-styles
description: Use when customising the look of a phpBB 3.3 forum - creating or editing a style under styles/, overriding prosilver templates, writing phpBB Twig markup, changing CSS, handling responsive or RTL layouts, or deciding between a template override and a template event.
---
```

Body: how a style is resolved (own template → parent style → prosilver), the
core guidance — **prefer a template event over an override**, because an
override freezes a copy of a prosilver file that will drift at the next
upgrade — the cache-purge requirement after any template or CSS change
(`php bin/phpbbcli.php cache:purge`), and links to the three references.

`references/inheritance.md`: `style.cfg` with its real keys (`name`,
`copyright`, `style_version`, `phpbb_version`, `template_bitfield`, `parent`)
copied from `styles/prosilver/style.cfg`; the resolution order; the role of
`styles/all/` (shared assets and the `template/event/` directory extensions
write into); how an extension ships style files; installing a style through the
ACP and the `phpbb_styles` table; Solace as the case study — a style that
inherits from prosilver, ships three templates instead of ~120, and moves its
configuration into a companion extension, which is why it survives phpBB
upgrades.

`references/twig.md`: phpBB's Twig dialect. `{{ lang('KEY') }}` and
`{{ lang('KEY', arg) }}`; `{% INCLUDE 'file.html' %}`; `{% EVENT name %}` and
the legacy `<!-- EVENT name -->` that prosilver actually uses;
`{% DEFINE $VAR = ... %}`; `{% INCLUDECSS %}` / `{% INCLUDEJS %}`; the legacy
`<!-- IF -->` / `<!-- BEGIN -->` / `<!-- ENDIF -->` block syntax and the fact
that `phpbb/template/twig/lexer.php` rewrites it into Twig, so both appear in
real templates. Read `phpbb/template/twig/tokenparser/` and
`phpbb/template/twig/node/` for the complete tag list and document what is
actually there.

`references/css.md`: the `@import` order in
`styles/prosilver/theme/stylesheet.css` — normalize, base, utilities, common,
links, content, buttons, cp, forms, icons, colours, responsive — with a
one-line role for each; the `?hash=` cache-busting suffix and what regenerates
it; where `bidi.css`, `print.css` and `tweaks.css` are loaded from (find out —
they are in the directory but not in that import list); the RTL approach; the
responsive breakpoints as actually written in `responsive.css`; and the rule
that a child style's stylesheet is loaded after the parent's, so overriding a
rule usually means adding a file rather than editing prosilver's.

- [ ] **Step 4: Run the verification to make sure it passes**

Run: `bash /tmp/verify-task6.sh`
Expected: 15 lines all `ok`, exit 0.

Then confirm the Twig tag list you wrote matches reality:
`ls /src/phpbb/phpBB3/phpbb/template/twig/tokenparser/ /src/phpbb/phpBB3/phpbb/template/twig/node/`

- [ ] **Step 5: Commit**

```bash
cd /src/phpbb/skills
git add phpbb-styles
git commit -m "$(printf '%s\n' \
  'Add the phpbb-styles skill' '' \
  'Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>' \
  'Claude-Session: https://claude.ai/code/session_01JDw9d4GQqPiJDdVKnAdJtw')"
```

---

### Task 7: `phpbb-admin`

**Files:**
- Create: `phpbb-admin/SKILL.md`
- Create: `phpbb-admin/references/cli.md`
- Create: `phpbb-admin/references/operations.md`

**Interfaces:**
- Consumes: Task 2's rule and tree map.
- Produces: nothing other tasks depend on.

- [ ] **Step 1: Write the failing verification**

Create `/tmp/verify-task7.sh`:

```bash
#!/usr/bin/env bash
set -u
D=/src/phpbb/skills/phpbb-admin
R=/src/phpbb/phpBB3
fail=0
chk() { if eval "$2" >/dev/null 2>&1; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }

chk "SKILL.md exists"         "test -f $D/SKILL.md"
chk "name matches directory"  "sed -n '2p' $D/SKILL.md | grep -q '^name: phpbb-admin$'"
chk "description Use when"    "grep -q '^description: Use when' $D/SKILL.md"
chk "under 250 lines"         "test \$(wc -l < $D/SKILL.md) -lt 250"
chk "two references exist"    "test -f $D/references/cli.md -a -f $D/references/operations.md"
chk "config.php documented"   "grep -q 'config.php' $D/references/operations.md"
chk "cache purge documented"  "grep -q 'cache:purge' $D/references/cli.md"
chk "search backends"         "grep -qi 'sphinx\|fulltext' $D/references/operations.md"
chk "no stray absolute paths" "! grep -rn '/src/phpbb' $D"
# every command name defined in the tree must appear in cli.md
grep -rho "setName('[a-z:._-]*')" "$R/phpbb/console/command/" | sed "s/setName('//;s/')//" | sort -u > /tmp/cli-defined.txt
: > /tmp/cli-missing.txt
while read -r cmd; do
	grep -qF "$cmd" "$D/references/cli.md" 2>/dev/null || echo "$cmd" >> /tmp/cli-missing.txt
done < /tmp/cli-defined.txt
chk "cli.md lists all 29 commands" "test ! -s /tmp/cli-missing.txt"
exit $fail
```

- [ ] **Step 2: Run it to make sure it fails**

Run: `bash /tmp/verify-task7.sh`
Expected: all `FAIL`, exit 1.

- [ ] **Step 3: Write the three files**

`phpbb-admin/SKILL.md` frontmatter, verbatim:

```markdown
---
name: phpbb-admin
description: Use when installing, updating or operating a phpBB 3.3 forum - running bin/phpbbcli.php commands, purging the cache, configuring cron, managing permissions and roles in the ACP, reindexing search, handling attachments and thumbnails, editing config.php, or troubleshooting a board.
---
```

Body: the operational entry points (ACP, `bin/phpbbcli.php`, `config.php`,
`cache/`), the three or four things that fix most problems (purge the cache,
re-run migrations, check file permissions on `cache/`, `store/`, `files/`,
`images/avatars/upload/`, enable debug), and links to the two references.

`references/cli.md`: all 29 commands, grouped by namespace, each with its real
arguments and options. Get them from the source rather than guessing:
`php bin/phpbbcli.php list` on a live board, or read the `configure()` method of
each class under `phpbb/console/command/`. Note that the CLI needs a working
`config.php` and a database connection, and that most commands take
`--safe-mode` / `-v`.

`references/operations.md`: installation and update paths (`install/`, and its
removal or renaming afterwards); `config.php` keys (`$dbms`, `$dbhost`,
`$dbname`, `$table_prefix`, `$acm_type`, `PHPBB_INSTALLED`, `PHPBB_ENVIRONMENT`
— read a real `config.php` or `install/` templates to confirm); the cache
(`cache/` directory, ACM drivers, when a purge is mandatory: template, CSS,
language, service, migration and extension changes); cron (the ACP-triggered
mode versus `cron:run` from system cron, and the `phpbb_cron` config toggles);
permissions (`acl_options` groups, roles, group versus user permissions, forum
permissions, the copy-permissions tools in the ACP, and the reminder that the
`user_permissions` cache must be cleared); search backends (native
`fulltext_native`, `fulltext_mysql`, `fulltext_postgres`, `fulltext_sphinx` —
verify the list in `phpbb/search/`) and reindexing from the ACP; attachments
and `thumbnail:*`; debugging (`PHPBB_ENVIRONMENT`, `DEBUG` constants, the error
log); the shipped sample configs `docs/nginx.sample.conf`,
`docs/lighttpd.sample.conf`, `docs/sphinx.sample.conf`; backup scope (database
plus `files/`, `images/`, `store/`, `config.php`, `ext/`, `styles/`).

- [ ] **Step 4: Run the verification to make sure it passes**

Run: `bash /tmp/verify-task7.sh`
Expected: 10 lines all `ok`, exit 0. The last check is the important one: it
compares the command names in your `cli.md` against the names defined in the
source. When it fails, `/tmp/cli-missing.txt` names the commands you omitted.

- [ ] **Step 5: Commit**

```bash
cd /src/phpbb/skills
git add phpbb-admin
git commit -m "$(printf '%s\n' \
  'Add the phpbb-admin skill' '' \
  'Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>' \
  'Claude-Session: https://claude.ai/code/session_01JDw9d4GQqPiJDdVKnAdJtw')"
```

---

### Task 8: README and whole-repository check

**Files:**
- Create: `README.md`

**Interfaces:**
- Consumes: all six skills and the three scripts.
- Produces: the repository's entry point.

- [ ] **Step 1: Write the failing verification**

Create `/tmp/verify-task8.sh`:

```bash
#!/usr/bin/env bash
set -u
D=/src/phpbb/skills
fail=0
chk() { if eval "$2" >/dev/null 2>&1; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }

chk "README exists"            "test -f $D/README.md"
chk "README lists six skills"  "test \$(grep -c 'phpbb-data\|phpbb-formatting\|phpbb-extensions\|phpbb-styles\|phpbb-admin' $D/README.md) -ge 5"
chk "README explains install"  "grep -qi 'symlink\|~/.claude/skills\|.claude/skills' $D/README.md"
chk "six SKILL.md present"     "test \$(find $D -maxdepth 2 -name SKILL.md | wc -l) -eq 6"
# each SKILL.md must declare a name equal to its directory name
: > /tmp/name-mismatch.txt
for f in $(find "$D" -maxdepth 2 -name SKILL.md); do
	dir=$(basename "$(dirname "$f")")
	grep -q "^name: $dir\$" "$f" || echo "$f" >> /tmp/name-mismatch.txt
done
chk "every name matches dir"   "test ! -s /tmp/name-mismatch.txt"
desc_ok=$(grep -l '^description: Use when' $(find "$D" -maxdepth 2 -name SKILL.md) 2>/dev/null | wc -l)
chk "every description is Use when" "test $desc_ok -eq 6"
chk "no SKILL.md over 250 lines" "! find $D -maxdepth 2 -name SKILL.md -exec wc -l {} + | awk '\$1 >= 250 && \$2 != \"total\"' | grep -q ."
chk "reference tree only in hub+scripts" "test \$(grep -rl '/src/phpbb/phpBB3' $D --include='*.md' --include='*.sh' --include='*.py' | grep -v docs/superpowers | wc -l) -le 4"
chk "no TBD or TODO"           "! grep -rn 'TBD\|TODO\|FIXME' $D --include='*.md' | grep -v docs/superpowers | grep -q ."
chk "scripts still pass"       "bash /tmp/verify-task1.sh"
exit $fail
```

- [ ] **Step 2: Run it to make sure it fails**

Run: `bash /tmp/verify-task8.sh`
Expected: `FAIL README exists`; the rest should already be `ok` if Tasks 1-7
are done. Exit 1.

- [ ] **Step 3: Write `README.md`**

Content: what the repository is (a family of six Claude Code skills for
phpBB 3.3), a table of the six skills with their one-line descriptions copied
from their frontmatter, the three helper scripts and what each prints, how to
install (symlink each skill directory into `~/.claude/skills/`, or copy into a
project's `.claude/skills/`; show the symlink loop), the portability note (the
skills detect the current project's phpBB root and fall back to a reference
tree), and a pointer to `docs/superpowers/specs/` and `docs/superpowers/plans/`.

Show the install command concretely:

```bash
for d in phpbb phpbb-data phpbb-formatting phpbb-extensions phpbb-styles phpbb-admin; do
	ln -sfn "$PWD/$d" ~/.claude/skills/"$d"
done
```

- [ ] **Step 4: Run the verification to make sure it passes**

Run: `bash /tmp/verify-task8.sh`
Expected: 10 lines all `ok`, exit 0.

Then run every task's verification once more in one go:

Run: `for i in 1 2 3 4 5 6 7 8; do echo "--- task $i"; bash /tmp/verify-task$i.sh; done`
Expected: no `FAIL` line anywhere.

- [ ] **Step 5: Commit**

```bash
cd /src/phpbb/skills
git add README.md
git commit -m "$(printf '%s\n' \
  'Add repository README' '' \
  'Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>' \
  'Claude-Session: https://claude.ai/code/session_01JDw9d4GQqPiJDdVKnAdJtw')"
```
