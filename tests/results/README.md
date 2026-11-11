# Raw results of the test runs

These are the unmodified outputs of the eight runs made on **2026-11-11** with
the harness of this repository.

```
$WPE_BASE/tests/run-case.sh <original|fixed> <wp-6.8.12|wp-7.1.4> <8.3.29|8.5.8>
```

| file | content |
|---|---|
| `matrice.txt` | the complete console output of the eight runs, in order |
| `<case>/resultats.txt` | the seven verdicts of one case (`VERT`/`ROUGE` + detail) |
| `<case>/server.log` | the log of the PHP built-in web server: the HTTP status of every request, and the fatal error of the original code |
| `<case>/debug.log.plugin-only.txt` | the lines of `wp-content/debug.log` that come from the plugin itself (empty for the patched code) |

## The counter-proof, in two lines

```
$ grep -h 'Uncaught' results/original-*/server.log
[...]: [500]: POST /wp-admin/admin.php?page=wp_edit_options&tab=user_specific - Uncaught TypeError: Cannot access offset of type string on string in .../wp-content/plugins/wp-edit/main.php:2521
```

```
$ wc -l results/*/debug.log.plugin-only.txt
  10 results/original-wp-6.8.12-8.3.29/debug.log.plugin-only.txt
  10 results/original-wp-6.8.12-8.5.8/debug.log.plugin-only.txt
  10 results/original-wp-7.1.4-8.3.29/debug.log.plugin-only.txt
  10 results/original-wp-7.1.4-8.5.8/debug.log.plugin-only.txt
   0 results/fixed-wp-6.8.12-8.3.29/debug.log.plugin-only.txt
   0 results/fixed-wp-6.8.12-8.5.8/debug.log.plugin-only.txt
   0 results/fixed-wp-7.1.4-8.3.29/debug.log.plugin-only.txt
   0 results/fixed-wp-7.1.4-8.5.8/debug.log.plugin-only.txt
```

The 10 lines of the original code are the 8 PHP warnings of
`includes/functions.php` (lines 11, 126, 135, 141, 147, 173, 231, 299) plus
the fatal error of `main.php` line 2521 and its stack trace. The patched code
produces **none** of them, on the four WordPress/PHP combinations.
