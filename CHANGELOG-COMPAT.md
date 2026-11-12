# CHANGELOG-COMPAT.md

Compatibility-only changes applied to **WP Edit 4.0.4** (original release:
2018-10-15, `https://downloads.wordpress.org/plugin/wp-edit.4.0.4.zip`).

Rules that were applied to every line below:

* **no feature added, no feature removed**;
* **no option added, renamed or removed**;
* **no user-visible text changed** (not one string literal, not one label);
* every corrected expression evaluates to **exactly the value PHP 7.x
  produced**, so the behaviour of the plugin is unchanged;
* end-of-line sequences (CRLF) and byte content of untouched files are
  preserved exactly.

Line numbers cited below are the line numbers **in the patched file published
in this repository**, so that every change can be located directly. The only
exceptions are quoted error messages and quotes from the original release,
which keep their own numbering and are labelled as such.

Only **two** files were modified:

| file | bytes changed | what |
|---|---|---|
| `wp-edit/includes/functions.php` | 9 lines | 8 guarded option reads + 1 `create_function()` |
| `wp-edit/main.php` | 12 lines + 1 block | 11 guarded option reads/writes + 1 fatal-error block |

Every other file of the official ZIP (78 of the 80 files: css, js, images,
langs, `plugins/`, `readme.txt`) is byte-for-byte identical to the original.

Verification of that claim:

```
$ diff -rq original/wp-edit fixed/wp-edit
Files original/wp-edit/includes/functions.php and fixed/wp-edit/includes/functions.php differ
Files original/wp-edit/main.php and fixed/wp-edit/main.php differ
```

---

## 1. `wp-edit/includes/functions.php`

### 1.1 Eight option reads that emit a PHP 8 warning (lines 11, 126, 135, 141, 147, 173, 231, 299)

`get_option()` returns `false` when the option does not exist yet. Reading an
array offset on `false` is a **Warning** on PHP 8.0+ ("Trying to access array
offset on false") where PHP 7 silently returned `null`.

The replacement `?? null` returns the same `null` that PHP 7 returned, without
emitting anything, so the comparison that follows gives the same result.

```diff
-$plugin_options_global = get_option('wp_edit_global');
-if($plugin_options_global['disable_admin_links'] != 1) {
+if(($plugin_options_global['disable_admin_links'] ?? null) != 1) {
```

The same change was applied to:

| line | expression |
|---|---|
| 11 | `$plugin_options_global['disable_admin_links']` |
| 126 | `$plugin_options_general['linebreak_shortcode']` |
| 135 | `$plugin_options_general['shortcodes_in_widgets']` |
| 141 | `$plugin_options_general['shortcodes_in_excerpts']` |
| 147 | `$plugin_options_general['post_excerpt_editor']` |
| 173 | `$plugin_options_general['page_excerpt_editor']` |
| 231 | `$plugin_options_general['profile_editor']` |
| 299 | `$plugin_options_posts['column_shortcodes']` |

**Proof (before / after).** These eight warnings fire on *every* activation,
because WordPress loads the plugin file before it runs the activation hook.
Original code, activation, `wp-content/debug.log`:

```
PHP Warning:  Trying to access array offset on value of type bool in
.../wp-content/plugins/wp-edit/includes/functions.php on line 11
... on line 126 / 135 / 141 / 147 / 173 / 231 / 299
```

Patched code, same activation: **0 line in `debug.log`**.

### 1.2 `create_function()` (line 772)

`create_function()` was **removed** in PHP 8.0: calling it is a fatal error.
The line is inside a branch that is only reached on PHP < 7 (the test is
`strnatcmp(phpversion(), '7.0.0') >= 0`), so on PHP 8 the branch is dead code
- but it is still shipped and would fatal on any old PHP, and `create_function`
is also flagged by every static analyser.

The branch is replaced by the **same closure as the branch right above it**
(same filter, same return value `'tmce'`), so nothing changes:

```diff
-add_filter( 'wp_default_editor', create_function('', 'return "tmce";') );
+add_filter( 'wp_default_editor', function() { return 'tmce'; } );
```

---

## 2. `wp-edit/main.php`

### 2.1 Option read used to select the jQuery UI theme (line 1179)

Same "array offset on false" warning; `?? null` keeps the same comparison
result and the same `selected="selected"` output.

```diff
-$selected = ($options_global['jquery_theme']==$jquery_theme) ? 'selected="selected"' : '';
+$selected = (($options_global['jquery_theme'] ?? null)==$jquery_theme) ? 'selected="selected"' : '';
```

### 2.2 Option write in `$db_buttons` (lines 2168-2169)

Writing into an option that is `false` is a **Deprecated** notice on PHP 8.1+
("Automatic conversion of false to array is deprecated"). PHP 7 auto-vivified
`false` into an array, so the final value was the same. The option is
normalised to an array first, and the missing key is read as `''`:

```diff
 $db_buttons = get_option('wp_edit_buttons');
-$db_buttons['tmce_container'] = $db_buttons['tmce_container'].$each_button;
+if ( ! is_array( $db_buttons ) ) { $db_buttons = array(); }
+$db_buttons['tmce_container'] = ( $db_buttons['tmce_container'] ?? '' ).$each_button;
```

### 2.3 `foreach()` over an option that may be `false` (line 2193)

```diff
 $options_buttons = get_option('wp_edit_buttons');
+if ( ! is_array( $options_buttons ) ) { $options_buttons = array(); }
```

### 2.4 Five option writes (lines 2285, 2317, 2420, 2459, 2493)

`$options_global`, `$options_general`, `$options_posts`, `$options_editor` and
`$options_extras` are written key by key. Each one is normalised to an array
before the writes, which is exactly what PHP 7 did silently:

```diff
 $options_global = get_option('wp_edit_global');
+if ( ! is_array( $options_global ) ) { $options_global = array(); }
```

(idem for `general`, `posts`, `editor`, `extras`).

### 2.5 `explode()` on a missing key (line 2924)

`explode(' ', null)` is deprecated since PHP 8.1. The key is read with
`?? ''`, which is the value PHP 7 used.

```diff
-$final_options = array_merge(explode(' ', $options_buttons['toolbar1']), explode(' ', $options_buttons['toolbar2']));
+$final_options = array_merge(explode(' ', ( $options_buttons['toolbar1'] ?? '' )), explode(' ', ( $options_buttons['toolbar2'] ?? '' )));
```

### 2.6 Toolbar 1 and toolbar 2 read in the mce filters (lines 3004, 3050)

```diff
-$options_toolbar1 = $options['toolbar1'];
+$options_toolbar1 = ( $options['toolbar1'] ?? '' );
```
(idem for `toolbar2` on line 3050).

### 2.7 The "User Specific" settings form - **fatal error** (lines 2527-2549)

This is the only place where the plugin does not just warn but **kills the
request** on PHP 8:

```
Uncaught TypeError: Cannot access offset of type string on string in
.../wp-content/plugins/wp-edit/main.php on line 2521
```

`get_user_meta( $id, 'aaa_wp_edit_user_meta', true )` returns `''` (a string)
when the meta does not exist yet. Writing `$meta['id_column'] = ...` into a
string is a `TypeError` on PHP 8. On PHP 7 it was a warning ("Cannot use a
scalar value as an array") and **the written values were silently lost**, so
the "User Specific" tab had never been able to save anything on a fresh
install.

The values are now collected in a temporary array and merged into the stored
value **only when the stored value is an array** - which reproduces the PHP 7
outcome in every case (array stored: the values are merged; anything else:
the stored value is left as it was, exactly like PHP 7 did).

```diff
 $options_user_specific_user_meta = get_user_meta($current_user->ID, 'aaa_wp_edit_user_meta', true);
-$options_user_specific_user_meta['id_column'] = isset($post_vars['id_column']) ? '1' : '0';
+// PHP 8 : ecrire dans un offset de chaine est une TypeError fatale.
+// Les valeurs sont donc rassemblees dans un tableau temporaire, puis
+// fusionnees dans la valeur stockee uniquement si celle-ci est un
+// tableau - exactement ce que faisait PHP 7 (les ecritures etaient
+// silencieusement perdues dans le cas contraire).
+$wpe_user_specific_writes = array();
+$wpe_user_specific_writes['id_column'] = isset($post_vars['id_column']) ? '1' : '0';
 ... (11 keys)
+if ( is_array( $options_user_specific_user_meta ) ) {
+	$options_user_specific_user_meta = array_merge( $options_user_specific_user_meta, $wpe_user_specific_writes );
+}
 update_user_meta($current_user->ID, 'aaa_wp_edit_user_meta', $options_user_specific_user_meta);
```

The eleven keys are unchanged (`id_column`, `thumbnail_column`,
`hide_text_tab`, `default_visual_tab`, `dashboard_widget`,
`enable_highlights`, `draft_highlight`, `pending_highlight`,
`published_highlight`, `future_highlight`, `private_highlight`), and the
confirmation message "User specific options saved." is unchanged.

**Proof (before / after).** Saving the "User Specific" tab:

* original code: **HTTP 500**, page "There has been a critical error on this
  website.", server log `Uncaught TypeError: Cannot access offset of type
  string on string`;
* patched code: **HTTP 200**, the confirmation "User specific options saved."
  is displayed, nothing in `debug.log`.

---

## 3. Known issues that were found but deliberately **not** changed

The consigne for this fork is "compatibility only, nothing else". The points
below are outside that scope; they are listed here so that nobody mistakes
this fork for a full modernisation of the plugin.

1. **`readme.txt` still says `Tested up to: 4.9.8`** while the plugin directory
   page reports `tested up to 4.9.35`. The readme of the original release was
   kept byte-for-byte; changing it would change the wording of the plugin.
2. **`wp-edit/plugins/advlink/advlink.php` loads jQuery over plain HTTP**
   (`http://code.jquery.com/jquery-1.11.0.min.js`). That is a transport issue,
   not a PHP 8 / WordPress 7.1 compatibility issue, and fixing it would change
   the behaviour of the plugin.
3. **The plugin still targets the classic (TinyMCE 4) editor.** WordPress 6.8
   and 7.1 still ship TinyMCE 4, so the plugin still works; a block-editor
   version is a feature, not a compatibility fix.
4. **No `LICENSE` file was shipped in the original 4.0.4 ZIP**, although
   `main.php` declares `License: GPL2` and `readme.txt` declares
   `License: GPLv2 or later`. The `LICENSE` file of this repository supplies
   the GNU General Public License version 2, unchanged and in full. The
   plugin's own header files were not touched.

---

## 4. Test matrix that was run

See `tests/README.md` and `tests/results/`.

| variant | WordPress | PHP | result |
|---|---|---|---|
| original 4.0.4 | 6.8.12 | 8.3.29 | RED |
| original 4.0.4 | 6.8.12 | 8.5.8 | RED |
| original 4.0.4 | 7.1.4  | 8.3.29 | RED |
| original 4.0.4 | 7.1.4  | 8.5.8 | RED |
| patched 4.0.4 | 6.8.12 | 8.3.29 | GREEN |
| patched 4.0.4 | 6.8.12 | 8.5.8 | GREEN |
| patched 4.0.4 | 7.1.4  | 8.3.29 | GREEN |
| patched 4.0.4 | 7.1.4  | 8.5.8 | GREEN |

The RED/GREEN pair is the counter-proof required for a test to prove
anything: the same harness, the same WordPress and the same PHP fail on the
original code and pass on the patched code.
