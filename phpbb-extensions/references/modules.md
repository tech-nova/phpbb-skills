# Control panel modules

Three panels, same mechanism:

| Class | Panel | Lives in |
|---|---|---|
| `acp` | Administration Control Panel | `acp/` |
| `ucp` | User Control Panel | `ucp/` |
| `mcp` | Moderator Control Panel | `mcp/` |

A module is **two files plus a migration step**: an info class describing it, a
module class implementing it, and `module.add` registering it in
`phpbb_modules`.

---

## The info class

`acp/<name>_info.php`, class `<name>_info`, one method `module()`.
From `ext/phpbb/viglink/acp/viglink_info.php`:

```php
namespace phpbb\viglink\acp;

class viglink_info
{
	public function module()
	{
		return array(
			'filename' => '\phpbb\viglink\acp\viglink_module',
			'title'    => 'ACP_VIGLINK_SETTINGS',
			'modes'    => array(
				'settings' => array(
					'title' => 'ACP_VIGLINK_SETTINGS',
					'auth'  => 'ext_phpbb/viglink && acl_a_board',
					'cat'   => array('ACP_BOARD_CONFIGURATION'),
				),
			),
		);
	}
}
```

- `filename` — the fully-qualified module class.
- `title` — a **language key**, not a string.
- `modes` — one entry per screen. Each has:
  - `title`: language key for the menu entry
  - `auth`: the access expression (below)
  - `cat`: which existing category it appears under, by language key

### The `auth` expression

A small boolean language of its own:

- `acl_<permission>` — the viewer must hold that permission, e.g. `acl_a_board`
- `ext_<vendor>/<package>` — that extension must be enabled
- `cfg_<config_name>` — that config value must be truthy
- combined with `&&` and `||`

`'ext_phpbb/viglink && acl_a_board'` means "this extension is enabled **and**
the user may change board settings". Always include the `ext_` clause, so the
module disappears when the extension is disabled.

---

## The module class

`acp/<name>_module.php`. It is a plain class — no base class to extend — with
three public properties and a `main($id, $mode)` method.

```php
namespace vendor\package\acp;

class my_module
{
	/** @var string */
	public $page_title;

	/** @var string */
	public $tpl_name;

	/** @var string */
	public $u_action;

	public function main($id, $mode)
	{
		global $phpbb_container;

		$config   = $phpbb_container->get('config');
		$language = $phpbb_container->get('language');
		$request  = $phpbb_container->get('request');
		$template = $phpbb_container->get('template');

		$language->add_lang('my_module_acp', 'vendor/package');

		$this->tpl_name   = 'acp_my_module';        // adm/style/acp_my_module.html
		$this->page_title = 'ACP_MY_MODULE_TITLE';  // a language key

		if ($mode !== 'settings')
		{
			return;
		}

		$form_key = 'acp_my_module';
		add_form_key($form_key);

		if ($request->is_set_post('submit'))
		{
			if (!check_form_key($form_key))
			{
				trigger_error($language->lang('FORM_INVALID') . adm_back_link($this->u_action), E_USER_WARNING);
			}

			$config->set('my_setting', $request->variable('my_setting', 0));
			trigger_error($language->lang('CONFIG_UPDATED') . adm_back_link($this->u_action));
		}

		$template->assign_vars(array(
			'U_ACTION'   => $this->u_action,
			'MY_SETTING' => $config['my_setting'],
		));
	}
}
```

The contract:

- **`$this->tpl_name`** — template name without extension. ACP templates go in
  the extension's `adm/style/`; UCP and MCP templates in
  `styles/all/template/`.
- **`$this->page_title`** — a language key.
- **`$this->u_action`** — set by phpBB, not by you. It is the URL of the current
  module screen; use it as the form action and in `adm_back_link()`.
- `$id` and `$mode` identify which module row and which mode is being shown.

Module classes are instantiated by the module manager, not by the DI container,
which is why viglink reaches for `$phpbb_container` inside `main()`. Extract
real logic into a proper service (viglink has `acp/viglink_helper.php`) and
keep the module thin.

### Forms

`add_form_key()` / `check_form_key()` are the CSRF protection — required on
every ACP form. `trigger_error($message . adm_back_link($this->u_action))` is
the idiomatic way to finish, for both success and failure.

Read input with `$request->variable($name, $default)`, which types the value
from `$default`. Never touch `$_POST` or `$_GET`.

---

## Registering it

In a migration's `update_data()`:

```php
array('module.add', array(
	'acp',                              // class: acp | ucp | mcp
	'ACP_BOARD_CONFIGURATION',          // parent category, by language key
	array(
		'module_basename' => '\vendor\package\acp\my_module',
		'modes'           => array('settings'),
	),
)),
```

Removing it in `revert_data()`:

```php
array('module.remove', array(
	'acp',
	'ACP_BOARD_CONFIGURATION',
	array(
		'module_basename' => '\vendor\package\acp\my_module',
		'modes'           => array('settings'),
	),
)),
```

To create a **new category** rather than adding to an existing one, `module.add`
with a plain language key as the third argument instead of the array, then add
the module under it in a second step.

`phpbb_modules` is a nested set (`left_id`/`right_id`) — never insert rows
directly. Signatures: `add($class, $parent = 0, $data = array())`,
`remove($class, $parent = 0, $module = '')` in
`phpbb/db/migration/tool/module.php`.

---

## Permissions

A module that needs its own permission rather than reusing `acl_a_board`:

1. Declare it in a migration:
   ```php
   array('permission.add', array('a_my_permission', true)),
   array('permission.permission_set', array('ROLE_ADMIN_FULL', 'a_my_permission', 'role', true)),
   ```
   `true` means global; `false` means per-forum.

2. Reference it in the info class: `'auth' => 'ext_vendor/package && acl_a_my_permission'`

3. Check it in code: `$auth->acl_get('a_my_permission')`, or
   `$auth->acl_get('f_read', $forum_id)` for a forum-local one.

Permission name prefixes are conventional and enforced by the ACP's grouping:
`a_` admin, `m_` moderator, `f_` forum, `u_` user.

Remember that permissions are cached in `users.user_permissions` — the
migration tool clears the cache for you, but code that writes ACL rows directly
must call `$auth->acl_clear_prefetch()`. See the **phpbb-data** skill.
