# The 69 tables

Canonical source: `install/schemas/schema.json`. Inspect any table with
`../phpbb/scripts/table-schema.py <name>` for its full column list, types,
defaults and indexes. Names below carry the default `phpbb_` prefix; the real
prefix is `$table_prefix` from `config.php`.

Column lists here name the columns that matter for querying, not every column.

---

## Content

### `phpbb_forums` (50 columns)
The forum tree. **A nested set**: `left_id`/`right_id` encode containment,
`parent_id` is a convenience, `forum_parents` a serialised breadcrumb cache.

- Identity: `forum_id`, `forum_name`, `forum_desc` (+ `_uid`/`_bitfield`/`_options`)
- Tree: `parent_id`, `left_id`, `right_id`, `forum_parents`
- Kind: `forum_type` (category / forum / link), `forum_status`, `forum_link`,
  `forum_flags`, `forum_options`, `forum_password`, `forum_style`
- Counters: `forum_posts_approved`, `forum_posts_unapproved`,
  `forum_posts_softdeleted`, `forum_topics_approved`, `forum_topics_unapproved`,
  `forum_topics_softdeleted`
- Last-post cache: `forum_last_post_id`, `forum_last_poster_id`,
  `forum_last_poster_name`, `forum_last_poster_colour`, `forum_last_post_time`,
  `forum_last_post_subject`
- Pruning: `enable_prune`, `prune_next`, `prune_days`, `prune_freq`,
  `prune_viewed`, and the `*_shadow_*` equivalents

### `phpbb_topics` (38 columns)
One row per topic. → `phpbb_forums.forum_id`.

- Identity: `topic_id`, `forum_id`, `topic_title`, `topic_poster`, `topic_time`
- Kind and state: `topic_type` (normal / sticky / announcement / global),
  `topic_status`, `topic_moved_id` (shadow topic pointing at its new home)
- First/last post caches: `topic_first_post_id`, `topic_first_poster_name`,
  `topic_first_poster_colour`, `topic_last_post_id`, `topic_last_poster_id`,
  `topic_last_poster_name`, `topic_last_poster_colour`, `topic_last_post_time`,
  `topic_last_post_subject`, `topic_last_view_time`
- Moderation: `topic_visibility`, `topic_delete_time`, `topic_delete_reason`,
  `topic_delete_user`, `topic_reported`
- Counters: `topic_posts_approved`, `topic_posts_unapproved`,
  `topic_posts_softdeleted`, `topic_views`
- Poll (a poll lives on the topic, options in `phpbb_poll_options`):
  `poll_title`, `poll_start`, `poll_length`, `poll_max_options`,
  `poll_last_vote`, `poll_vote_change`
- Flags: `topic_attachment`, `topic_bumped`, `topic_bumper`, `icon_id`

### `phpbb_posts` (29 columns)
One row per post. → `phpbb_topics.topic_id`, `phpbb_forums.forum_id`,
`phpbb_users.poster_id`.

- Identity: `post_id`, `topic_id`, `forum_id`, `poster_id`, `post_time`,
  `poster_ip`, `post_username` (for guests)
- **Formatted text**: `post_subject`, `post_text`, `bbcode_uid` (VCHAR:8),
  `bbcode_bitfield` (VCHAR:255), and the toggles `enable_bbcode`,
  `enable_smilies`, `enable_magic_url`, `enable_sig`. Never read or write
  `post_text` directly — see the **phpbb-formatting** skill.
- Moderation: `post_visibility`, `post_delete_time`, `post_delete_reason`,
  `post_delete_user`, `post_reported`
- Edits: `post_edit_time`, `post_edit_reason`, `post_edit_user`,
  `post_edit_count`, `post_edit_locked`
- Flags: `post_attachment`, `post_postcount` (whether it counts toward
  `users.user_posts`), `post_checksum`, `icon_id`

### `phpbb_attachments` (15 columns)
→ `post_msg_id` is a **post_id or a msg_id**, disambiguated by `in_message`.

`attach_id`, `post_msg_id`, `topic_id`, `in_message`, `poster_id`,
`is_orphan` (uploaded but never submitted), `physical_filename` (the name on
disk under `files/`), `real_filename` (what the user sees), `extension`,
`mimetype`, `filesize`, `filetime`, `download_count`, `attach_comment`,
`thumbnail`.

### `phpbb_poll_options` / `phpbb_poll_votes`
`poll_options`: `poll_option_id`, `topic_id`, `poll_option_text`,
`poll_option_total`. `poll_votes`: `topic_id`, `poll_option_id`,
`vote_user_id`, `vote_user_ip`.

### `phpbb_icons`
Post icons: `icons_id`, `icons_url`, `icons_width`, `icons_height`,
`icons_alt`, `icons_order`, `display_on_posting`.

### `phpbb_drafts`
Saved unsent posts: `draft_id`, `user_id`, `topic_id`, `forum_id`,
`save_time`, `draft_subject`, `draft_message`.

---

## Users and authentication

### `phpbb_users` (69 columns)
`user_id`, `username`, `username_clean` (lowercased, the one to search on),
`user_email`, `user_password`, `user_type` (normal / inactive / ignore / founder),
`group_id` (the *default* group), `user_regdate`, `user_lastvisit`,
`user_posts`, `user_lang`, `user_style`, `user_timezone`, `user_colour`,
`user_rank`, `user_avatar` (+ `_type`/`_width`/`_height`).

- **`user_permissions` and `user_perm_from` are a permission cache**, not source
  data. See [pitfalls.md](pitfalls.md).
- Signature: `user_sig`, `user_sig_bbcode_uid`, `user_sig_bbcode_bitfield` —
  the same formatted-text triple as posts.
- `user_options` is a bitfield of display preferences.

### `phpbb_groups` (21 columns)
`group_id`, `group_name`, `group_type` (open / request / closed / hidden /
special), `group_desc` (+ `_uid`/`_bitfield`/`_options`), `group_colour`,
`group_rank`, `group_avatar*`, `group_legend`, `group_display`,
`group_founder_manage`, `group_skip_auth`, `group_receive_pm`,
`group_message_limit`, `group_max_recipients`, `group_sig_chars`.

### `phpbb_user_group`
Membership: `group_id`, `user_id`, `group_leader`, `user_pending`. A user
belongs to many groups; `users.group_id` is only the default one.

### `phpbb_ranks`
`rank_id`, `rank_title`, `rank_min` (post count threshold), `rank_special`,
`rank_image`.

### `phpbb_profile_fields` (24 columns) and friends
Custom profile fields. Definition in `profile_fields`
(`field_ident`, `field_type`, validation and display flags); **values in
`phpbb_profile_fields_data`, one column per field named `pf_<field_ident>`** —
the table is altered when a field is created. Translations in
`phpbb_profile_fields_lang` (option labels) and `phpbb_profile_lang`
(field name and explanation per language).

### `phpbb_oauth_accounts` / `phpbb_oauth_states` / `phpbb_oauth_tokens`
External login linkage, keyed by `user_id` + `provider`.

### `phpbb_banlist`
`ban_id`, `ban_userid`, `ban_ip`, `ban_email`, `ban_start`, `ban_end`,
`ban_exclude`, `ban_reason`, `ban_give_reason`. One row bans by user, IP **or**
email depending on which column is set.

### `phpbb_disallow`
Disallowed usernames: `disallow_id`, `disallow_username`.

### `phpbb_warnings`
`warning_id`, `user_id`, `post_id`, `log_id`, `warning_time`. The text lives in
`phpbb_log` via `log_id`.

### `phpbb_zebra`
Friends and foes: `user_id`, `zebra_id`, `friend`, `foe`.

### `phpbb_login_attempts`
Rate limiting: `attempt_ip`, `attempt_browser`, `attempt_forwarded_for`,
`attempt_time`, `user_id`, `username`, `username_clean`.

### `phpbb_bots`
`bot_id`, `bot_active`, `bot_name`, `user_id`, `bot_agent`, `bot_ip`. Each bot
has a real `user_id` row in `phpbb_users`.

---

## Permissions

Effective permissions are **computed** from these tables and cached in
`users.user_permissions`. See [pitfalls.md](pitfalls.md).

### `phpbb_acl_options`
The catalogue of permission names: `auth_option_id`, `auth_option` (e.g.
`f_read`, `m_delete`, `a_board`, `u_sendpm`), `is_global`, `is_local`,
`founder_only`. The `f_`/`m_` prefixes are local (per forum), `a_`/`u_` are
global.

### `phpbb_acl_roles` / `phpbb_acl_roles_data`
Named bundles of permissions. `acl_roles`: `role_id`, `role_name`,
`role_description`, `role_type`, `role_order`. `acl_roles_data`: `role_id`,
`auth_option_id`, `auth_setting`.

### `phpbb_acl_groups` / `phpbb_acl_users`
The assignments. Both: `group_id`/`user_id`, `forum_id` (0 = global),
`auth_option_id`, `auth_role_id`, `auth_setting`. A row sets **either** a
single option **or** a whole role, not both.

`auth_setting`: `0` = NO, `1` = YES, `-1` = NEVER (NEVER wins over YES).

### `phpbb_moderator_cache`
Denormalised list of who moderates what: `forum_id`, `user_id`, `username`,
`group_id`, `group_name`, `display_on_index`. Rebuilt, never edited.

### `phpbb_teampage`
Ordering of groups on the team page: `teampage_id`, `group_id`,
`teampage_name`, `teampage_position`, `teampage_parent`.

---

## Read tracking

### `phpbb_topics_track` / `phpbb_forums_track`
`user_id`, `topic_id`/`forum_id`, `mark_time`. Only written for registered
users, and only above the "mark all read" watermark — absence of a row does
**not** mean unread.

### `phpbb_topics_posted`
`user_id`, `topic_id`, `topic_posted` — powers the "you have posted in this
topic" marker.

### `phpbb_bookmarks`
`topic_id`, `user_id`.

### `phpbb_topics_watch` / `phpbb_forums_watch`
Subscriptions: `topic_id`/`forum_id`, `user_id`, `notify_status`.

### `phpbb_forums_access`
Password-protected forums the session has unlocked: `forum_id`, `user_id`,
`session_id`.

---

## Sessions

### `phpbb_sessions` (13 columns)
`session_id`, `session_user_id`, `session_start`, `session_time`,
`session_last_visit`, `session_ip`, `session_browser`, `session_forwarded_for`,
`session_page`, `session_viewonline`, `session_autologin`, `session_admin`,
`session_forum_id`. Truncating this table logs everyone out; it is otherwise
disposable.

### `phpbb_sessions_keys`
"Remember me" keys: `key_id`, `user_id`, `last_ip`, `last_login`.

### `phpbb_confirm`
CAPTCHA state: `confirm_id`, `session_id`, `confirm_type`, `code`, `seed`,
`attempts`.

---

## Private messages and notifications

### `phpbb_privmsgs` (22 columns)
The message body, one row per message sent: `msg_id`, `root_level` (thread
root), `author_id`, `message_time`, `message_subject`, `message_text`,
`bbcode_uid`, `bbcode_bitfield`, the `enable_*` toggles, `to_address`,
`bcc_address`, `message_attachment`, `message_reported`, `message_edit_*`.
Same formatted-text handling as posts.

### `phpbb_privmsgs_to`
Per-recipient state — this is what a user's inbox reads: `msg_id`, `user_id`,
`author_id`, `folder_id`, `pm_new`, `pm_unread`, `pm_replied`, `pm_marked`,
`pm_forwarded`, `pm_deleted`.

### `phpbb_privmsgs_folder`
User-created folders: `folder_id`, `user_id`, `folder_name`, `pm_count`.

### `phpbb_privmsgs_rules`
Inbox filters: `rule_id`, `user_id`, `rule_check`, `rule_connection`,
`rule_string`, `rule_user_id`, `rule_group_id`, `rule_action`, `rule_folder_id`.

### `phpbb_notifications`
`notification_id`, `notification_type_id`, `item_id`, `item_parent_id`,
`user_id`, `notification_read`, `notification_time`, `notification_data`
(serialised payload).

### `phpbb_notification_types`
`notification_type_id`, `notification_type_name`, `notification_type_enabled`.
Extensions register new types here via a migration.

### `phpbb_user_notifications`
Per-user opt-in: `item_type`, `item_id`, `user_id`, `method` (e.g. board,
email), `notify`.

### `phpbb_notification_emails`
Queue for digest email: `notification_type_id`, `item_id`, `item_parent_id`,
`user_id`.

---

## Search and censoring

### `phpbb_search_wordlist` / `phpbb_search_wordmatch`
The native fulltext index. `wordlist`: `word_id`, `word_text`, `word_common`,
`word_count`. `wordmatch`: `post_id`, `word_id`, `title_match`. Owned by the
search backend — rebuild from the ACP, never edit.

### `phpbb_search_results`
Cached result sets: `search_key`, `search_time`, `search_keywords`,
`search_authors`. Safe to truncate.

### `phpbb_words`
**The censor list, unrelated to search**: `word_id`, `word`, `replacement`.

---

## System

### `phpbb_config` / `phpbb_config_text`
`config`: `config_name`, `config_value`, `is_dynamic` (dynamic values are
excluded from the cached config array). `config_text`: `config_name`,
`config_value` for values too long for `config`. Read and write through the
`config` service or the `config:*` CLI commands, not raw SQL — the cache.

### `phpbb_ext`
Installed extensions: `ext_name` (`vendor/package`), `ext_active`, `ext_state`.

### `phpbb_extensions` / `phpbb_extension_groups`
**Attachment file extensions**, nothing to do with `phpbb_ext`.
`extension_groups`: `group_id`, `group_name`, `cat_id`, `allow_group`,
`download_mode`, `upload_icon`, `max_filesize`, `allowed_forums`, `allow_in_pm`.
`extensions`: `extension_id`, `group_id`, `extension`.

### `phpbb_migrations`
`migration_name`, `migration_depends_on`, `migration_schema_done`,
`migration_data_done`, `migration_data_state`, `migration_start_time`,
`migration_end_time`. The migrator's ledger.

### `phpbb_modules`
ACP/UCP/MCP module tree — **also a nested set** (`left_id`, `right_id`):
`module_id`, `module_enabled`, `module_display`, `module_basename`,
`module_class` (`acp`/`ucp`/`mcp`), `parent_id`, `left_id`, `right_id`,
`module_langname`, `module_mode`, `module_auth`. Managed through migrations'
`module.add` / `module.remove`.

### `phpbb_styles`
`style_id`, `style_name`, `style_copyright`, `style_active`, `style_path`,
`bbcode_bitfield`, `style_parent_id`, `style_parent_tree`.

### `phpbb_lang`
`lang_id`, `lang_iso`, `lang_dir`, `lang_english_name`, `lang_local_name`,
`lang_author`.

### `phpbb_log`
Admin, moderator, user, critical and error logs in one table: `log_id`,
`log_type`, `user_id`, `forum_id`, `topic_id`, `post_id`, `reportee_id`,
`log_ip`, `log_time`, `log_operation` (a language key), `log_data` (serialised
arguments).

### `phpbb_reports` / `phpbb_reports_reasons`
`reports`: `report_id`, `reason_id`, `post_id`, `pm_id`, `user_id`,
`report_time`, `report_text`, `report_closed`, `user_notify`, plus a snapshot
of the reported text (`reported_post_text`, `reported_post_uid`,
`reported_post_bitfield`, `reported_post_enable_*`).
`reports_reasons`: `reason_id`, `reason_title`, `reason_description`,
`reason_order`.

### `phpbb_smilies`
`smiley_id`, `code`, `emotion`, `smiley_url`, `smiley_width`, `smiley_height`,
`smiley_order`, `display_on_posting`.

### `phpbb_bbcodes`
Custom BBCodes: `bbcode_id`, `bbcode_tag`, `bbcode_helpline`,
`display_on_posting`, `bbcode_match`, `bbcode_tpl`, `first_pass_match`,
`first_pass_replace`, `second_pass_match`, `second_pass_replace`. See the
**phpbb-formatting** skill.

### `phpbb_sitelist`
Remote-avatar / referrer allow- or block-list: `site_id`, `site_ip`,
`site_hostname`, `ip_exclude`.
