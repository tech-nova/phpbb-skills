# The formatting pipeline

Entry points are in `includes/functions_content.php` (legacy procedural, still
the normal way) and in the `text_formatter.*` services (modern, injectable).

---

## Reading — displaying stored text

```php
generate_text_for_display($text, $uid, $bitfield, $flags, $censor_text = true)
```
`includes/functions_content.php:575`

Give it the four stored values; get HTML back. It picks the right path for you:
s9e XML rows go through `text_formatter.renderer`, legacy uid rows through
`includes/bbcode.php`. It also honours the viewer's censor preference
(`viewcensors` user option, `allow_nocensors` config, `u_chgcensors`
permission).

```php
$html = generate_text_for_display(
	$row['post_text'],
	$row['bbcode_uid'],
	$row['bbcode_bitfield'],
	($row['enable_bbcode'] ? OPTION_FLAG_BBCODE : 0)
		+ ($row['enable_smilies'] ? OPTION_FLAG_SMILIES : 0)
		+ ($row['enable_magic_url'] ? OPTION_FLAG_LINKS : 0)
);
```

It fires `core.modify_text_for_display_before` and
`core.modify_text_for_display_after` — hook those from an extension rather than
wrapping the call.

### The renderer service directly

`\phpbb\textformatter\renderer_interface`:

```php
public function render($text);
public function set_smilies_path($path);
public function get_viewcensors();
public function set_viewcensors($value);
public function get_viewflash();
public function set_viewflash($value);
public function get_viewimg();
public function set_viewimg($value);
public function get_viewsmilies();
public function set_viewsmilies($value);
```

Use this when you render outside a request context (a CLI export, a feed) and
need to control the four view toggles explicitly. It only handles s9e XML;
legacy rows need `generate_text_for_display()`.

---

## Editing — text back into a textarea

```php
generate_text_for_edit($text, $uid, $flags)
```
`includes/functions_content.php:777`

Returns an array with `text` (what the user originally typed, BBCode and all),
plus the decoded `allow_bbcode`, `allow_smilies`, `allow_urls` flags. This is
the reverse of storage, not of display.

Never feed rendered HTML back into an editor.

---

## Writing — new text into the database

### The four values

```php
generate_text_for_storage(
	&$text, &$uid, &$bitfield, &$flags,
	$allow_bbcode = false, $allow_urls = false, $allow_smilies = false,
	$allow_img_bbcode = true, $allow_flash_bbcode = true,
	$allow_quote_bbcode = true, $allow_url_bbcode = true,
	$mode = 'post'
)
```
`includes/functions_content.php:694`

The first four are **by reference** — you pass empty variables and it fills
them. Note that `$allow_bbcode`, `$allow_urls` and `$allow_smilies` default to
**false**: forgetting them silently strips all formatting.

```php
$text     = "Hello [b]world[/b]";
$uid      = '';
$bitfield = '';
$flags    = 0;
generate_text_for_storage($text, $uid, $bitfield, $flags, true, true, true);
// now insert $text, $uid, $bitfield and the decoded $flags
```

This is the minimum for a field like `forum_desc` or `group_desc`.

### A whole post

For posts and PMs, `generate_text_for_storage()` is **not enough**. Use:

```php
submit_post($mode, $subject, $username, $topic_type, &$poll, &$data, $update_message = true, $update_search_index = true)
```
`includes/functions_posting.php`

`$mode` is `'post'`, `'reply'`, `'quote'` or `'edit'`. It also:

- updates `topic_posts_approved`, `forum_posts_approved`, `user_posts`
- updates the last-post caches on topic and forum
- writes the search index
- sends notifications and handles subscriptions
- marks the topic read for the poster, handles attachments and polls

**A raw `INSERT INTO phpbb_posts` gives you a post that renders as literal
BBCode, is invisible to search, and leaves every counter wrong.** See
`phpbb-data`'s pitfalls reference.

The usual way to build `$data` is `\parse_message` in
`includes/message_parser.php`, which wraps the parser and validates lengths,
attachments and permissions.

### The parser service

`\phpbb\textformatter\parser_interface`:

```php
public function parse($text);
public function get_errors();
public function set_var($name, $value);
public function set_vars(array $vars);
public function enable_bbcode($name);      public function disable_bbcode($name);
public function enable_bbcodes();          public function disable_bbcodes();
public function enable_censor();           public function disable_censor();
public function enable_magic_url();        public function disable_magic_url();
public function enable_smilies();          public function disable_smilies();
```

`parse()` returns the s9e XML to store. Always check `get_errors()` — it
returns language keys for things like unclosed tags or a too-deep quote nest.

---

## Extracting — plain text out

`\phpbb\textformatter\utils_interface`, service `text_formatter.utils`:

```php
public function clean_formatting($text);
public function generate_quote($text, array $attributes = array());
public function get_outermost_quote_authors($text);
public function remove_bbcode($text, $bbcode_name, $depth = 0);
public function unparse($text);
public function is_empty($text);
```

| Method | Gives you | Use for |
|---|---|---|
| `clean_formatting()` | plain text, formatting replaced with whitespace, **smilies preserved as their text codes** | excerpts, search input, notification previews |
| `unparse()` | the original text the user typed, BBCode included | re-editing, migrating content |
| `remove_bbcode($text, 'quote', 2)` | the stored form with one BBCode stripped, optionally only below a depth | trimming nested quotes |
| `generate_quote($text, ['author' => ..., 'post_id' => ..., 'user_id' => ..., 'time' => ...])` | a quote block ready to insert into a new post | reply-with-quote |
| `get_outermost_quote_authors()` | the author names of top-level quotes | notification logic |
| `is_empty()` | whether the text has any content once markup is removed | validation |

`clean_formatting()` and `unparse()` are the two you want most often, and they
are not interchangeable: one is for machines, the other for humans.

---

## Which function, at a glance

| Goal | Call |
|---|---|
| Show a post on a page | `generate_text_for_display()` |
| Show a post outside a request | `text_formatter.renderer->render()` |
| Fill an edit form | `generate_text_for_edit()` |
| Store a description / signature / rules field | `generate_text_for_storage()` |
| Create or edit a post or PM | `submit_post()` |
| Excerpt, index, diff | `text_formatter.utils->clean_formatting()` |
| Recover what the user typed | `text_formatter.utils->unparse()` |
| Re-process everything after a rule change | `reparser:reparse` |
