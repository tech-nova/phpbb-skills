# Reparsing stored content

Formatting rules are applied **at parse time**. Changing a rule does not change
what is already in the database. Reparsing re-runs the current parser over
stored text and rewrites it.

Implementation: `phpbb/textreparser/`. Plugins are registered in
`config/default/container/services_text_reparser.yml` with the
`text_reparser.plugin` tag and collected by `text_reparser.manager`.

## When you must reparse

| Change | Reparse needed |
|---|---|
| Added, edited or removed a custom BBCode | **yes** |
| Changed a smiley code | **yes** |
| Turned magic URLs on or off board-wide | **yes** |
| Changed `allow_post_links` or link handling | **yes** |
| Upgraded from phpBB 3.0/3.1 to 3.2+ | **yes** (the installer does it) |
| Changed the censor word list | no — censoring is applied at render time |
| Changed a signature or attachment setting | no — render time |
| Changed `bbcode_tpl` only (same tag, new HTML) | usually no — but purge the cache |

The distinction is the parse-time / render-time split in
[pipeline-elements.md](pipeline-elements.md).

**Purge the cache first**, or you reparse with the old compiled rules:

```
php bin/phpbbcli.php cache:purge
```

## Listing the reparsers

```
php bin/phpbbcli.php reparser:list
```

The nine shipped plugins, as declared in `services_text_reparser.yml`:

| Reparser | Reprocesses |
|---|---|
| `text_reparser.post_text` | `phpbb_posts.post_text` — the big one |
| `text_reparser.pm_text` | `phpbb_privmsgs.message_text` |
| `text_reparser.user_signature` | `phpbb_users.user_sig` |
| `text_reparser.forum_description` | `phpbb_forums.forum_desc` |
| `text_reparser.forum_rules` | `phpbb_forums.forum_rules` |
| `text_reparser.group_description` | `phpbb_groups.group_desc` |
| `text_reparser.poll_option` | `phpbb_poll_options.poll_option_text` |
| `text_reparser.poll_title` | poll titles on `phpbb_topics` |
| `text_reparser.contact_admin_info` | the contact-admin message in `phpbb_config_text` |

An extension adds its own by registering a service with the
`text_reparser.plugin` tag.

## Running it

```
php bin/phpbbcli.php reparser:reparse [reparser-name] [options]
```

The argument is optional — omit it to reparse everything.

| Option | Effect |
|---|---|
| `--dry-run` | do not save; print what would happen |
| `--force-bbcode-reparsing` | reparse **all** BBCodes without exception. Note: previously disabled BBCodes get reprocessed, enabled and fully rendered |
| `--resume` | start where the last run stopped |
| `--range-min=N` | lowest record id to process (default `1`) |
| `--range-max=N` | highest record id to process |
| `--range-size=N` | approximate records per batch (default `100`) |

Verified against `phpbb/console/command/reparser/reparse.php` and
`language/en/cli.php`.

## Doing it safely on a live board

Reparsing `post_text` rewrites every post row. On a large board it is long and
irreversible.

1. **Back up the database first.** There is no undo.
2. **Dry-run** on a slice to see what changes:
   ```
   php bin/phpbbcli.php reparser:reparse post_text --dry-run --range-min=1 --range-max=1000
   ```
3. **Run in ranges** rather than all at once, so a failure does not leave you
   guessing how far it got:
   ```
   php bin/phpbbcli.php reparser:reparse post_text --range-min=1 --range-max=50000
   ```
4. **Use `--resume`** for the remainder — the manager records progress, and
   `text_reparser.lock` prevents two runs colliding.
5. Increase `--range-size` for speed on a healthy server, decrease it if you hit
   memory limits.

**Be careful with `--force-bbcode-reparsing`.** Its documented behaviour is to
reprocess *every* BBCode, which re-enables and renders BBCodes that were
deliberately disabled in individual posts. Use it only when that is what you
want — for instance after re-enabling a BBCode board-wide — not as a
general "make it work" flag.

There is also an ACP counterpart under *Maintenance → Database → Reparse
BBCode*, which drives the same plugins in the browser. The CLI is better for
anything large.
