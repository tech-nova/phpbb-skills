---
name: phpbb-admin
description: Use when installing, updating or operating a phpBB 3.3 forum - running bin/phpbbcli.php commands, purging the cache, configuring cron, managing permissions and roles in the ACP, reindexing search, handling attachments and thumbnails, editing config.php, or troubleshooting a board.
---

# Operating a phpBB 3.3 board

## The four entry points

| | |
|---|---|
| **ACP** — `adm/index.php` | everything a board admin does day to day. The path is `$phpbb_adm_relative_path` in `config.php` and is often renamed. |
| **CLI** — `bin/phpbbcli.php` | 29 commands. The right tool for anything scripted, large or done while the board is broken. |
| **`config.php`** | database credentials, table prefix, cache driver, environment. |
| **`cache/`** | disposable, but stale contents are the cause of most "my change did nothing" reports. |

Confirm what you are working on before doing anything:

```
../phpbb/scripts/phpbb-root.sh
```

It prints the root, `PHPBB_VERSION` and the table prefix.

## Five things that fix most problems

1. **Purge the cache.** `php bin/phpbbcli.php cache:purge` — after any change to
   templates, CSS, language files, services, BBCodes, smilies or extension code.
2. **Boot without extensions.** `php bin/phpbbcli.php --safe-mode extension:show`
   — the way back in when an extension breaks the board.
3. **Run pending migrations.** `php bin/phpbbcli.php db:migrate` — after
   replacing files for an update.
4. **Check writability** of `cache/`, `store/`, `files/` and
   `images/avatars/upload/`, and that they are owned by the web server user.
   Wrong ownership here breaks uploads and caching after every migration.
5. **Turn on real errors.** Set `PHPBB_ENVIRONMENT` to `development` in
   `config.php`, reproduce, then set it back. Never leave a public board there.

## Run the CLI as the web server user

```
sudo -u www-data php bin/phpbbcli.php cache:purge
```

Running it as root leaves files in `cache/` and `store/` that the web server
cannot read, which breaks the board in a way that looks unrelated.

## The two references

| Topic | File |
|---|---|
| All 29 CLI commands with their real arguments and options | [references/cli.md](references/cli.md) |
| `config.php`, environments, cache, cron, permissions, search, attachments, install and update, web server config, backups, troubleshooting | [references/operations.md](references/operations.md) |

## Destructive commands

These are not reversible. Back up the database first:

| Command | Destroys |
|---|---|
| `extension:purge` | the extension's data and schema |
| `db:revert` | that migration **and everything depending on it** |
| `reparser:reparse` | rewrites stored post text in place |
| `user:delete --delete-posts` | the user's posts, and adjusts every counter |

A complete backup is the database **plus** `files/`, `images/`, `store/`,
`config.php`, `ext/` and `styles/`. A database-only dump loses every attachment
and avatar — see [operations.md](references/operations.md).
