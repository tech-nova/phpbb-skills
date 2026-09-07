---
name: phpbb-formatting
description: Use when reading, rendering, extracting or transforming phpBB post and message text - BBCode, smilies, attachments, magic URLs, word censoring, signatures, bbcode_uid and bbcode_bitfield, the s9e/TextFormatter services, or bulk reparsing with reparser:reparse.
---

# phpBB 3.3 text formatting

## The one thing to know first

**What is stored in `post_text` is neither the BBCode the user typed nor the
HTML the reader sees.** It is an intermediate representation, and phpBB 3.3
has two of them in the same column:

| Form | Looks like | Written by |
|---|---|---|
| **s9e XML** (3.2+) | starts with `<r ` or `<t ` — e.g. `<r><B><s>[b]</s>hi<e>[/b]</e></B></r>` | every post since the 3.2 upgrade |
| **Legacy uid** (3.0) | `[b:2xk4j1qa]hi[/b:2xk4j1qa]`, keyed by `bbcode_uid` | posts predating the upgrade, still present |

Core decides between them with `preg_match('#^<[rt][ >]#', $text)` in
`generate_text_for_display()`. Both live in the same table at the same time.

Consequences:

- **Reading `post_text` directly gives you markup, not content.**
- **Writing `post_text` with a raw `INSERT`/`UPDATE` produces a broken post** —
  it renders as literal `[b]` tags, or as nothing at all.
- Any transformation must go through the parser/renderer, never through
  `str_replace` on the stored value.

The same applies to every other formatted field: `privmsgs.message_text`,
`users.user_sig`, `forums.forum_desc`, `forums.forum_rules`,
`groups.group_desc`, `poll_options.poll_option_text`, `topics.topic_title`'s
poll title, and `reports.reported_post_text`. Each carries its own
`*_uid` / `*_bitfield` / `*_options` companions.

## The storage quadruple

For a post:

| Column | Holds |
|---|---|
| `post_text` | the intermediate representation above |
| `bbcode_uid` (VCHAR:8) | the per-post key used by the legacy form; empty for s9e rows |
| `bbcode_bitfield` (VCHAR:255) | which BBCodes appear, for the legacy second-pass renderer |
| `enable_bbcode`, `enable_smilies`, `enable_magic_url`, `enable_sig` | per-post toggles |

The legacy API packs the three toggles into an integer `$flags` built from
`includes/constants.php`:

```php
define('OPTION_FLAG_BBCODE',  1);
define('OPTION_FLAG_SMILIES', 2);
define('OPTION_FLAG_LINKS',   4);
```

Other tables store the same integer directly, e.g. `forums.forum_desc_options`
(default `7` = all three on).

## Decision tree

**I want to display it** → `generate_text_for_display()`, or the
`text_formatter.renderer` service. → [pipeline.md](references/pipeline.md)

**I want to put it in a textarea for editing** → `generate_text_for_edit()`.
It returns the text as the user originally typed it. →
[pipeline.md](references/pipeline.md)

**I want to store new text** → `generate_text_for_storage()` for the four
values, or `submit_post()` for the whole job (counters, search index,
notifications, tracking). → [pipeline.md](references/pipeline.md)

**I want plain text out of it** (export, search, excerpt, diff) →
`text_formatter.utils`: `clean_formatting()`, `remove_bbcode()`, `unparse()`.
→ [pipeline.md](references/pipeline.md)

**I want to change smilies, attachments, links, censoring** →
[pipeline-elements.md](references/pipeline-elements.md)

**I want a new BBCode** →
[custom-bbcodes.md](references/custom-bbcodes.md)

**I changed formatting rules and existing content must follow** →
`reparser:reparse`. → [reparser.md](references/reparser.md)

## The services

Declared in `config/default/container/services_text_formatter.yml`. The three
public aliases:

| Service | Class | For |
|---|---|---|
| `text_formatter.parser` | `phpbb\textformatter\s9e\parser` | plain text → stored form |
| `text_formatter.renderer` | `phpbb\textformatter\s9e\renderer` | stored form → HTML |
| `text_formatter.utils` | `phpbb\textformatter\s9e\utils` | manipulate stored form without rendering |

Supporting services: `text_formatter.s9e.factory` (builds and caches the
configured parser/renderer from `phpbb_bbcodes`, `phpbb_smilies`,
`phpbb_words`, `phpbb_styles`), `text_formatter.s9e.bbcode_merger`,
`text_formatter.s9e.link_helper`, `text_formatter.s9e.quote_helper`,
`text_formatter.acp_utils`, `text_formatter.data_access`.

The factory caches the compiled parser and renderer. **After changing a BBCode,
a smiley or the censor list, purge the cache**
(`php bin/phpbbcli.php cache:purge`) — otherwise the old rules keep applying.

## Rules

- Never `str_replace` on stored text. Use `text_formatter.utils`.
- Never build the four stored values by hand. Use
  `generate_text_for_storage()`.
- Changing a formatting rule does **not** change existing content. Reparse.
- Purge the cache after any BBCode, smiley or censor change.
