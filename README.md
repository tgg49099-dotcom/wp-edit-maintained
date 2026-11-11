WP Edit - compatibility fork by Tgg Labs (unofficial)

This repository is an UNOFFICIAL compatibility fork of "WP Edit" by Josh
(https://profiles.wordpress.org/josh401/), original plugin page
https://wordpress.org/plugins/wp-edit/, original site https://wpeditpro.com.

The original plugin's licence (GPL-2.0-or-later) and its copyright notice are kept
unchanged; see LICENSE. We are not the original author and we do not sell this
plugin. The commercial "WP Edit PRO" remains the property of its author.

What we changed: compatibility only (PHP 8.3/8.5, WordPress 6.8/7.1). No feature, no
option and no user-visible text was changed. The list of changes is in
CHANGELOG-COMPAT.md, with the tests we ran in tests/.

Why: the last public release is 4.0.4 (October 2018) and the plugin is marked as
tested up to WordPress 4.9.35, so it no longer runs on current WordPress and PHP
versions. If the original author prefers to maintain the plugin himself, this
repository and these patches are his to use.

---

## Who does what

| | |
|---|---|
| Original plugin, all features, all wording, copyright | **Josh** (Josh Lobe) - https://profiles.wordpress.org/josh401/ - https://wpeditpro.com |
| Commercial "WP Edit PRO" | **Josh** - https://wpeditpro.com |
| This repository: PHP 8 / WordPress 6.8-7.1 compatibility patches, test harness, packaging | **Tgg Labs** (https://github.com/tgg49099-dotcom) - unofficial, free, no paid tier |
| WordPress.org plugin directory, its slug `wp-edit`, its page, its reviews, its SVN | **unchanged, still Josh's** - this repository is not published there |

Nothing here is submitted to the WordPress.org plugin directory. The plugin slug
`wp-edit` on wordpress.org is untouched by us.

## Repository layout

```
wp-edit/               the plugin, patched for compatibility (WP Edit 4.0.4)
tests/                 the test harness we used, and the raw output of the runs
CHANGELOG-COMPAT.md    every change we made, file by file, with the reason
NOTICE                 authorship, attribution and licensing notice
LICENSE                the GNU General Public License v2 (the plugin's own licence)
```

The `wp-edit/` directory is the plugin itself and can be zipped and installed as
a normal WordPress plugin (main folder name must stay `wp-edit`). Apart from the
two PHP files listed in `CHANGELOG-COMPAT.md`, every file of the original
release is byte-for-byte identical to the official WordPress.org ZIP
(`wp-edit.4.0.4.zip`).

## What we changed, in one paragraph

Only two files were touched: `wp-edit/main.php` and `wp-edit/includes/functions.php`.
The changes are (a) guarding reads of WordPress options that may be missing, so
PHP 8.3/8.5 no longer emit "Trying to access array offset on false" or
"Automatic conversion of false to array is deprecated", and (b) making the
"User Specific" settings form save without the PHP 8 fatal error
`TypeError: Cannot access offset of type string on string`. No feature was
added, no feature was removed, no option was renamed, no user-visible text was
changed, and the saved values are exactly the ones PHP 7 stored. See
`CHANGELOG-COMPAT.md`.

## Tests

The harness in `tests/` installs a real WordPress (6.8.12 or 7.1.4) with the
SQLite database integration, activates the plugin, opens the front end and the
editor, saves a post, opens the nine settings tabs, and saves each of the six
settings forms - then checks that nothing was written to `wp-content/debug.log`
by the plugin and that no request ended in a fatal error.

The same harness is run against the **original** code and against the
**patched** code: the original fails (8 PHP warnings at activation, plus a
fatal error when saving the "User Specific" tab), the patched code passes.
The raw output of the eight runs is in `tests/results/`.

```
tests/run-case.sh <original|fixed> <wp-6.8.12|wp-7.1.4> <8.3.29|8.5.8>
```

See `tests/README.md` for the prerequisites and for how to reproduce the runs.
