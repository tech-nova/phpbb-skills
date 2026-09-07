# phpBB Skills Family — Design

Date: 2026-09-07
Status: approved

## Goal

A family of Claude Code skills that let an agent work competently on phpBB 3.3:
understand the data model, use the BBCode / text-formatting pipeline correctly,
develop extensions, customise styles, and operate a forum.

Skill content is written in **English** (phpBB's own vocabulary: event names,
table names, API signatures, coding guidelines). Conversation with the user
stays in French.

## Repository layout

The repository at `/src/phpbb/skills` (git, branch `materio`, no remote) holds
the skill directories at its root, so each one can be symlinked into
`~/.claude/skills/` or copied into a project's `.claude/skills/`.

```
/src/phpbb/skills/
  README.md
  docs/superpowers/specs/            this document
  phpbb/                             hub
    SKILL.md
    scripts/
      phpbb-root.sh
      find-event.sh
      table-schema.py
  phpbb-data/
    SKILL.md
    references/{tables.md,pitfalls.md,dbal.md}
  phpbb-formatting/
    SKILL.md
    references/{pipeline.md,pipeline-elements.md,custom-bbcodes.md,reparser.md}
  phpbb-extensions/
    SKILL.md
    references/{anatomy.md,events.md,migrations.md,modules.md}
  phpbb-styles/
    SKILL.md
    references/{inheritance.md,twig.md,css.md}
  phpbb-admin/
    SKILL.md
    references/{cli.md,operations.md}
```

No `.claude-plugin/plugin.json`: the repository ships raw skills plus a README
explaining installation. (Decision: packaging as an installable plugin was
considered and declined.)

## Skill roster and boundaries

| Skill | Triggers on | Owns |
|---|---|---|
| `phpbb` | any phpBB question with no clear domain | locating the phpBB root and version, tree map, core conventions, authoritative sources, routing to the other five |
| `phpbb-data` | schema, tables, SQL, queries | the 69 tables, relationships, structural pitfalls, DBAL usage |
| `phpbb-formatting` | BBCode, smilies, attachments, censoring, rendering or extracting post text | the s9e/TextFormatter pipeline end to end |
| `phpbb-extensions` | `ext/`, listeners, migrations, services, ACP/UCP/MCP modules | extension anatomy, PHP and template events, migrations, modules |
| `phpbb-styles` | templates, Twig, CSS, prosilver, styles | inheritance, template resolution, phpBB's Twig dialect, CSS order, RTL, responsive |
| `phpbb-admin` | CLI, cache, cron, install, permissions, search | running a forum |

`phpbb-formatting` is separate from `phpbb-data` on purpose: the storage
quadruple (`post_text`, `bbcode_uid`, `bbcode_bitfield`, `post_options`) is the
single largest source of error when manipulating content, and it needs its own
trigger.

## Portability

Every skill resolves the phpBB root of the current project first: a directory
containing both `common.php` and `includes/constants.php`, from which
`PHPBB_VERSION` and the table prefix (`config.php`) are read. Failing that, the
skill names `/src/phpbb/phpBB3` (phpBB 3.3.17) as a reference tree to read.
No other absolute path appears in skill content.

## Cross-cutting rule

Each skill states it explicitly: **never recall an event name, method signature
or column name from memory — read it in the tree.** Authoritative sources, cited
by path:

- `docs/events.md` — 3645 lines, 526 **template** events only. PHP `core.*`
  events are NOT in this file: the ~518 of them are documented in `@event`
  docblocks directly above each `trigger_event()` call site in the source.
- `install/schemas/schema.json` — 69 tables, canonical column definitions
- `ext/phpbb/viglink/` — a complete extension shipped with core (ext.php,
  config/services.yml, config/cron.yml, event listeners, 5 migrations,
  ACP module, language, styles): the worked example for `phpbb-extensions`
- `styles/prosilver/` — 120 templates, the CSS baseline
- `docs/coding-guidelines.html` — phpBB's own conventions
- `phpbb/` — PSR-4 library; `includes/` — legacy procedural functions

Solace (`/src/phpbb/phpbb3-style-solace`) is used as a **case study only** in
`phpbb-styles` — a well-built style that overrides just 3 templates and inherits
the rest from prosilver — not as the project's working style.

## Content outline

### `phpbb` (hub)

`SKILL.md` only. Root/version detection (delegating to `scripts/phpbb-root.sh`),
tree map (`phpbb/` PSR-4 library, `includes/` legacy procedural,
`config/default/container/` DI wiring, `styles/`, `ext/`, `adm/`, `language/`,
`install/`), the "everything goes through an extension or a style, never through
core files" rule, the routing table, and the authoritative-sources list.

### `phpbb-data`

- `references/tables.md` — the 69 tables grouped by domain: content
  (forums, topics, posts, attachments, polls, reports), users and auth
  (users, groups, user_group, ranks, profile fields, oauth, bans),
  ACL (acl_options, acl_roles, acl_roles_data, acl_groups, acl_users,
  moderator_cache), sessions, private messages, search, system
  (config, config_text, ext, migrations, modules, styles, log).
- `references/pitfalls.md` — forums as a nested set (`left_id`/`right_id`),
  post/topic visibility (`post_visibility`, the `content_visibility` service),
  denormalised counters (`topic_posts_approved` vs real counts,
  `forum_posts_approved`, `user_posts`), permission resolution
  (`phpbb_acl_*` → the cached `user_permissions` blob), read tracking
  (`topics_track`, `forums_track`, `topics_posted`), configurable table prefix.
- `references/dbal.md` — `$db->sql_build_query`, `sql_in_set`, `sql_escape`,
  `sql_query_limit`, `sql_multi_insert`, transactions, and why raw PDO is wrong.

### `phpbb-formatting`

`SKILL.md` carries the pipeline overview and a decision tree: *read / edit /
write / bulk-transform*.

- `references/pipeline.md` — storage quadruple; reading with
  `generate_text_for_display()` (`includes/functions_content.php:575`) and the
  `text_formatter.renderer` service; editing with `generate_text_for_edit()`
  (`:777`); writing with `generate_text_for_storage()` (`:694`) or
  `submit_post()`, and why a raw SQL `INSERT` yields unrendered text; extraction
  with `text_formatter.utils` (`clean_formatting`, `remove_bbcode`, `unparse`,
  `generate_quote`).
- `references/pipeline-elements.md` — smilies (`phpbb_smilies`,
  `set_smilies_path`), attachments (`[attachment=n]` ↔ `phpbb_attachments` ↔
  `parse_attachments()`), magic URLs (`phpbb/textformatter/s9e/link_helper.php`),
  word censoring (`phpbb_words`, the `viewcensors` toggle), signatures.
- `references/custom-bbcodes.md` — shorter: `bbcode_match` / `bbcode_tpl`
  syntax, the `phpbb_bbcodes` table, `bbcode_merger`, tokens
  (`{TEXT}`, `{URL}`, `{SIMPLETEXT}`, `{IDENTIFIER}`), adding one via ACP versus
  via an extension migration.
- `references/reparser.md` — `phpbb/textreparser/`, `phpbbcli.php
  reparser:list` and `reparser:reparse` for bulk re-processing after a BBCode or
  smiley change.

### `phpbb-extensions`

- `references/anatomy.md` — full layout modelled on `ext/phpbb/viglink/`:
  `composer.json` (type `phpbb-extension`), `ext.php`, `config/services.yml`,
  `config/routing.yml`, `config/cron.yml`, `event/`, `migrations/`, `language/`,
  `styles/`, `acp/`, `controller/`, `cron/`.
- `references/events.md` — subscribing to PHP events, reading and writing
  `$event['var']`, the `vars` compact/extract mechanism, adding template events
  from an extension, and where each catalogue lives — template events in
  `docs/events.md`, PHP events in `@event` docblocks in the source — using
  `scripts/find-event.sh` rather than loading either wholesale.
- `references/migrations.md` — `depends_on`, `effectively_installed`,
  `update_schema` / `revert_schema`, `update_data` / `revert_data`, and the
  common data operations: config values, ACP modules, permissions.
- `references/modules.md` — ACP/UCP/MCP modules, `*_info.php`, permission
  declaration and checking.

### `phpbb-styles`

- `references/inheritance.md` — `style.cfg`, the `parent` key, template
  resolution order, `styles/all/`, cache invalidation; Solace as a case study.
- `references/twig.md` — phpBB's Twig dialect: `{% EVENT %}`, `{% INCLUDE %}`,
  `{{ lang('KEY') }}`, `INCLUDECSS` / `INCLUDEJS`, `DEFINE`, and the legacy
  `<!-- IF -->` syntax still handled by `phpbb/template/twig/lexer.php`.
- `references/css.md` — the `@import` order of `stylesheet.css` and the role of
  each prosilver file (normalize, base, common, links, content, buttons, cp,
  forms, icons, colours, responsive, bidi, print, tweaks, utilities).
- The template-override versus event-injection trade-off, with the guidance to
  prefer events because they survive upgrades.

### `phpbb-admin`

- `references/cli.md` — the real inventory taken from
  `phpbb/console/command/`: `cache:purge`; `config:get|set|set-atomic|delete|
  increment`; `cron:list|run`; `db:migrate|revert|list`; `dev:migration-tips`;
  `extension:enable|disable|purge|show`; `fixup:fix-left-right-ids|
  update-hashes`; `reparser:list|reparse`; `thumbnail:generate|delete|recreate`;
  `update:check`; `user:add|delete|delete_id|activate|reclean`.
- `references/operations.md` — install and update, `config.php`, cache and
  purging, cron modes, ACP permissions (roles, groups, forum permissions),
  search backends and reindexing, attachments and thumbnails, debug mode, the
  shipped `docs/nginx.sample.conf` / `lighttpd.sample.conf` /
  `sphinx.sample.conf`, backups, troubleshooting.

## Scripts

Under `phpbb/scripts/`, invoked by the skills so that facts get verified in the
tree instead of loaded wholesale into context.

- `phpbb-root.sh` — walks up from a given directory (default: cwd) to find a
  phpBB root, prints its path, `PHPBB_VERSION`, and the table prefix from
  `config.php` when present. Falls back to reporting the reference tree.
- `find-event.sh <pattern>` — searches both event catalogues, because they live
  in different places: template events in `docs/events.md` (name, `Location:` /
  `Locations:`, `Since:`, `Purpose:`) and PHP events in the source, where each
  `@event core.*` docblock carries its `@var` list, `@since` and `@changed`
  lines. Prints matching entries from both. Avoids loading a 99 KB file or
  grepping the whole tree by hand.
- `table-schema.py <table>` — prints columns, types, keys and auto-increment
  for one table from `install/schemas/schema.json`. Accepts names with or
  without the `phpbb_` prefix.

All three take an optional phpBB root argument and default to autodetection.

## Success criteria

- Asking about a phpBB topic triggers exactly one relevant skill; the hub is
  reached only when the domain is ambiguous.
- Each `SKILL.md` stays under ~250 lines; detail lives in `references/`.
- Every factual claim in the skills (event name, signature, column, CLI command)
  is verifiable in the reference tree, and the skills say to verify.
- The skills work unchanged against another phpBB 3.3 checkout.

## Out of scope

- phpBB 4.x / 3.2 and earlier specifics.
- Deep coverage of Solace and Devlom Configurator internals.
- Writing content programmatically as a primary focus (covered, but shorter than
  the read/render/transform path).
- A `.claude-plugin/plugin.json`.
