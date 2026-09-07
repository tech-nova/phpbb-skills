# Style structure and inheritance

## Layout

```
styles/<name>/
	style.cfg                  required — the style's manifest
	template/                  .html templates (and .twig, both work)
	theme/
		stylesheet.css         entry point, @imports the rest
		*.css
		images/
		<iso>/                 language-specific images
```

`styles/all/` sits beside the styles and holds assets and template-event files
shared by every style. Extensions write into `styles/all/template/event/`.

## `style.cfg`

Verified against `styles/prosilver/style.cfg`:

```ini
name = prosilver
copyright = © phpBB Limited, 2007
style_version = 3.3.17
phpbb_version = 3.3.17

# template_bitfield = //g=

parent = prosilver
```

| Key | Meaning |
|---|---|
| `name` | display name in the ACP. Must be unique. |
| `copyright` | shown in the ACP style list |
| `style_version` | your style's version |
| `phpbb_version` | the phpBB version it targets — the ACP warns on a mismatch |
| `parent` | the style to inherit from. Empty, or the style's own name, means no parent. |
| `template_bitfield` | optional, rarely used |

Values are trimmed; quote them to keep leading or trailing spaces. `#` starts a
comment.

**`parent = prosilver` is what makes inheritance work.** Without it, phpBB
expects the style to be complete and pages break wherever a file is missing.

## Resolution order

For any template or theme file:

1. the active style
2. its parent, then the parent's parent, up the chain
3. prosilver

`phpbb_styles.style_parent_id` and `style_parent_tree` cache the chain in the
database — they are rebuilt when a style is installed, not edited by hand.

The same inheritance applies to `theme/` files, so a child style can ship only
`stylesheet.css` plus one override file and inherit the other eleven from
prosilver.

## Installing a style

1. Upload the directory to `styles/`.
2. ACP → *Customise → Styles* → install.
3. It gets a row in `phpbb_styles`: `style_id`, `style_name`, `style_path`,
   `style_active`, `style_parent_id`, `style_parent_tree`.
4. Purge the cache.

The board default is `config['default_style']`; a user's choice is
`users.user_style`; a forum can force one with `forums.forum_style`.

## Case study: Solace

`phpbb3-style-solace` is a third-party style worth reading as an example of the
inheritance approach done deliberately.

What it demonstrates:

- **`parent = prosilver`** in its `style.cfg`, targeting `phpbb_version = 3.3.0`.
- **It ships 10 template files against prosilver's 115.** Everything else is
  inherited. (Its README claims three; the real count is ten — always count
  rather than trust a claim.) The point stands either way: shipping ~9% of the
  templates means a phpBB upgrade touches almost nothing.
- **Configuration moved out of the style and into a companion extension.**
  Colours, fonts, menus, logo and slideshow settings live in an extension
  (`devlom/configurator`) with an ACP module and YAML config, rather than being
  edited into template and CSS files. The style stays upgradeable; the settings
  survive independently.
- **prosilver's CSS ordering is kept** rather than introducing Sass or Less, so
  the theme files stay drop-in comparable with prosilver's.

The general lesson: **put behaviour and configuration in an extension, keep the
style thin.** A style that overrides 100 templates is a style that has to be
re-merged at every phpBB release.

Mixed file extensions are fine — Solace uses both `.html` and `.html.twig`.

## Shipping style files from an extension

An extension can add its own templates and CSS without being a style:

```
ext/vendor/package/styles/all/template/event/<event_name>.html
ext/vendor/package/styles/all/template/<your_own_template>.html
ext/vendor/package/styles/prosilver/theme/<your>.css
```

`styles/all/` applies to every style; `styles/<style_name>/` targets one. This
is how an extension adds markup to pages it does not own.

## What not to do

- **Do not edit `styles/prosilver/`.** It is replaced on upgrade.
- **Do not copy all 115 templates into a new style.** You inherit them for free
  and copying them makes every future upgrade a merge.
- **Do not delete template events** from a file you override — extensions hook
  them, and removing one breaks other people's code with no error message.
- **Do not edit `phpbb_styles` directly.** `style_parent_tree` is derived.
