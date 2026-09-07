---
name: phpbb
description: Use when working on a phpBB 3.3 forum and the specific area is not yet clear - orienting in the codebase, locating the phpBB root and version, mapping the tree, or deciding which phpBB skill applies. Routes to phpbb-data, phpbb-formatting, phpbb-extensions, phpbb-styles and phpbb-admin.
---

# phpBB 3.3

Orientation hub for phpBB work. Locate the forum, read the facts out of it,
then hand off to the skill that owns the area.

## 1. Locate the forum first

Never assume a layout. Run:

```
phpbb/scripts/phpbb-root.sh [start_dir]
```

```
root=/src/phpbb/phpBB3
version=3.3.17
prefix=unknown
```

- A **phpBB root** is a directory holding both `common.php` and
  `includes/constants.php`. The script walks up from `start_dir` (default:
  `$PWD`) looking for that pair.
- **Version** comes from `PHPBB_VERSION` in `includes/constants.php`. These
  skills target 3.3.x. If the number you get is 3.2 or lower, or 4.x, stop and
  say so — the APIs differ.
- **Table prefix** comes from `$table_prefix` in `config.php`. The default is
  `phpbb_`, but it is chosen at install time. `prefix=unknown` means there is
  no installed `config.php` (an uninstalled source tree). Never hardcode
  `phpbb_` in a query you are writing for a live board.

When no project root is found, the script falls back to the reference tree
`/src/phpbb/phpBB3` (phpBB 3.3.17). That tree is a **read-only source of
truth** for looking things up. It is never an edit target.

## 2. The rule: verify, do not recall

phpBB has ~518 PHP events, 526 template events, 69 tables, 29 CLI commands and
a large legacy surface. Recalling any of them from memory is how wrong code
gets written.

**Before writing an event name, a method signature, a column name, a service id
or a CLI command into code or into an answer, read it in the tree.** The three
scripts below exist so that costs a second. When you cannot verify something,
say it is unverified rather than stating it.

## 3. Tree map

| Path | Role |
|---|---|
| `phpbb/` | The PSR-4 library, namespace `\phpbb\`. Modern code lives here: `db/`, `textformatter/`, `template/`, `auth/`, `extension/`, `console/`, `notification/`, `search/`. |
| `includes/` | Legacy procedural functions, still load-bearing. Notably `functions.php`, `functions_content.php`, `functions_posting.php`, `functions_display.php`, `functions_user.php`, `message_parser.php`, `constants.php`. |
| `config/default/container/` | Symfony DI wiring, one `services_*.yml` per subsystem, plus `parameters.yml` and `tables.yml`. This is where service ids are defined. |
| `styles/` | `prosilver` (the default style, ~120 templates) and `all/` (assets and the `template/event/` directory extensions write into). |
| `ext/` | Extensions, in `ext/<vendor>/<package>/` layout. `ext/phpbb/viglink/` ships with core and is a complete worked example. |
| `adm/` | The Administration Control Panel: `adm/style/` templates, `adm/index.php`. |
| `language/` | Language packs, `language/<iso>/*.php`. |
| `install/` | Installer, and `install/schemas/schema.json` — the canonical schema. |
| `docs/` | `events.md`, `coding-guidelines.html`, sample server configs, CHANGELOG. |
| `bin/phpbbcli.php` | The CLI entry point (29 commands). |
| `cache/`, `store/`, `files/` | Writable runtime directories. `files/` holds attachments. |
| `vendor/` | Composer dependencies. Never edit; exclude from every search. |

Root-level `*.php` files (`viewtopic.php`, `posting.php`, `ucp.php`, `mcp.php`,
`memberlist.php`, …) are the page controllers. Most PHP events are triggered
from them.

## 4. Authoritative sources

| What you want | Where to read it |
|---|---|
| **Template events** | `docs/events.md` — 526 entries. **Template events only.** |
| **PHP events** | `@event` docblocks above each `trigger_event()` call in the source. ~518 unique `core.*` names. **These are NOT in `docs/events.md`.** |
| Database schema | `install/schemas/schema.json` (69 tables) |
| A complete extension | `ext/phpbb/viglink/` |
| Style baseline | `styles/prosilver/` (`style.cfg`, `template/`, `theme/`) |
| Service ids and wiring | `config/default/container/services_*.yml` |
| Coding conventions | `docs/coding-guidelines.html` |
| CLI commands | `setName()` in `phpbb/console/command/*/*.php` |

The split between the two event catalogues is the single most common source of
confusion. `find-event.sh` searches both.

## 5. The scripts

All three take an optional phpBB root and otherwise autodetect it.

### `phpbb/scripts/phpbb-root.sh [start_dir]`

Prints `root=`, `version=`, `prefix=`. Exits 1 if no root and no reference tree.

### `phpbb/scripts/find-event.sh <pattern> [phpbb_root]`

Looks a pattern up in **both** catalogues. Template hits come from
`docs/events.md` with their `Locations:`, `Since:` and `Purpose:`; PHP hits come
from the source with the full docblock and the `trigger_event()` call site, so
you see the exact `@var` list a listener can read and write.

```
$ phpbb/scripts/find-event.sh viewtopic_post_row_after
## Template events   (source: docs/events.md)

(no matches)

## PHP events   (source: @event docblocks in the tree)

### core.viewtopic_post_row_after
File: viewtopic.php:2230
	/**
	* Event after the post data has been assigned to the template
	*
	* @event core.viewtopic_post_row_after
	* @var	int		start				Start item of this page
	...
	* @var	array	topic_data			Array with topic data
	* @since 3.1.0-a3
	* @changed 3.1.0-b3 Added topic_data array, total_posts
	*/
	$vars = array('start', ... 'topic_data');
	extract($phpbb_dispatcher->trigger_event('core.viewtopic_post_row_after', compact($vars)));
```

Use a fragment, not a full name, when hunting: `find-event.sh viewtopic_post_row`
returns the whole family.

### `phpbb/scripts/table-schema.py <table> [--root PATH]`

Prints one table's columns, types, defaults, primary key and indexes. The name
works with or without the `phpbb_` prefix.

```
$ phpbb/scripts/table-schema.py styles
TABLE phpbb_styles   (install/schemas/schema.json)

  style_id           UINT           default=NULL       auto_increment
  style_name         VCHAR_UNI:255  default=''
  style_copyright    VCHAR_UNI      default=''
  style_active       BOOL           default=1
  style_path         VCHAR:100      default=''
  bbcode_bitfield    VCHAR:255      default='kNg='
  style_parent_id    UINT:4         default=0
  style_parent_tree  TEXT           default=''

  PRIMARY KEY: style_id
  KEY style_name: ['UNIQUE', 'style_name']
```

Types are phpBB abstractions, not SQL types: `UINT`, `ULINT`, `USINT`, `BOOL`,
`TINT:3`, `VCHAR:40`, `VCHAR_UNI:255`, `STEXT_UNI`, `MTEXT_UNI`, `TIMESTAMP`.
`phpbb/db/tools/` maps them to each supported DBMS.

## 6. Which skill

| Skill | Use it when |
|---|---|
| **phpbb-data** | Reading or writing the schema; understanding `phpbb_posts`, `phpbb_topics`, `phpbb_forums`, `phpbb_users` or the `phpbb_acl_*` tables; writing SQL or DBAL queries; interpreting counters, visibility flags and forum tree ids. |
| **phpbb-formatting** | Reading, rendering, extracting or transforming post and message text: BBCode, smilies, attachments, magic URLs, censoring, signatures, `bbcode_uid`/`bbcode_bitfield`, the s9e/TextFormatter services, bulk reparsing. |
| **phpbb-extensions** | Building or modifying anything under `ext/`: `composer.json`, `ext.php`, `config/services.yml`, event listeners, migrations, ACP/UCP/MCP modules, controllers, cron tasks. |
| **phpbb-styles** | Customising the look: creating or editing a style, overriding prosilver templates, phpBB Twig markup, CSS, responsive and RTL, template override versus template event. |
| **phpbb-admin** | Installing, updating or operating a board: `bin/phpbbcli.php`, cache, cron, ACP permissions, search reindexing, attachments, `config.php`, troubleshooting. |

If the question spans two, start with the one that owns the thing being
*changed*, not the thing being read.

## 7. Core conventions

- **Never patch core files.** Every change goes through an extension (behaviour)
  or a style (appearance). A patched core is silently reverted at the next
  upgrade and breaks the updater.
- **Prefer an event over a template override.** An override freezes a copy of a
  prosilver file that will drift; an event survives upgrades.
- **Purge the cache after changing** templates, CSS, language files, service
  definitions or extension code: `php bin/phpbbcli.php cache:purge`. Most
  "my change did nothing" reports are a stale cache.
- **Schema changes go through a migration**, never raw DDL. The migrator tracks
  what ran in `phpbb_migrations`; hand-applied DDL desynchronises it.
- **Every user-facing string goes through a language file** and `$user->lang()`
  or `{{ lang('KEY') }}`. Hardcoded English breaks ~50 language packs.
- **Never interpolate into SQL.** Use the DBAL's `sql_escape()`, `sql_in_set()`
  and `sql_build_array()`.
