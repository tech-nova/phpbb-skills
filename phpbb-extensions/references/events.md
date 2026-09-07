# Events

phpBB has two independent event systems. Knowing which one you need, and where
its catalogue lives, is most of the work.

| | PHP events | Template events |
|---|---|---|
| Change | behaviour, data, variables | markup |
| Named | `core.something` | `something` (no prefix) |
| Hooked by | a service tagged `event.listener` | a file in `styles/all/template/event/` |
| Documented in | `@event` docblocks **in the source** | `docs/events.md` |
| Count in 3.3.17 | ~518 | 526 |

**`docs/events.md` contains template events only.** Searching it for
`core.viewtopic_post_row_after` finds nothing, and that absence means nothing.

## Finding an event

```
../phpbb/scripts/find-event.sh <pattern> [phpbb_root]
```

Searches both catalogues and prints, for template events, the `Locations:`,
`Since:` and `Purpose:`; for PHP events, the whole docblock plus the
`trigger_event()` call site.

Search by fragment, not full name — `find-event.sh viewtopic_post_row` returns
the family, which is how you discover that `_before`, `_after` and `_modify`
variants exist.

---

## PHP events

### The call site

```php
/**
* Event after the post data has been assigned to the template
*
* @event core.viewtopic_post_row_after
* @var	int		start				Start item of this page
* @var	int		current_row_number	Number of the post on this page
* @var	array	row					Array with original post and user data
* @var	array	post_row			Template block array of the post
* @var	array	topic_data			Array with topic data
* @since 3.1.0-a3
* @changed 3.1.0-b3 Added topic_data array, total_posts
*/
$vars = array('start', 'current_row_number', 'row', 'post_row', 'topic_data');
extract($phpbb_dispatcher->trigger_event('core.viewtopic_post_row_after', compact($vars)));
```

Read it as a contract:

- **The `@var` lines are the authoritative list** of what a listener can see and
  change. Nothing else is available.
- `@since` tells you the minimum phpBB version — check it against your
  `composer.json` floor.
- `@changed` warns that the variable set differs between versions.
- `compact($vars)` packs the named locals into the event; `extract(...)` unpacks
  whatever listeners returned **back over those locals**. That round trip is
  why a listener's write actually takes effect.

Some events pass data with no `$vars` — they are pure notifications and nothing
you write will be read back.

### Subscribing

```php
namespace vendor\package\event;

use Symfony\Component\EventDispatcher\EventSubscriberInterface;

class listener implements EventSubscriberInterface
{
	/** @var \phpbb\config\config */
	protected $config;

	/** @var \phpbb\template\template */
	protected $template;

	public function __construct(\phpbb\config\config $config, \phpbb\template\template $template)
	{
		$this->config   = $config;
		$this->template = $template;
	}

	public static function getSubscribedEvents()
	{
		return array(
			'core.viewtopic_post_row_after' => 'on_post_row',
		);
	}

	public function on_post_row($event)
	{
		// read
		$row = $event['row'];

		// write back — only works for names listed in the call site's $vars
		$post_row = $event['post_row'];
		$post_row['MY_FLAG'] = ($row['poster_id'] == ANONYMOUS);
		$event['post_row'] = $post_row;
	}
}
```

Register it in `config/services.yml` with the `event.listener` tag — see
[anatomy.md](anatomy.md).

### Reading and writing

- `$event['name']` reads.
- `$event['name'] = $value` writes, **but only takes effect if `name` is in the
  call site's `$vars`**. Writing anything else is silently discarded.
- Arrays are copies. Mutating `$event['post_row']['X']` in place does not work
  in PHP; assign to a local, modify it, assign it back — as above.

### Priority and multiple handlers

```php
return array(
	'core.some_event' => array('my_handler', 10),   // higher runs earlier
);
```

An array of arrays subscribes several handlers to one event. Do not rely on
ordering between extensions.

### Common gotchas

- **The listener is never called.** Almost always the missing
  `tags: [{ name: event.listener }]`, or a stale cache. Purge and retry.
- **The write is ignored.** The variable is not in `$vars`.
- **It works on one page only.** The same logical hook often has several
  events, one per page. Search by fragment.
- **It breaks on an older board.** Check `@since`.

---

## Template events

### Using one from an extension

Create a file named exactly after the event:

```
ext/vendor/package/styles/all/template/event/overall_footer_after.html
```

Its content is inserted wherever `overall_footer_after` appears — **in every
style**, including styles that did not exist when you wrote the extension.
This is why events beat template overrides.

For markup that only makes sense in one style, use
`styles/<style_name>/template/event/<event>.html` instead of `styles/all/`.

ACP template events go under `adm/style/` in the extension.

### The syntax in templates

prosilver uses the legacy form:

```html
<!-- EVENT viewtopic_topic_title_before -->
```

The Twig form also works:

```twig
{% EVENT viewtopic_topic_title_before %}
```

`phpbb/template/twig/lexer.php` rewrites the legacy syntax into Twig before
compiling, so both are valid and both appear in real code. When adding an event
to your own templates, either is fine; match the surrounding file.

### Reading the catalogue

`docs/events.md` entries look like:

```
overall_header_breadcrumbs_after
===
* Locations:
    + styles/prosilver/template/navbar_header.html
* Since: 3.1.0-RC3
* Purpose: Add content after the breadcrumbs (outside of the breadcrumbs container)
```

`Locations:` (plural, with `+` lines) is the common form; `Location:` singular
appears in older entries. Both mean the same thing.

### Getting data into a template event

Template events see the template variables available at that point. To add your
own, assign them from a PHP listener on an event that fires while that page is
being built:

```php
$this->template->assign_vars(array(
	'MY_VALUE' => $something,
));
```

then use `{MY_VALUE}` or `{{ MY_VALUE }}` in the template event file.

### Adding an event to your own templates

An extension may declare template events in its own templates for other
extensions to hook. Document them the way core does, so they can be found.
