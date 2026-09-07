---
name: phpbb-data
description: Use when working with phpBB 3.3 data - reading or writing the schema, understanding tables like phpbb_posts, phpbb_topics, phpbb_forums, phpbb_users or the phpbb_acl_* permission tables, writing SQL or DBAL queries, or interpreting counters, visibility flags and forum tree ids.
---

# phpBB 3.3 data model

69 tables. This skill covers what they hold, how they relate, the places where
a naive query gives a wrong answer, and how to query through phpBB's database
abstraction layer.

## Inspect before you write

```
../phpbb/scripts/table-schema.py <table>
```

Accepts the name with or without the `phpbb_` prefix. Prints columns, phpBB
types, defaults, primary key and indexes, straight from
`install/schemas/schema.json`.

**Never recall a column name from memory — read it.** Several tables are large
(`phpbb_users` has 69 columns, `phpbb_forums` 50, `phpbb_topics` 38) and column
names are not always what you would guess.

**The table prefix is configurable.** `phpbb_` is only the default, chosen at
install time and stored as `$table_prefix` in `config.php`. In extension or
core code, never write a table name literally: use the injected parameter
(`%tables.posts%` and friends, declared in
`config/default/container/tables.yml`) or the constants from
`includes/constants.php`.

## The eight domains

| Domain | Tables | What to know |
|---|---|---|
| **Content** | forums, topics, posts, attachments, poll_options, poll_votes, icons, drafts | The core hierarchy. `forums` is a nested set, `topics` and `posts` carry visibility flags and denormalised counters. |
| **Users & auth** | users, groups, user_group, ranks, profile_fields*, oauth_*, banlist, disallow, warnings, zebra, login_attempts, bots | `users.user_permissions` is a **cache**, not source data. |
| **Permissions** | acl_options, acl_roles, acl_roles_data, acl_groups, acl_users, moderator_cache, teampage | Effective permissions are computed from these and cached per user. |
| **Tracking** | topics_track, forums_track, topics_posted, bookmarks, topics_watch, forums_watch, forums_access | Read/unread state. Partly cookie-based for guests. |
| **Sessions** | sessions, sessions_keys, confirm | |
| **Messaging** | privmsgs, privmsgs_to, privmsgs_folder, privmsgs_rules, notifications, notification_types, notification_emails, user_notifications | A PM's body lives in `privmsgs`; delivery state in `privmsgs_to`. |
| **Search** | search_wordlist, search_wordmatch, search_results, words | Owned by the search backend; `words` is the censor list, unrelated to search. |
| **System** | config, config_text, ext, extensions, extension_groups, migrations, modules, styles, lang, log, sitelist, smilies, bbcodes, reports, reports_reasons | `config` holds scalars, `config_text` holds long values. |

Full table-by-table detail: **[references/tables.md](references/tables.md)**.

## Read this before writing a query

Four things make naive SQL silently wrong. Each is explained in
**[references/pitfalls.md](references/pitfalls.md)**:

1. **`phpbb_forums` is a nested set.** `left_id`/`right_id` encode the tree.
   Never renumber them by hand.
2. **Posts and topics are soft-deleted and moderated**, not removed.
   `post_visibility`/`topic_visibility` must be filtered or your counts include
   unapproved and deleted content.
3. **Counters are denormalised.** `topic_posts_approved`, `forum_posts_approved`,
   `user_posts` are maintained by application code, not by triggers.
4. **`users.user_permissions` is a cache** built from the `acl_*` tables.
   Writing ACL rows without invalidating it changes nothing.

## Querying

phpBB supports MySQL, PostgreSQL, SQLite, MS SQL and Oracle behind one
interface. Use it. **[references/dbal.md](references/dbal.md)** documents
`$db` (`\phpbb\db\driver\driver_interface`) with real signatures.

The two rules that matter most:

- **Never interpolate a variable into SQL.** Use `sql_escape()`,
  `sql_in_set()`, `sql_build_array()`.
- **Never use `LIMIT` directly.** Write `sql_query_limit($sql, $total, $offset)`
  — `LIMIT` syntax differs across the supported engines.

## Changing the schema

Not with raw DDL. Schema changes belong in an extension migration, which is
covered by the **phpbb-extensions** skill. The migrator records what ran in
`phpbb_migrations`; hand-applied DDL desynchronises it and breaks later updates.
