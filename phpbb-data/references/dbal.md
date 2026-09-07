# Querying through the DBAL

`$db` implements `\phpbb\db\driver\driver_interface`. phpBB supports MySQL,
PostgreSQL, SQLite 3, MS SQL and Oracle behind it. Signatures below are copied
from `phpbb/db/driver/driver_interface.php` — re-read that file rather than
trusting memory.

In an extension, inject the `dbal.conn` service; in legacy scripts `$db` is a
global.

## Running queries

```php
public function sql_query($query = '', $cache_ttl = 0);
public function sql_query_limit($query, $total, $offset = 0, $cache_ttl = 0);
public function sql_fetchrow($query_id = false);
public function sql_fetchrowset($query_id = false);
public function sql_fetchfield($field, $rownum = false, $query_id = false);
public function sql_freeresult($query_id = false);
public function sql_affectedrows();
public function sql_nextid();
public function sql_last_inserted_id();
```

**Never write `LIMIT` yourself.** `LIMIT n OFFSET m` is MySQL/PostgreSQL syntax;
MS SQL and Oracle differ. `sql_query_limit()` rewrites it per driver.

```php
$sql = 'SELECT post_id, post_subject
	FROM ' . POSTS_TABLE . '
	WHERE topic_id = ' . (int) $topic_id . '
	ORDER BY post_time ASC';
$result = $db->sql_query_limit($sql, 25, 0);
while ($row = $db->sql_fetchrow($result))
{
	// ...
}
$db->sql_freeresult($result);
```

Always `sql_freeresult()` — some drivers leak otherwise.

`$cache_ttl` caches the result set through the ACM layer. Use it only for
queries whose result is genuinely stable.

## Escaping — the injection rules

```php
public function sql_escape($msg);
public function sql_quote($msg);
public function sql_in_set($field, $array, $negate = false, $allow_empty_set = false);
public function sql_like_expression($expression);
public function sql_not_like_expression($expression);
```

- **Integers**: cast, `(int) $forum_id`. This is the idiomatic phpBB form.
- **Strings**: `"'" . $db->sql_escape($value) . "'"` — note that `sql_escape`
  does **not** add the quotes.
- **`IN (...)`**: `$db->sql_in_set('forum_id', $forum_ids)`. It handles escaping,
  single-element sets (emits `= x`, not `IN (x)`), and the empty set. Pass
  `$allow_empty_set = true` when an empty array should legitimately match
  nothing; otherwise an empty array raises an error rather than producing
  invalid SQL.
- **`LIKE`**: build the pattern with `$db->get_any_char()` and
  `$db->get_one_char()` (the portable `%` and `_`), then wrap in
  `sql_like_expression()`.

Never interpolate a raw variable into a query string. This is the standard
phpBB security bug.

## Building queries

```php
public function sql_build_array($query, $assoc_ary = array());
public function sql_build_query($query, $array);
```

`sql_build_array()` turns an associative array into a fragment, escaping every
value. `$query` is `'INSERT'`, `'UPDATE'`, `'SELECT'` or `'MULTI_INSERT'`.

```php
$sql_ary = array(
	'topic_id'   => (int) $topic_id,
	'forum_id'   => (int) $forum_id,
	'poster_id'  => (int) $user->data['user_id'],
	'post_time'  => time(),
	'post_text'  => $text,
);
$db->sql_query('INSERT INTO ' . POSTS_TABLE . ' ' . $db->sql_build_array('INSERT', $sql_ary));
$post_id = $db->sql_nextid();
```

```php
$sql = 'UPDATE ' . TOPICS_TABLE . '
	SET ' . $db->sql_build_array('UPDATE', $sql_ary) . '
	WHERE topic_id = ' . (int) $topic_id;
$db->sql_query($sql);
```

`sql_build_query('SELECT', $array)` assembles a multi-table select from
`SELECT` / `FROM` / `LEFT_JOIN` / `WHERE` / `GROUP_BY` / `ORDER_BY` keys — this
is what core uses when an event needs to let extensions add joins:

```php
$sql_array = array(
	'SELECT'    => 'p.*, u.username, u.user_colour',
	'FROM'      => array(POSTS_TABLE => 'p'),
	'LEFT_JOIN' => array(
		array('FROM' => array(USERS_TABLE => 'u'), 'ON' => 'p.poster_id = u.user_id'),
	),
	'WHERE'     => 'p.topic_id = ' . (int) $topic_id,
	'ORDER_BY'  => 'p.post_time ASC',
);
$result = $db->sql_query($db->sql_build_query('SELECT', $sql_array));
```

## Bulk inserts

```php
public function sql_multi_insert($table, $sql_ary);
public function get_multi_insert();
public function set_multi_insert($multi_insert);
```

`sql_multi_insert()` takes an array of row arrays and emits one statement per
driver capability. For very large volumes use
`\phpbb\db\sql_insert_buffer`, which batches and flushes.

## Transactions

```php
public function sql_transaction($status = 'begin');   // 'begin' | 'commit' | 'rollback'
public function sql_buffer_nested_transactions();
```

Nested transactions are emulated, not real — check
`sql_buffer_nested_transactions()` before relying on nesting.

## Portability helpers

Use these instead of writing engine-specific SQL:

```php
public function sql_concatenate($expr1, $expr2);
public function sql_case($condition, $action_true, $action_false = false);
public function sql_lower_text($column_name);
public function sql_bit_and($column_name, $bit, $compare = '');
public function sql_bit_or($column_name, $bit, $compare = '');
public function cast_expr_to_bigint($expression);
public function cast_expr_to_string($expression);
public function get_any_char();      // portable '%'
public function get_one_char();      // portable '_'
public function get_sql_layer();     // e.g. 'mysqli', 'postgres'
```

## Diagnostics

```php
public function sql_error($sql = '');
public function sql_return_on_error($fail = false);
public function sql_num_queries($cached = false);
public function sql_report($mode, $query = '');
public function get_row_count($table_name);
public function get_estimated_row_count($table_name);
```

`sql_return_on_error(true)` suppresses the fatal error handler so you can
inspect a failure; always turn it back off.

## What not to do

- **No raw PDO or `mysqli`.** It bypasses the abstraction, the query counter,
  the cache layer and the debug report, and breaks on four of the five
  supported engines.
- **No DDL from application code.** Schema changes belong in a migration — see
  the **phpbb-extensions** skill.
- **No direct `UPDATE` on counters or visibility.** See
  [pitfalls.md](pitfalls.md).
- **No literal table names.** See [pitfalls.md](pitfalls.md) §5.
