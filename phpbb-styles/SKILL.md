---
name: phpbb-styles
description: Use when customising the look of a phpBB 3.3 forum - creating or editing a style under styles/, overriding prosilver templates, writing phpBB Twig markup, changing CSS, handling responsive or RTL layouts, or deciding between a template override and a template event.
---

# phpBB 3.3 styles

## How a template is resolved

When phpBB needs `viewtopic_body.html`, it looks in order:

1. `styles/<active_style>/template/`
2. the parent style's `template/`, following `parent` in `style.cfg` up the chain
3. `styles/prosilver/template/` — the end of every chain in practice
4. enabled extensions' `styles/all/template/event/` files, injected at each
   template event

So a style only needs to ship the files it actually changes. prosilver has 115
templates; a well-built child style ships a handful.

## The central decision: override or event?

| | Template override | Template event |
|---|---|---|
| You write | a full copy of a prosilver file in your style | a small fragment in `styles/all/template/event/<name>.html` |
| Lives in | a style | an extension |
| On phpBB upgrade | **your copy is now stale** — prosilver's version changed, yours did not | keeps working |
| Applies to | one style | every style |

**Prefer the event.** An override is the right answer only when you are
restructuring a page, not when you are adding to it. Every override you ship is
a file you must diff against prosilver at each upgrade.

Template events are covered by the **phpbb-extensions** skill —
see its [events reference](../phpbb-extensions/references/events.md).

## The three references

| Topic | File |
|---|---|
| `style.cfg`, inheritance, installing a style, `styles/all/` | [references/inheritance.md](references/inheritance.md) |
| phpBB's Twig dialect: the tags, the legacy syntax, `lang()` | [references/twig.md](references/twig.md) |
| CSS load order, the prosilver files, responsive, RTL | [references/css.md](references/css.md) |

## Purge the cache

Templates are compiled and cached. **Nothing you change in a template or a
stylesheet takes effect until you purge:**

```
php bin/phpbbcli.php cache:purge
```

This is the single most common reason a style change "does nothing". During
development, set `PHPBB_ENVIRONMENT=development` so templates recompile on each
request — see the **phpbb-admin** skill.

## Rules

- **Never edit prosilver.** It is replaced wholesale on upgrade. Create a child
  style with `parent = prosilver` instead.
- **Ship the minimum.** Every template you copy is maintenance debt.
- **Never hardcode a string.** Use `{{ lang('KEY') }}` and ship a language file.
- **Keep template events intact** when you do override a file — extensions
  depend on them, and removing one silently breaks other people's extensions.
- **Purge the cache** after every change.
