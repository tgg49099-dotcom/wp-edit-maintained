# Tests

The harness in this folder installs **real WordPress** instances, activates the
plugin, and drives it over HTTP. It is the same harness that produced the
RED/GREEN counter-proof in `CHANGELOG-COMPAT.md`.

Nothing here is a mock: each run reinstalls WordPress from
`downloads.wordpress.org`, with the official SQLite database integration, and
serves it with the PHP built-in web server.

## Files

| file | role |
|---|---|
| `setup-env.sh` | downloads and installs a WordPress version (6.8.12 or 7.1.4) in an isolated folder, with the SQLite drop-in and a `wp-config.php` that turns `WP_DEBUG` and `WP_DEBUG_LOG` on |
| `lib.sh` | helpers: PHP binaries, WP-CLI wrapper, environment reset, diagnostics counter, authentication cookies, server start/stop |
| `run-case.sh` | one test case = (variant) x (WordPress) x (PHP) |
| `results/` | the raw output of the eight runs that were made on 2026-11-11 |

## What a case checks

| test | what it does | how it fails |
|---|---|---|
| T1 | activates the plugin | any line written by the plugin in `wp-content/debug.log`, or a fatal error |
| T3 | loads the article on the front end | HTTP != 200, a fatal error, or any new diagnostic |
| T4 | loads the post edit screen in wp-admin | HTTP != 200 (the one-time post-activation redirect of the plugin is tolerated and retried), a fatal error, or any new diagnostic |
| T5 | saves the article | the content is not really saved in the database, or any new diagnostic |
| T6 | opens the nine settings tabs | any non-200, a fatal error, or any new diagnostic |
| T7 | saves the six settings forms | a fatal error, a missing confirmation message, or any new diagnostic |

The "diagnostic" counter is the number of lines of `wp-content/debug.log`
that mention `wp-content/plugins/wp-edit/` - that is, every PHP warning,
notice and deprecation raised by the plugin itself. The harness ignores the
WordPress core and WP-CLI noise.

## Running it

Requirements:

* two PHP binaries, 8.3.29 and 8.5.8 (the paths are configurable);
* `wp-cli.phar`;
* `curl`;
* the `sqlite-database-integration` plugin folder, to be copied into
  `wp-content/plugins/`.

```bash
export WPE_BASE=/path/to/this/repository          # repository root
export WPE_WPCLI=/path/to/wp-cli.phar
export WPE_PHP_83=/path/to/php-8.3.29/bin/php
export WPE_PHP_85=/path/to/php-8.5.8/bin/php
export WPE_SQLITE_SRC=/path/to/sqlite-database-integration

bash tests/setup-env.sh 6.8.12 "$WPE_BASE/env/wp-6.8.12" http://127.0.0.1:8092
bash tests/setup-env.sh 7.1.4  "$WPE_BASE/env/wp-7.1.4"  http://127.0.0.1:8091

bash tests/run-case.sh original wp-6.8.12 8.3.29   # expected: RED
bash tests/run-case.sh fixed    wp-6.8.12 8.3.29   # expected: GREEN
```

`run-case.sh` expects the two plugin trees next to each other:

```
$WPE_BASE/original/wp-edit   the untouched 4.0.4 release
$WPE_BASE/fixed/wp-edit      the patched release
```

and the WordPress installs in `$WPE_BASE/env/wp-<version>/wordpress`.

Exit code is `0` when every test is green, `1` otherwise.

**Do not run two cases at the same time in the same checkout**: each case
reinstalls the database of the WordPress instance it uses, so two parallel
cases would fight over the same SQLite file.

## The counter-proof

The point of a compatibility test is that it can fail. The same harness, the
same WordPress version and the same PHP version are run against the original
release and against the patched release:

* **original**: 8 PHP warnings at activation, and a fatal `TypeError` when the
  "User Specific" tab is saved -> RED;
* **patched**: no warning, no fatal -> GREEN.

The raw outputs are in `results/`.
