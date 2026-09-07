# Anatomy of an extension

Every example here is taken from `ext/phpbb/viglink/`, the extension shipped
with phpBB core. Read that directory alongside this file.

---

## `composer.json` — required

Without a valid `composer.json` phpBB does not recognise the directory as an
extension.

```json
{
	"name": "phpbb/viglink",
	"type": "phpbb-extension",
	"description": "The VigLink extension for phpBB …",
	"homepage": "https://www.phpbb.com",
	"version": "1.0.5",
	"keywords": ["phpbb", "extension", "viglink"],
	"license": "GPL-2.0-only",
	"authors": [
		{
			"name": "phpBB Limited",
			"email": "operations@phpbb.com",
			"homepage": "https://www.phpbb.com/go/authors"
		}
	],
	"require": {
		"php": ">=5.4",
		"phpbb/phpbb": ">=3.2.0",
		"composer/installers": "^1.0 || ^2.0"
	},
	"extra": {
		"display-name": "VigLink",
		"soft-require": {
			"phpbb/phpbb": ">=3.2.0"
		}
	}
}
```

- `"type": "phpbb-extension"` is what phpBB looks for.
- `name` must be `vendor/package`, matching the directory path and the PHP
  namespace.
- `extra.display-name` is the label in the ACP extension list.
- `extra.soft-require` records a phpBB version requirement without letting
  Composer refuse installation — the real gate is `ext.php`.

---

## `ext.php` — optional lifecycle hooks

Extends `\phpbb\extension\base`. Only needed when you must gate installation or
run code at enable/disable/purge time.

```php
namespace phpbb\viglink;

class ext extends \phpbb\extension\base
{
	public function is_enableable()
	{
		return phpbb_version_compare(PHPBB_VERSION, '3.2.0-b1', '>=');
	}

	public function enable_step($old_state)
	{
		if ($old_state === false)
		{
			// first step: do something, return a state marker
			return 'viglink';
		}

		return parent::enable_step($old_state);
	}
}
```

`is_enableable()` returning false blocks enabling with a message. Use it for a
version floor or a missing dependency.

`enable_step()`, `disable_step()` and `purge_step()` follow a **resumable
protocol**: called with `false` the first time, then with whatever the previous
call returned, until they return `false`. This lets long work run across
several HTTP requests without timing out. Always end by delegating to
`parent::` so the base class finishes migrations and cache handling.

---

## `config/services.yml` — dependency injection

```yaml
imports:
    - { resource: cron.yml }

services:
    phpbb.viglink.listener:
        class: phpbb\viglink\event\listener
        arguments:
            - '@config'
            - '@template'
        tags:
            - { name: event.listener }

    phpbb.viglink.acp_listener:
        class: phpbb\viglink\event\acp_listener
        arguments:
            - '@config'
            - '@language'
            - '@request'
            - '@template'
            - '@user'
            - '@phpbb.viglink.helper'
            - '%core.root_path%'
            - '%core.php_ext%'
        tags:
            - { name: event.listener }

    phpbb.viglink.helper:
        class: phpbb\viglink\acp\viglink_helper
        arguments:
            - '@cache.driver'
            - '@config'
            - '@file_downloader'
            - '@language'
            - '@log'
            - '@user'
```

- Service ids conventionally start with `vendor.package.`.
- `'@name'` injects another service; `'%name%'` injects a container parameter.
- **`tags: [{ name: event.listener }]` is what registers a subscriber.** Without
  the tag the class is built but never called — the most common reason a
  listener "does nothing".
- Core service ids live in `config/default/container/services_*.yml`; container
  parameters including `%core.root_path%`, `%core.php_ext%` and the
  `%tables.*%` set live in `parameters.yml` and `tables.yml`. Read them rather
  than guessing an id.

Services are cached. **Purge the cache after editing this file.**

## `config/routing.yml` — front-end routes

Maps a URL to a controller service. Present only if the extension adds pages.

## `config/cron.yml` — scheduled tasks

Declares task services with the `cron.task` tag; the class extends
`\phpbb\cron\task\base`. viglink has one, in `cron/viglink.php`.

---

## `event/` — listeners

See [events.md](events.md).

## `migrations/` — schema and data

See [migrations.md](migrations.md). viglink has five:
`viglink_data.php`, `viglink_data_v2.php`, `viglink_ask_admin.php`,
`viglink_ask_admin_wait.php`, `viglink_cron.php`.

## `acp/`, `ucp/`, `mcp/` — control panel modules

See [modules.md](modules.md). viglink has `acp/viglink_module.php`,
`acp/viglink_info.php` and `acp/viglink_helper.php`.

---

## `language/<iso>/` — strings

```php
if (!defined('IN_PHPBB')) { exit; }
if (empty($lang) || !is_array($lang)) { $lang = array(); }

$lang = array_merge($lang, array(
	'ACP_VIGLINK_SETTINGS' => 'VigLink settings',
));
```

Always `array_merge` into `$lang`; never assign. Ship at least `en`. Keys are
conventionally prefixed to avoid collisions with core and other extensions.

Load a file from a listener with
`$this->language->add_lang('common', 'vendor/package')`.

---

## `styles/all/template/event/` — template events

One file per event, named exactly after the event. viglink has:

```
styles/all/template/event/overall_footer_after.html
styles/all/template/event/acp_help_phpbb_stats_before.html
styles/all/template/event/acp_help_phpbb_stats_after.html
```

The file's content is injected wherever that template event appears, in **every
style**, without touching any style's files. This is the mechanism that makes
overrides unnecessary. See [events.md](events.md).

A style-specific variant goes in `styles/<style>/template/event/` instead of
`styles/all/`.

---

## `adm/style/` — ACP templates

Templates for the extension's own ACP modules, plus ACP template events.

## `tests/` — PHPUnit

phpBB's test suite can run an extension's tests against a real board. Not
required, but the shipped extensions have them and the pattern is worth
copying if the extension is non-trivial.
