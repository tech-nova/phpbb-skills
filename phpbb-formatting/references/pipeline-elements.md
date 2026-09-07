# The other pipeline elements

BBCode is one of five things the formatter handles. Each has its own storage,
its own toggle and its own failure mode.

---

## Smilies

**Stored in** `phpbb_smilies`: `smiley_id`, `code` (what the user types, e.g.
`:D`), `emotion` (the alt text), `smiley_url` (file under
`images/smilies/`), `smiley_width`, `smiley_height`, `smiley_order`,
`display_on_posting` (whether it shows in the posting page's smiley box).

Several rows may share one `smiley_url` — that is how `:D` and `:grin:` map to
the same image.

**Toggle**: `posts.enable_smilies` per post, `OPTION_FLAG_SMILIES` (2) in the
packed flags, `viewsmilies` in the user's options.

**Rendering**: the renderer needs to know where the images live.

```php
$renderer->set_smilies_path($path);
```

In a request this is done for you — `services_text_formatter.yml` wires
`configure_smilies_path` with `@config` and `@path_helper`. **In a CLI script
or a feed you must set it yourself**, or every smiley renders with a broken
relative URL.

`smiley_text($text, $force_option = false)` in
`includes/functions_content.php:1099` rewrites smiley `<img>` paths in already
rendered output — used when the same HTML is served from different depths.

**After changing a smiley code**: purge the cache (the compiled parser is
cached) and reparse, or existing posts keep the old code as plain text.

---

## Attachments

Attachments are **not** stored in the text. The text carries a marker and the
file lives in `phpbb_attachments` + the `files/` directory.

**In the text**: `[attachment=0]filename.png[/attachment]`, where the number is
the index into the post's attachment list — **not** an `attach_id`.

**Stored in** `phpbb_attachments`:

| Column | Meaning |
|---|---|
| `attach_id` | primary key |
| `post_msg_id` | **a `post_id` or a `msg_id`** — disambiguated by `in_message` |
| `in_message` | 0 = attached to a post, 1 = attached to a PM |
| `topic_id`, `poster_id` | context |
| `is_orphan` | uploaded but the post was never submitted; cleaned up by cron |
| `physical_filename` | the name on disk under `files/` — random, not the user's name |
| `real_filename` | what the user sees |
| `extension`, `mimetype`, `filesize`, `filetime` | metadata |
| `download_count` | counter |
| `attach_comment` | user caption |
| `thumbnail` | 1 if a thumbnail was generated |

`posts.post_attachment` / `privmsgs.message_attachment` is a denormalised flag
saying "this row has attachments" — used to avoid a join on listing pages.

**Rendering**:

```php
parse_attachments($forum_id, &$message, &$attachments, &$update_count_ary, $preview = false)
```
`includes/functions_content.php:1133`

It replaces the markers in `$message` (already rendered HTML) with the
attachment templates, and records which download counters to bump in
`$update_count_ary`. Call it **after** `generate_text_for_display()`, not
before.

**Which extensions are allowed** is `phpbb_extension_groups` +
`phpbb_extensions` — nothing to do with `phpbb_ext`, which holds board
extensions.

**Never move or rename files under `files/` directly**: `physical_filename` is
the only link back, and the directory is intentionally not web-browsable.

---

## Magic URLs

Bare URLs typed in a post become links automatically.

**Toggle**: `posts.enable_magic_url` per post, `OPTION_FLAG_LINKS` (4) in the
packed flags. Note the constant is `LINKS`, not `URL` — a common slip.

**Implementation**: `phpbb/textformatter/s9e/link_helper.php`, wired as
`text_formatter.s9e.link_helper` into the factory. It handles truncating long
URLs for display, keeping the full target in the `href`, and marking local
links so they do not get an external-link treatment.

`config['allow_post_links']` gates links entirely; `config['force_server_vars']`
and the board URL affect how local links are recognised.

Magic URLs are applied **at parse time**, not at render time. Turning the
feature on does not linkify existing posts — that needs a reparse.

---

## Word censoring

**Stored in** `phpbb_words`: `word_id`, `word` (may contain `*` wildcards),
`replacement`. Nothing to do with `phpbb_search_wordlist`.

**Applied at render time**, so it is reversible and always current — changing
the censor list affects old posts immediately for rendering. (The compiled
renderer is cached, so purge the cache.)

Three things decide whether a given viewer sees censored text:

1. `config['allow_nocensors']` — is opting out permitted at all
2. the `u_chgcensors` permission — may this user opt out
3. `$user->optionget('viewcensors')` — has this user opted out

`generate_text_for_display()` resolves all three. If you call the renderer
directly you must decide yourself:

```php
$renderer->set_viewcensors(true);
```

`censor_text($text)` in `includes/functions_content.php:1051` censors a plain
string (a topic title, a username in a log entry) — not stored post text.

---

## Signatures

Stored on the user row with the same triple as a post:

- `users.user_sig` — the formatted text
- `users.user_sig_bbcode_uid`
- `users.user_sig_bbcode_bitfield`

**Toggle**: `posts.enable_sig` per post decides whether the signature is
appended when that post is displayed; `config['allow_sig']` and the
`u_sig` permission gate having one at all.

Signatures are rendered separately from the post body — the post's own
`enable_bbcode` does not apply to them. `config['allow_sig_bbcode']`,
`allow_sig_img`, `allow_sig_links`, `allow_sig_smilies` and
`max_sig_chars` control what a signature may contain.

The reparser plugin for signatures is `text_reparser.user_signature`.

---

## What each toggle actually controls

| Column | Constant | Applies at | Change affects old content? |
|---|---|---|---|
| `enable_bbcode` | `OPTION_FLAG_BBCODE` (1) | parse time | no — reparse |
| `enable_smilies` | `OPTION_FLAG_SMILIES` (2) | parse time | no — reparse |
| `enable_magic_url` | `OPTION_FLAG_LINKS` (4) | parse time | no — reparse |
| `enable_sig` | — | render time | yes |
| censoring | — | render time | yes (purge cache) |
| attachments | — | render time | yes |

The parse-time/render-time split is the thing to keep straight: it is exactly
what decides whether you need [reparser.md](reparser.md).
