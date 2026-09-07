# `bin/phpbbcli.php`

29 commands in phpBB 3.3.17. Names, arguments and options below were extracted
from `setName()`, `addArgument()` and `addOption()` in
`phpbb/console/command/`. Re-extract rather than trusting this list on a
different version:

```
php bin/phpbbcli.php list
```

## Requirements

The CLI needs a working `config.php` and a reachable database — it boots the
same container the web front end does. Run it **as the web server user**, or
files it writes into `cache/` become unreadable by the web server. A `sudo -u
www-data php bin/phpbbcli.php …` is the usual form.

## Global options

Handled in `phpbb/console/application.php` and `bin/phpbbcli.php`:

| Option | Effect |
|---|---|
| `--safe-mode` | boot without extensions — the way out when an extension breaks the board |
| `--env=<name>` | choose the container environment (`production`, `development`) |

Plus Symfony's standard `-v` / `-vv` / `-vvv`, `-q`, `-n`, `--help`.

---

## `cache`

| Command | Args / options |
|---|---|
| `cache:purge` | — |

Clears the data cache, compiled templates, the compiled text formatter and the
container. **The first thing to run after changing templates, CSS, language
files, services, BBCodes, smilies or extension code.**

## `config`

| Command | Args | Options |
|---|---|---|
| `config:get` | `key` | `--no-newline` |
| `config:set` | `key` `value` | `--dynamic` / `-d` |
| `config:set-atomic` | `key` `old` `new` | `--dynamic` / `-d` |
| `config:increment` | `key` `increment` | `--dynamic` / `-d` |
| `config:delete` | `key` | — |

Reads and writes `phpbb_config`. Use these rather than SQL — the config array is
cached. `--dynamic` marks the value as excluded from that cache.

`config:set-atomic` only writes if the current value equals `old`; its exit code
tells you whether it applied. That is the safe form in a script.

## `cron`

| Command | Args |
|---|---|
| `cron:list` | — |
| `cron:run` | `name` (optional) |

`cron:list` shows every task and whether it is due. `cron:run` with no argument
runs all due tasks; with a task name, runs that one.

Driving cron from the system scheduler instead of from page views is the right
setup on any busy board — see [operations.md](operations.md).

## `db`

| Command | Args | Options |
|---|---|---|
| `db:list` | — | `--available` / `-u` |
| `db:migrate` | — | — |
| `db:revert` | `name` | — |
| `dev:migration-tips` | — | — |

`db:list` shows installed migrations; `--available` shows those not yet run.
`db:migrate` applies everything pending. `db:revert` takes a migration class
name and reverts it **and everything depending on it** — destructive, back up
first.

`dev:migration-tips` names the current leaf migrations, which is what a new
extension migration's `depends_on()` should point at. See the
**phpbb-extensions** skill.

## `extension`

| Command | Args |
|---|---|
| `extension:show` | — |
| `extension:enable` | `extension-name` |
| `extension:disable` | `extension-name` |
| `extension:purge` | `extension-name` |

`extension-name` is `vendor/package`. `enable` runs the extension's migrations;
`disable` stops it but keeps its data; **`purge` reverts its migrations and
destroys its data.**

`extension:show` is the first diagnostic when the board misbehaves after an
update.

## `reparser`

| Command | Args | Options |
|---|---|---|
| `reparser:list` | — | — |
| `reparser:reparse` | `reparser-name` (optional) | `--dry-run`, `--force-bbcode-reparsing`, `--resume`, `--range-min=N` (default 1), `--range-max=N`, `--range-size=N` (default 100) |

Re-processes stored text with the current formatter configuration. Required
after adding, changing or removing a BBCode or a smiley code. Back up first —
it rewrites content and there is no undo. Full guidance in the
**phpbb-formatting** skill's
[reparser reference](../phpbb-formatting/references/reparser.md).

## `thumbnail`

| Command |
|---|
| `thumbnail:generate` |
| `thumbnail:delete` |
| `thumbnail:recreate` |

Attachment thumbnails. `recreate` is `delete` then `generate` — the fix after
changing the thumbnail size setting.

## `user`

| Command | Args | Options |
|---|---|---|
| `user:add` | — | `--username`, `--password`, `--email`, `--send-email` |
| `user:activate` | `username` | `--deactivate` / `-d`, `--send-email` |
| `user:delete` | `username` | `--delete-posts` |
| `user:delete_id` | `user_ids` | `--delete-posts` |
| `user:reclean` | — | — |

`user:add` prompts interactively for anything not passed as an option — useful
for creating a founder account when locked out.

`user:delete` / `user:delete_id` **keep the user's posts by default**,
reassigning them to the anonymous user. `--delete-posts` removes them, which
also decrements every affected counter.

`user:reclean` regenerates `username_clean` for every user — run it after
changing the username-cleaning rules or a locale.

## `fixup`

| Command |
|---|
| `fixup:fix-left-right-ids` |
| `fixup:update-hashes` |

`fix-left-right-ids` rebuilds the nested-set columns on `phpbb_forums` and
`phpbb_modules`. Run it when forums disappear from the index, nest wrongly, or
show at the wrong level. See the **phpbb-data** skill.

`update-hashes` re-hashes stored passwords to the current algorithm.

## `update`

| Command | Args | Options |
|---|---|---|
| `update:check` | `ext-name` (optional) | `--stability=<s>`, `--cache` / `-c` |

Checks for a phpBB update, or for an extension's update when given
`vendor/package`. `--stability` filters to `stable` or `unstable`.
