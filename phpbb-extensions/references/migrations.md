# Migrations

Every schema and data change goes through a migration. The migrator records
what ran in `phpbb_migrations`; hand-applied SQL desynchronises that ledger and
breaks later updates.

## The class

```php
namespace vendor\package\migrations;

class add_my_feature extends \phpbb\db\migration\migration
{
	static public function depends_on()
	{
		return array('\phpbb\db\migration\data\v33x\v339');
	}

	public function effectively_installed()
	{
		return isset($this->config['my_feature_enabled']);
	}

	public function update_schema()  { return array(); }
	public function revert_schema()  { return array(); }
	public function update_data()    { return array(); }
	public function revert_data()    { return array(); }
}
```

File in `migrations/`, class name matching the file name, namespace
`\vendor\package\migrations`.

The base class (`phpbb/db/migration/migration.php`) gives you `$this->config`,
`$this->db`, `$this->db_tools`, `$this->table_prefix`, `$this->phpbb_root_path`
and `$this->php_ext`.

### `depends_on()`

Static, returns fully-qualified class names that must run first. Depend on:

- a core migration establishing the phpBB version you need — pick a real one
  from `phpbb/db/migration/data/v33x/` (`v339`, `v338`, …). Verify it exists;
  the list changes with each release.
- your own earlier migrations, to force ordering within the extension.

### `effectively_installed()`

Returns true when the change is already present. The migrator then marks the
migration done without running it. Use it so an extension can be installed over
a board that already has the data — checking a config key, a column or a table
is the usual test. Without it, re-enabling an extension can fail on a duplicate.

---

## `update_schema()` / `revert_schema()`

Return an array keyed by operation. The complete set of keys handled by
`phpbb/db/tools/tools.php::perform_schema_changes()`:

`add_tables`, `drop_tables`, `add_columns`, `change_columns`, `drop_columns`,
`add_index`, `add_unique_index`, `add_primary_keys`, `drop_keys`, `primary_key`

```php
public function update_schema()
{
	return array(
		'add_columns' => array(
			$this->table_prefix . 'users' => array(
				'user_my_setting' => array('BOOL', 0),
			),
		),
		'add_tables' => array(
			$this->table_prefix . 'my_table' => array(
				'COLUMNS' => array(
					'my_id'   => array('UINT', null, 'auto_increment'),
					'user_id' => array('ULINT', 0),
					'my_text' => array('TEXT_UNI', ''),
				),
				'PRIMARY_KEY' => 'my_id',
				'KEYS' => array(
					'user_id' => array('INDEX', 'user_id'),
				),
			),
		),
		'add_index' => array(
			$this->table_prefix . 'my_table' => array(
				'my_idx' => array('user_id'),
			),
		),
	);
}

public function revert_schema()
{
	return array(
		'drop_columns' => array(
			$this->table_prefix . 'users' => array('user_my_setting'),
		),
		'drop_tables' => array(
			$this->table_prefix . 'my_table',
		),
	);
}
```

**Always use `$this->table_prefix`**, never a literal `phpbb_`.

Column types are phpBB abstractions, not SQL: `UINT`, `ULINT`, `USINT`, `BOOL`,
`TINT:3`, `VCHAR:255`, `VCHAR_UNI:255`, `STEXT_UNI`, `MTEXT_UNI`, `TEXT_UNI`,
`TIMESTAMP`, `DECIMAL`. `phpbb/db/tools/` maps them per DBMS. Copy the shape of
an existing table from `install/schemas/schema.json` — inspect one with
`../phpbb/scripts/table-schema.py <table>`.

`revert_schema()` must genuinely undo `update_schema()`, or `extension:purge`
leaves debris.

---

## `update_data()` / `revert_data()`

Return a list of `array('<tool>.<method>', array(args…))` steps. Tools live in
`phpbb/db/migration/tool/` and their public methods are the callable names.

### `config` (`tool/config.php`)

| Step | Signature |
|---|---|
| `config.add` | `add($config_name, $config_value, $is_dynamic = false)` |
| `config.update` | `update($config_name, $config_value)` |
| `config.update_if_equals` | `update_if_equals($compare, $config_name, $config_value)` |
| `config.remove` | `remove($config_name)` |

### `config_text` (`tool/config_text.php`)

`config_text.add($name, $value)`, `config_text.update($name, $value)`,
`config_text.remove($name)`.

### `module` (`tool/module.php`)

| Step | Signature |
|---|---|
| `module.add` | `add($class, $parent = 0, $data = array())` |
| `module.remove` | `remove($class, $parent = 0, $module = '')` |

### `permission` (`tool/permission.php`)

| Step | Signature |
|---|---|
| `permission.add` | `add($auth_option, $global = true, $copy_from = false)` |
| `permission.remove` | `remove($auth_option, $global = true)` |
| `permission.role_add` | `role_add($role_name, $role_type, $role_description = '')` |
| `permission.role_update` | `role_update($old_role_name, $new_role_name)` |
| `permission.role_remove` | `role_remove($role_name)` |
| `permission.permission_set` | `permission_set($name, $auth_option, $type = 'role', $has_permission = true)` |
| `permission.permission_unset` | `permission_unset($name, $auth_option, $type = 'role')` |

### `custom`

For anything the tools do not cover:

```php
array('custom', array(array($this, 'my_method'))),
```

`my_method()` is a method on the migration class. It may return a state value
to be called again — the same resumable protocol as `enable_step()`.

---

## A complete worked example

`ext/phpbb/viglink/migrations/viglink_data.php`, unabridged:

```php
namespace phpbb\viglink\migrations;

class viglink_data extends \phpbb\db\migration\migration
{
	public static function depends_on()
	{
		return array('\phpbb\db\migration\data\v31x\v312');
	}

	public function effectively_installed()
	{
		return isset($this->config['phpbb_viglink_api_key']);
	}

	public function update_data()
	{
		return array(
			array('config.add', array('viglink_enabled', 0)),
			array('config.add', array('viglink_api_key', '')),
			array('config.add', array('allow_viglink_phpbb', 1)),
			array('config.add', array('allow_viglink_global', 1)),
			array('config.add', array('phpbb_viglink_api_key', 'e4fd14f5d7f2bb6d80b8f8da1354718c')),
			array('config.add', array('viglink_convert_account_url', '')),
			array('config.add', array('viglink_api_siteid', md5($this->config['server_name']))),

			array('module.add', array(
				'acp',
				'ACP_BOARD_CONFIGURATION',
				array(
					'module_basename' => '\phpbb\viglink\acp\viglink_module',
					'modes'           => array('settings'),
				),
			)),
		);
	}
}
```

Note `effectively_installed()` testing one config key, and `module.add` naming
the module class and its modes — see [modules.md](modules.md).

---

## Running them

```
php bin/phpbbcli.php db:list                    # migrations and their state
php bin/phpbbcli.php db:migrate                 # apply everything pending
php bin/phpbbcli.php db:revert <migration class>
php bin/phpbbcli.php dev:migration-tips         # suggests depends_on values
```

`extension:enable` runs an extension's migrations automatically;
`extension:purge` reverts them.

`dev:migration-tips` is worth knowing: it tells you which migration classes are
the current leaves, which is what `depends_on()` should usually point at.

## Rules

- One logical change per migration. Never edit a migration that has shipped —
  add a new one.
- `revert_*` must undo `update_*` completely.
- `effectively_installed()` on anything that might pre-exist.
- `$this->table_prefix`, always.
- Test the revert path, not only the forward path: `extension:purge` should
  leave the database as it was.
