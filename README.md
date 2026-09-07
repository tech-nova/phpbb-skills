# phpBB skills

A family of six Claude Code skills for working on **phpBB 3.3** forums:
the data model, the text-formatting pipeline, extensions, styles and operations.

Written against phpBB **3.3.17**. Every factual claim in them — event names,
method signatures, column names, service ids, CLI commands — was verified
against a real phpBB tree rather than recalled, and the skills tell the agent
to do the same.

## The skills

| Skill | Use it when |
|---|---|
| **[phpbb](phpbb/)** | Orienting in a phpBB codebase, locating the root and version, mapping the tree, or deciding which of the others applies. Owns the helper scripts. |
| **[phpbb-data](phpbb-data/)** | Reading or writing the schema; the 69 tables; SQL and DBAL queries; counters, visibility flags and forum tree ids. |
| **[phpbb-formatting](phpbb-formatting/)** | Reading, rendering, extracting or transforming post text: BBCode, smilies, attachments, magic URLs, censoring, signatures, `bbcode_uid`/`bbcode_bitfield`, bulk reparsing. |
| **[phpbb-extensions](phpbb-extensions/)** | Building anything under `ext/`: `composer.json`, `ext.php`, services, event listeners, migrations, ACP/UCP/MCP modules, cron tasks. |
| **[phpbb-styles](phpbb-styles/)** | Customising the look: styles and inheritance, prosilver, phpBB's Twig dialect, CSS order, responsive and RTL, override versus event. |
| **[phpbb-admin](phpbb-admin/)** | Installing, updating and operating a board: the 29 CLI commands, cache, cron, permissions, search, attachments, `config.php`, troubleshooting. |

Each is a short `SKILL.md` router plus `references/*.md` loaded on demand.

## Helper scripts

In `phpbb/scripts/`. Each takes an optional phpBB root and otherwise detects
one, so they work from anywhere inside a forum.

| Script | Prints |
|---|---|
| `phpbb-root.sh [start_dir]` | `root=`, `version=`, `prefix=` — the phpBB root, its `PHPBB_VERSION`, and the table prefix from `config.php` |
| `find-event.sh <pattern> [root]` | matching events from **both** catalogues: template events from `docs/events.md`, PHP events from the `@event` docblocks in the source, with their `@var` contract and call site |
| `table-schema.py <table> [--root PATH]` | one table's columns, types, defaults, primary key and indexes, from `install/schemas/schema.json`. Name works with or without the `phpbb_` prefix. |

`find-event.sh` exists because the two event catalogues live in different
places — `docs/events.md` holds **template events only**, and searching it for a
`core.*` name finds nothing. That confusion is the most common phpBB
extension bug.

```console
$ phpbb/scripts/phpbb-root.sh
root=/path/to/phpBB3
version=3.3.17
prefix=phpbb_
```

## Installing

Symlink each skill into your user skills directory:

```bash
for d in phpbb phpbb-data phpbb-formatting phpbb-extensions phpbb-styles phpbb-admin; do
	ln -sfn "$PWD/$d" ~/.claude/skills/"$d"
done
```

Or copy them into a project's `.claude/skills/` to scope them to one repository.

There is no `.claude-plugin/plugin.json` — these are raw skill directories.

## Portability

The skills do not assume a fixed location. Each one resolves the phpBB root of
the current project first: a directory holding both `common.php` and
`includes/constants.php`, from which `PHPBB_VERSION` and the table prefix are
read.

When no project root is found, they fall back to a **reference tree** — a
phpBB 3.3.17 checkout used read-only to look things up. The default path is
`/src/phpbb/phpBB3`, set in `phpbb/SKILL.md` and in the three scripts; change it
there if your checkout lives elsewhere.

## Repository

```
phpbb/                  hub + scripts/
phpbb-data/             SKILL.md + references/{tables,pitfalls,dbal}.md
phpbb-formatting/       SKILL.md + references/{pipeline,pipeline-elements,custom-bbcodes,reparser}.md
phpbb-extensions/       SKILL.md + references/{anatomy,events,migrations,modules}.md
phpbb-styles/           SKILL.md + references/{inheritance,twig,css}.md
phpbb-admin/            SKILL.md + references/{cli,operations}.md
docs/superpowers/
	specs/              the design these were built from
	plans/              the implementation plan, with its verification scripts
```

## License

The skills document phpBB, which is GPL-2.0. phpBB is a registered trademark of
phpBB Limited; this repository is not affiliated with it.
