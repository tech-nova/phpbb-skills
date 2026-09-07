# Where naive queries go wrong

Five structural facts. Each one turns an obvious query into a wrong answer.

---

## 1. `phpbb_forums` is a nested set

`left_id` and `right_id` encode the tree, not `parent_id`. A forum's entire
subtree is every row whose `left_id` falls between the parent's `left_id` and
`right_id`.

```sql
-- all descendants of forum 5, in display order
SELECT f2.*
FROM phpbb_forums f1, phpbb_forums f2
WHERE f1.forum_id = 5
  AND f2.left_id BETWEEN f1.left_id AND f1.right_id
ORDER BY f2.left_id ASC
```

`ORDER BY left_id` is the canonical display order. `parent_id` exists for
convenience and `forum_parents` caches a serialised breadcrumb — both are
derived from the nested set, not the other way round.

**Never renumber `left_id`/`right_id` by hand.** Inserting or moving a forum
shifts every id after it. Use the ACP, or `\phpbb\db\tools` / the
`\phpbb\tree\nestedset_forum` service. When the tree gets corrupted (symptoms:
forums missing from the index, wrong nesting, subforums showing at top level):

```
php bin/phpbbcli.php fixup:fix-left-right-ids
```

`phpbb_modules` is a nested set too, with the same rules.

---

## 2. Posts and topics are soft-deleted and moderated, not removed

`post_visibility` and `topic_visibility` hold one of the `ITEM_*` constants
from `includes/constants.php`:

| Constant | Value | Meaning |
|---|---|---|
| `ITEM_UNAPPROVED` | 0 | queued, not yet approved |
| `ITEM_APPROVED` | 1 | visible |
| `ITEM_DELETED` | 2 | soft-deleted |
| `ITEM_REAPPROVE` | 3 | edited, needs re-approval |

A query with no visibility filter counts spam in the moderation queue and posts
users have deleted. Filtering on `= 1` is right for a raw report but wrong for
a rendered page, because moderators are allowed to see more.

**In application code, use the `content_visibility` service** rather than
writing the condition yourself — it takes the viewer's permissions into
account. Real methods (`phpbb/content_visibility.php`):

```php
$phpbb_content_visibility->get_visibility_sql($mode, $forum_id, $table_alias = '')
$phpbb_content_visibility->get_forums_visibility_sql($mode, $forum_ids = array(), $table_alias = '')
$phpbb_content_visibility->get_global_visibility_sql($mode, $exclude_forum_ids = array(), $table_alias = '')
$phpbb_content_visibility->is_visible($mode, $forum_id, $data)
$phpbb_content_visibility->get_count($mode, $data, $forum_id)
$phpbb_content_visibility->can_soft_delete($forum_id, $poster_id, $post_locked)
```

`$mode` is `'post'` or `'topic'`. Changing visibility goes through
`set_post_visibility(...)` / `set_topic_visibility(...)`, which also fix the
counters below — a direct `UPDATE` does not.

Also note `topic_moved_id`: a moved topic leaves a **shadow** row behind
pointing at its new home. Counting rows in `phpbb_topics` without excluding
shadows double-counts.

---

## 3. Counters are denormalised and maintained by application code

There are no triggers. These columns are updated by phpBB when it writes:

- `phpbb_topics`: `topic_posts_approved`, `topic_posts_unapproved`,
  `topic_posts_softdeleted`, `topic_views`
- `phpbb_forums`: `forum_posts_approved`, `forum_posts_unapproved`,
  `forum_posts_softdeleted`, `forum_topics_approved`, `forum_topics_unapproved`,
  `forum_topics_softdeleted`
- `phpbb_users`: `user_posts`
- Last-post caches: `topic_last_post_id`, `topic_last_poster_name`,
  `forum_last_post_id`, `forum_last_poster_colour`, …

Consequences:

- **Reading** a counter is fast and normally correct — prefer it to a `COUNT(*)`.
- **Writing** rows directly desynchronises everything. Any script that inserts,
  deletes or moves posts must go through `submit_post()` /
  `delete_posts()` / the `content_visibility` service, or recalculate
  afterwards from the ACP ("Resynchronise post counts", "Resynchronise
  statistics").
- `post_postcount` on a post decides whether it contributed to
  `users.user_posts`. Posts in forums with post counting disabled have it at 0.

---

## 4. `users.user_permissions` is a cache

Effective permissions are computed from `phpbb_acl_options` +
`phpbb_acl_roles_data` + `phpbb_acl_groups` + `phpbb_acl_users`, then
serialised into `users.user_permissions`, with `users.user_perm_from` recording
whose permissions were borrowed when an admin is browsing as someone else.

Resolution order, per option and per forum:

1. Collect the user's group rows (`acl_groups`, via `phpbb_user_group`) and the
   user's own rows (`acl_users`).
2. A row sets **either** `auth_option_id` **or** `auth_role_id` — a role
   expands to its `acl_roles_data` rows.
3. `auth_setting`: `1` (YES) grants, `0` (NO) is neutral, `-1` (NEVER) denies
   and **overrides every YES**.
4. `forum_id = 0` means global; a per-forum row applies to that forum only.

**Writing `acl_*` rows changes nothing until the cache is invalidated.** In
code, use `$auth->acl_clear_prefetch()` (optionally for one user) after any ACL
write; from the ACP, permissions are cleared automatically. Checking a
permission is `$auth->acl_get('f_read', $forum_id)` — never a manual join.

`phpbb_moderator_cache` is likewise derived, rebuilt by
`cache_moderators()` in `includes/functions_admin.php`.

---

## 5. The table prefix is not `phpbb_`

It is `$table_prefix` in `config.php`, chosen at install. Hardcoding `phpbb_`
works on your board and breaks on the next one.

- In extension code, inject the container parameters declared in
  `config/default/container/tables.yml` (`%tables.posts%`, `%tables.topics%`,
  `%tables.users%`, …) or use the constants from `includes/constants.php`
  (`POSTS_TABLE`, `TOPICS_TABLE`, `USERS_TABLE`, …).
- In an ad-hoc script, read the prefix first:
  `../phpbb/scripts/phpbb-root.sh` prints it.

---

## Bonus: read tracking is not a complete record

`phpbb_topics_track` and `phpbb_forums_track` only hold rows above the user's
"mark all read" watermark (`users.user_lastmark`), and only for registered
users — guests are tracked in a cookie. **The absence of a row does not mean
unread.** Reproducing phpBB's unread logic from SQL alone is a known trap; use
the display helpers in `includes/functions_display.php` instead.
