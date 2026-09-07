# Custom BBCodes

phpBB ships a fixed set of core BBCodes (`b`, `i`, `u`, `quote`, `code`,
`list`, `img`, `url`, `size`, `color`, `email`, `flash`, `attachment`). Anything
else is a **custom BBCode**, stored in `phpbb_bbcodes`.

## The table

| Column | Holds |
|---|---|
| `bbcode_id` | primary key; ids below 12 are reserved for core BBCodes |
| `bbcode_tag` | the tag name, e.g. `highlight` |
| `bbcode_helpline` | the tooltip shown on the posting page |
| `display_on_posting` | whether it gets a button in the posting form |
| `bbcode_match` | the usage pattern |
| `bbcode_tpl` | the HTML replacement |
| `first_pass_match`, `first_pass_replace`, `second_pass_match`, `second_pass_replace` | compiled legacy regexes, generated — never write these by hand |

The last four exist for the pre-3.2 renderer. The s9e factory compiles from
`bbcode_match`/`bbcode_tpl`; leave the generated columns to phpBB.

## `bbcode_match` and `bbcode_tpl`

```
bbcode_match: [highlight={COLOR}]{TEXT}[/highlight]
bbcode_tpl:   <span style="background-color: {COLOR};">{TEXT}</span>
```

Number tokens when a tag uses more than one of a kind:

```
bbcode_match: [font={SIMPLETEXT1}]{SIMPLETEXT2}[/font]
bbcode_tpl:   <span style="font-family: {SIMPLETEXT1};">{SIMPLETEXT2}</span>
```

In `bbcode_tpl` you can also use any language key as `{L_STRINGNAME}` — e.g.
`{L_WROTE}` renders as "wrote" in the viewer's language.

## The tokens

Only these are accepted. Source of truth: the `tokens` array in
`language/en/acp/posting.php`.

| Token | Accepts |
|---|---|
| `{TEXT}` | any text, including non-latin characters |
| `{SIMPLETEXT}` | A-Z, digits, space, comma, dot, minus, plus, hyphen, underscore |
| `{INTTEXT}` | Unicode letters, digits, space, comma, dot, minus, plus, hyphen, underscore, whitespace |
| `{IDENTIFIER}` | A-Z, digits, hyphen, underscore |
| `{ALNUM}` | A-Z and digits |
| `{NUMBER}` | any series of digits |
| `{INT}` | an integer |
| `{UINT}` | an unsigned integer |
| `{FLOAT}` | a decimal value |
| `{RANGE=-10,42}` | an integer within the range |
| `{EMAIL}` | a valid email address |
| `{URL}` | a valid URL on an allowed protocol; `http://` is prefixed if absent |
| `{LOCAL_URL}` | a URL relative to the board, no server name or protocol |
| `{RELATIVE_URL}` | a relative URL — careful: a full URL is also a valid relative URL, prefer `{LOCAL_URL}` for board links |
| `{COLOR}` | `#FF1234` or a CSS colour keyword |
| `{IP}`, `{IPV4}`, `{IPV6}`, `{IPPORT}` | address forms |
| `{TIMESTAMP}` | `1h30m10s` or a number, converted to seconds |
| `{CHOICE=a,b,c}` | one of the listed values; add `;caseSensitive` to make it strict |
| `{MAP=k1:v1,k2:v2}` | maps strings to replacements, case-insensitive |
| `{HASHMAP=k1:v1,k2:v2}` | same, case-sensitive |
| `{REGEXP=/^foo\w+bar$/}` | matches the given regexp |

**Tokens are the sanitisation boundary.** `{TEXT}` in an HTML attribute is an
injection: use `{SIMPLETEXT}`, `{IDENTIFIER}`, `{COLOR}`, `{CHOICE}` or
`{REGEXP}` for anything that lands inside a tag. Reserve `{TEXT}` for element
content.

## Paired and unpaired forms

`text_formatter.s9e.bbcode_merger` (`phpbb/textformatter/s9e/bbcode_merger.php`)
merges the two shapes of a tag into one definition:

- with a value — `[size=20]text[/size]`
- without — `[size]text[/size]`

Define both in `bbcode_match` as separate BBCodes with the same tag and the
merger combines them. This is why a single `bbcode_tag` can appear twice.

## Adding one

### Through the ACP

*Posting → BBCodes → Add a new BBCode*. Right for a board admin, and the ACP
validates the tokens for you. Not reproducible across installs.

### Through an extension migration

Right when the BBCode is part of a feature. Insert into `phpbb_bbcodes` from
`update_data()`, using a `custom` migration step so you can compute
`bbcode_id`:

```php
public function update_data()
{
	return array(
		array('custom', array(array($this, 'add_bbcode'))),
	);
}

public function add_bbcode()
{
	$sql = 'SELECT MAX(bbcode_id) AS max_id FROM ' . BBCODES_TABLE;
	$result = $this->db->sql_query($sql);
	$max_id = (int) $this->db->sql_fetchfield('max_id');
	$this->db->sql_freeresult($result);

	$bbcode_id = max($max_id + 1, 13);   // ids under 13 are reserved

	$sql_ary = array(
		'bbcode_id'          => $bbcode_id,
		'bbcode_tag'         => 'highlight',
		'bbcode_helpline'    => 'HIGHLIGHT_HELPLINE',
		'display_on_posting' => 1,
		'bbcode_match'       => '[highlight={COLOR}]{TEXT}[/highlight]',
		'bbcode_tpl'         => '<span style="background-color: {COLOR};">{TEXT}</span>',
	);
	$this->db->sql_query('INSERT INTO ' . BBCODES_TABLE . ' ' .
		$this->db->sql_build_array('INSERT', $sql_ary));
}
```

Verify `\phpbb\db\migration\migration`'s available properties and the exact
`custom` step signature in `phpbb/db/migration/migration.php` before writing
this — see the **phpbb-extensions** skill.

`text_formatter.acp_utils` (`phpbb/textformatter/s9e/acp_utils.php`) is what the
ACP uses to validate and compile a definition; call it if you want the same
validation from code.

## After adding, changing or removing one

Two steps, both required:

1. **Purge the cache** — the compiled parser and renderer are cached:
   `php bin/phpbbcli.php cache:purge`
2. **Reparse existing content** — a new BBCode does not retroactively apply,
   and a removed one leaves posts rendering its literal tags:
   see [reparser.md](reparser.md)

Skipping step 2 is the usual reason a new BBCode "works in new posts but not
old ones".
