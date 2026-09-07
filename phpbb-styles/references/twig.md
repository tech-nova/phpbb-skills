# phpBB's Twig dialect

phpBB templates are Twig, plus a set of custom tags, plus a **legacy syntax
that is rewritten into Twig before compilation**. All three appear in real
templates, including prosilver's.

## Two syntaxes, one engine

`phpbb/template/twig/lexer.php` rewrites the old phpBB 3.0 markup into Twig at
load time. These pairs are equivalent:

| Legacy | Twig |
|---|---|
| `<!-- IF x -->` … `<!-- ENDIF -->` | `{% if x %}` … `{% endif %}` |
| `<!-- ELSEIF x -->` / `<!-- ELSE -->` | `{% elseif x %}` / `{% else %}` |
| `<!-- BEGIN loop -->` … `<!-- END loop -->` | `{% for x in loop %}` … `{% endfor %}` |
| `<!-- BEGINELSE -->` | the `{% else %}` branch of a `for` |
| `<!-- INCLUDE file.html -->` | `{% INCLUDE 'file.html' %}` |
| `<!-- EVENT name -->` | `{% EVENT name %}` |
| `<!-- DEFINE $X = 1 -->` / `<!-- UNDEFINE $X -->` | `{% DEFINE $X = 1 %}` |
| `<!-- INCLUDECSS file -->` / `<!-- INCLUDEJS file -->` | `{% INCLUDECSS … %}` / `{% INCLUDEJS … %}` |
| `<!-- PHP -->` … `<!-- ENDPHP -->` | `{% PHP %}` (disabled by default) |
| `{VARIABLE}` | `{{ VARIABLE }}` |

**prosilver uses the legacy form for most of these**, notably
`<!-- EVENT name -->` and `<!-- IF -->`. Both work everywhere. When editing an
existing file, match what is already there; in a new file, either is fine.

The full list of tokens the lexer converts: `IF`, `ELSE`, `ELSEIF`, `ENDIF`,
`BEGIN`, `BEGINELSE`, `END`, `DEFINE`, `ENDDEFINE`, `UNDEFINE`, `INCLUDE`,
`INCLUDECSS`, `INCLUDEJS`, `INCLUDEPHP`, `PHP`, `ENDPHP`, `EVENT`, `NAME`.

## The custom tags

Implemented in `phpbb/template/twig/tokenparser/`:
`event.php`, `defineparser.php`, `includeparser.php`, `includecss.php`,
`includejs.php`, `includephp.php`, `php.php`.

### `EVENT`

```twig
{% EVENT viewtopic_topic_title_before %}
```

Inserts every enabled extension's
`styles/all/template/event/viewtopic_topic_title_before.html` at that point.
Emits nothing when no extension hooks it. This is the extension seam — see the
**phpbb-extensions** skill.

### `INCLUDE`

```twig
{% INCLUDE 'overall_header.html' %}
```

Resolved through the style inheritance chain, so an included file can come from
the parent style.

### `DEFINE` / `UNDEFINE`

```twig
{% DEFINE $COLSPAN = 4 %}
{{ $COLSPAN }}
{% UNDEFINE $COLSPAN %}
```

Template-local variables. The `$` prefix is part of the name.

### `INCLUDECSS` / `INCLUDEJS`

```twig
{% INCLUDEJS RECAPTCHA_SERVER ~ '.js?onload=phpbbRecaptchaOnLoad&hl=' ~ lang('RECAPTCHA_LANG') %}
```
```html
<!-- INCLUDEJS forum_fn.js -->
```

Queue an asset for the collected `<script>` / `<link>` block in the footer or
header, rather than emitting a tag inline. Paths resolve through the style
chain; use `{T_ASSETS_PATH}` for core assets.

### `PHP` / `INCLUDEPHP`

Inline PHP in templates. **Disabled unless `$config['tpl_allow_php']` is on**,
and it should stay off. Anything you need PHP for belongs in an event listener.

## Functions and filters phpBB adds

From `phpbb/template/twig/extension.php`:

| | Name | Use |
|---|---|---|
| function | `lang('KEY')`, `lang('KEY', arg1, …)` | translate; the only correct way to output text |
| function | `lang_defined('KEY')` | test whether a key exists before using it |
| function | `lang_js('KEY')` | translate, escaped for a JavaScript context |
| function | `get_class(obj)` | PHP's `get_class` |
| filter | `subset(start, len)` | slice a loop — `{% for row in loop.foo|subset(0, 10) %}` |
| filter | `int`, `float` | cast |
| filter | `addslashes` | **deprecated since 3.2** — use Twig's `|escape('js')` |

```twig
<h2>{{ lang('VIEWING_TOPIC') }}</h2>
<p>{{ lang('POSTED_ON_DATE', POST_DATE) }}</p>
```

Everything else is standard Twig: `|escape`, `|raw`, `|length`, `|join`,
`|default`, `{% set %}`, `{% for %}`, `{% if %}`.

## Variables

- `{{ UPPERCASE }}` — a variable assigned from PHP with
  `$template->assign_vars(['NAME' => $value])`.
- Loops come from `$template->assign_block_vars('loopname', [...])` and are read
  as `{% for row in loopname %}` … `{{ row.FIELD }}`.
- `{{ VAR }}` autoescapes. Use `{{ VAR|raw }}` **only** for content that is
  already safe HTML — rendered post text from `generate_text_for_display()`
  being the standard case.

## Escaping and safety

Autoescaping is on. The two mistakes to avoid:

1. `|raw` on anything that came from a user and was not run through the text
   formatter. See the **phpbb-formatting** skill.
2. Hardcoded English. Every visible string goes through `lang()`, or the ~50
   language packs cannot translate it.

## Debugging

Templates are compiled and cached. After editing one:

```
php bin/phpbbcli.php cache:purge
```

Or set `PHPBB_ENVIRONMENT=development`, which recompiles on each request and
turns on Twig's real error messages instead of a generic failure.
