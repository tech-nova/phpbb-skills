---
name: phpbb-extensions
description: Use when building or modifying a phpBB 3.3 extension in ext/ - composer.json, ext.php, config/services.yml, event listeners, database migrations, ACP/UCP/MCP modules, controllers, cron tasks, language files, or enabling and purging an extension.
---

# phpBB 3.3 extensions

An extension is the **only** supported way to change forum behaviour. Patching
core is reverted by the next update and breaks the updater.

## Read the shipped example first

`ext/phpbb/viglink/` ships with core and is a complete, real extension:
`composer.json`, `ext.php`, `config/services.yml` + `cron.yml`, two event
listeners, five migrations, an ACP module, language files and template events.
**Read it before writing anything** — it is more reliable than memory, and it
is guaranteed to be correct for the version you are working against.

## Layout

```
ext/<vendor>/<package>/
	composer.json              required — declares the extension to phpBB
	ext.php                    optional — enable/disable/purge hooks
	config/
		services.yml           DI: listeners, controllers, helpers
		routing.yml            front-end routes
		cron.yml               cron tasks
	event/
		listener.php           event subscribers
	migrations/
		*.php                  schema and data changes
	language/<iso>/
		*.php                  translatable strings
	styles/all/template/event/
		<event_name>.html      template event hooks
	acp/  ucp/  mcp/           control panel modules
	controller/                front-end controllers
	cron/                      cron task classes
	notification/type/         notification types
	tests/                     PHPUnit tests
```

`<vendor>/<package>` is also the PHP namespace (`\vendor\package\…`) and the
name in `phpbb_ext.ext_name`. It is fixed at creation — renaming means
uninstalling and reinstalling.

Details, file by file, from viglink: **[references/anatomy.md](references/anatomy.md)**

## Lifecycle

```
php bin/phpbbcli.php extension:show          # what is installed and enabled
php bin/phpbbcli.php extension:enable  vendor/package
php bin/phpbbcli.php extension:disable vendor/package
php bin/phpbbcli.php extension:purge   vendor/package   # disable + revert migrations
```

- **enable** runs pending migrations, then `ext.php`'s `enable_step()`.
- **disable** stops the extension but **keeps its data and schema**.
- **purge** additionally reverts the migrations — destructive.

Also available in the ACP under *Customise → Manage extensions*. Purge the
cache after enabling (`cache:purge`); template and service changes are cached.

## Building one: the order that works

1. `composer.json` with `"type": "phpbb-extension"` — without it phpBB does not
   see the directory at all.
2. Language file, so no string is hardcoded.
3. Migration for any config value, module or schema change.
4. `config/services.yml` declaring your listener.
5. `event/listener.php` implementing `EventSubscriberInterface`.
6. Template event files under `styles/all/template/event/` if you need markup.
7. `extension:enable`, then `cache:purge`.

## The four references

| Topic | File |
|---|---|
| Every file of an extension, from the shipped example | [anatomy.md](references/anatomy.md) |
| Finding and subscribing to events, PHP and template | [events.md](references/events.md) |
| Schema and data changes | [migrations.md](references/migrations.md) |
| ACP/UCP/MCP modules and permissions | [modules.md](references/modules.md) |

## Rules

- **Prefer an event over a template override.** Overrides freeze a copy of a
  prosilver file that will drift at the next upgrade.
- **Never write DDL outside a migration.** The migrator's ledger
  (`phpbb_migrations`) desynchronises and later updates fail.
- **Never hardcode a table name.** Inject `%tables.posts%` and friends from
  `config/default/container/tables.yml`.
- **Every user-facing string goes through a language file** and `$user->lang()`
  / `{{ lang('KEY') }}`.
- **Verify the event exists** with `../phpbb/scripts/find-event.sh` before
  subscribing to it. Subscribing to a name that does not exist fails silently.
