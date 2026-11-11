#!/usr/bin/env bash
# =============================================================================
# run-case.sh - UN cas de test : (variante) x (WordPress) x (PHP)
#
#   usage : run-case.sh <original|fixed> <wp-7.1.4|wp-6.8.12> <8.3.29|8.5.8>
#
# Sortie : une ligne "Rouge"/"Vert" par test + un verdict final.
# Code de sortie 0 = tout vert, 1 = au moins un test rouge.
# =============================================================================
set -uo pipefail
BASE=${WPE_BASE:-/work/wp/reprise/wp-edit}
source "$BASE/tests/lib.sh"

VARIANT="$1"; ENVN="$2"; PHPV="$3"
ENVDIR="$BASE/env/$ENVN"
PORT=$(env_port "$ENVN")
LOGDIR="$BASE/logs/$VARIANT-$ENVN-$PHPV"
mkdir -p "$LOGDIR"

PASS=0; FAIL=0
declare -a RESULTS=()

say()  { printf '%s\n' "$*"; }
res()  { # res <etat> <nom> <detail>
  if [ "$1" = "VERT" ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fi
  RESULTS+=("$1 | $2 | $3")
  printf '%-6s %-42s %s\n' "$1" "$2" "$3"
}

diag_now() { count_diagnostics "$ENVDIR"; }

# -----------------------------------------------------------------------------
say "=============================================================="
say "CAS : $VARIANT / WordPress $ENVN / PHP $PHPV"
say "=============================================================="

# --- preparation ------------------------------------------------------------
reset_env "$ENVDIR" "$PHPV"
if [ ! -f "$ENVDIR/wordpress/wp-content/database/wpenv.sqlite" ]; then
  res ROUGE "T0 preparation" "la base n'a pas ete reinstallee"
  say "VERDICT : ROUGE"
  exit 1
fi
cp -a "$BASE/$VARIANT/wp-edit" "$ENVDIR/wordpress/wp-content/plugins/wp-edit"

# --- T1 : activation --------------------------------------------------------
BEFORE=$(diag_now)
OUT=$(wp "$ENVDIR" "$PHPV" plugin activate wp-edit 2>&1); RC=$?
AFTER=$(diag_now)
DETAIL=$(plugin_diagnostics "$ENVDIR" | sed 's/.*plugins\/wp-edit\///' | head -3 | tr '\n' ';')
if [ "$RC" -ne 0 ]; then
  res ROUGE "T1 activation" "wp-cli a rendu $RC : $(echo "$OUT" | head -2 | tr '\n' ' ')"
elif echo "$OUT" | grep -qiE 'fatal error|parse error|uncaught'; then
  res ROUGE "T1 activation" "erreur fatale : $(echo "$OUT" | grep -iE 'fatal|uncaught' | head -1)"
elif [ "$AFTER" -gt "$BEFORE" ]; then
  res ROUGE "T1 activation" "$((AFTER-BEFORE)) diagnostic(s) : $DETAIL"
else
  res VERT "T1 activation" "aucune erreur fatale, 0 diagnostic"
fi
echo "$OUT" > "$LOGDIR/activation.txt"

# --- preparation du contenu de test ----------------------------------------
POST_ID=$(wp "$ENVDIR" "$PHPV" post create --post_title="Compatibilite WP Edit" \
  --post_status=publish --post_content="Texte d origine." --porcelain 2>/dev/null | tr -d '\r\n')
[ -n "$POST_ID" ] || POST_ID=$(wp "$ENVDIR" "$PHPV" post list --post_type=post --posts_per_page=1 --field=ID --format=ids 2>/dev/null | tr -d '\r\n' | awk '{print $1}')
say "POST_ID = [$POST_ID]"

# --- serveur web ------------------------------------------------------------
if ! start_server "$ENVDIR" "$PHPV"; then
  res ROUGE "T2 serveur HTTP" "le serveur ne repond pas sur le port $PORT"
  say "VERDICT : ROUGE"; exit 1
fi
COOKIE=$(login_cookie "$ENVDIR" "$PHPV")
PERMALINK=$(wp "$ENVDIR" "$PHPV" post get "$POST_ID" --field=url 2>/dev/null | tr -d '\r\n')
[ -n "$PERMALINK" ] || PERMALINK="http://127.0.0.1:$PORT/?p=$POST_ID"

# --- T3 : affichage de l'article sur le front -------------------------------
BEFORE=$(diag_now)
CODE=$(curl -s -o "$LOGDIR/front.html" -w '%{http_code}' "$PERMALINK" --max-time 45)
AFTER=$(diag_now)
DETAIL=$(plugin_diagnostics "$ENVDIR" | sed 's/.*plugins\/wp-edit\///' | head -3 | tr '\n' ';')
if [ "$CODE" != "200" ]; then
  res ROUGE "T3 article sur le front" "HTTP $CODE"
elif grep -qiE 'fatal error|uncaught (exception|error)' "$LOGDIR/front.html"; then
  res ROUGE "T3 article sur le front" "erreur fatale dans la page"
elif [ "$AFTER" -gt "$BEFORE" ]; then
  res ROUGE "T3 article sur le front" "$((AFTER-BEFORE)) diagnostic(s) : $DETAIL"
else
  res VERT "T3 article sur le front" "HTTP 200, 0 diagnostic"
fi

# --- T4 : ecran d'edition (admin) ------------------------------------------
# Le plugin fait UNE redirection apres activation (option
# wp_edit_activation_redirect -> admin.php?page=wp_edit_options). Ce
# comportement existe dans le code d'origine ET dans le code corrige : on le
# laisse passer, puis on exige un 200 sur la requete suivante.
BEFORE=$(diag_now)
EDITURL="http://127.0.0.1:$PORT/wp-admin/post.php?post=$POST_ID&action=edit"
CODE=$(curl -s -b "$COOKIE" -o "$LOGDIR/edit.html" -w '%{http_code}\n%{redirect_url}' \
       "$EDITURL" --max-time 60)
HTTP=$(echo "$CODE" | head -1); LOC=$(echo "$CODE" | tail -1)
NOTE=""
if [ "$HTTP" = "302" ] && echo "$LOC" | grep -q 'page=wp_edit_options'; then
  NOTE=" (1re requete : 302 de redirection post-activation)"
  CODE=$(curl -s -b "$COOKIE" -o "$LOGDIR/edit.html" -w '%{http_code}\n%{redirect_url}' \
         "$EDITURL" --max-time 60)
  HTTP=$(echo "$CODE" | head -1); LOC=$(echo "$CODE" | tail -1)
fi
AFTER=$(diag_now)
DETAIL=$(plugin_diagnostics "$ENVDIR" | sed 's/.*plugins\/wp-edit\///' | head -3 | tr '\n' ';')
if [ "$HTTP" != "200" ]; then
  res ROUGE "T4 ecran d'edition" "HTTP $HTTP -> $LOC"
elif grep -qiE 'fatal error|uncaught (exception|error)|critical error' "$LOGDIR/edit.html"; then
  res ROUGE "T4 ecran d'edition" "erreur fatale dans la page"
elif [ "$AFTER" -gt "$BEFORE" ]; then
  res ROUGE "T4 ecran d'edition" "$((AFTER-BEFORE)) diagnostic(s) : $DETAIL"
else
  res VERT "T4 ecran d'edition" "HTTP 200, 0 diagnostic$NOTE"
fi

# --- T5 : enregistrement de l'article ---------------------------------------
# La page d'edition contient plusieurs champs _wpnonce (deconnexion WordPress,
#/widgets, ...). On essaie chaque nonce jusqu'a ce que l'enregistrement
# fonctionne reellement (verifie ensuite dans la base).
BEFORE=$(diag_now)
NEWCONTENT="Contenu enregistre par le harnais de test."
SAVED=""
CODE=000
for N in $(grep -oP 'name="_wpnonce"[^>]*value="\K[a-f0-9]+' "$LOGDIR/edit.html" | tac); do
  CODE=$(curl -s -b "$COOKIE" -o "$LOGDIR/save.html" -w '%{http_code}' \
    --data-urlencode "action=editpost" \
    --data-urlencode "post_ID=$POST_ID" \
    --data-urlencode "post_type=post" \
    --data-urlencode "post_title=Compatibilite WP Edit" \
    --data-urlencode "content=$NEWCONTENT" \
    --data-urlencode "original_post_status=publish" \
    --data-urlencode "originalaction=editpost" \
    --data-urlencode "post_author=1" \
    --data-urlencode "hidden_post_status=publish" \
    --data-urlencode "hidden_post_visibility=public" \
    --data-urlencode "_wpnonce=$N" \
    --data-urlencode "_wp_http_referer=/wp-admin/post.php?post=$POST_ID&action=edit" \
    "http://127.0.0.1:$PORT/wp-admin/post.php" --max-time 60)
  SAVED=$(wp "$ENVDIR" "$PHPV" post get "$POST_ID" --field=post_content 2>/dev/null | tr -d '\r\n')
  echo "$SAVED" | grep -q "enregistre par le harnais" && break
done
AFTER=$(diag_now)
DETAIL=$(plugin_diagnostics "$ENVDIR" | sed 's/.*plugins\/wp-edit\///' | head -3 | tr '\n' ';')
if [ "$CODE" != "200" ] && [ "$CODE" != "302" ]; then
  res ROUGE "T5 enregistrement de l'article" "HTTP $CODE"
elif echo "$SAVED" | grep -q "enregistre par le harnais"; then
  if [ "$AFTER" -gt "$BEFORE" ]; then
    res ROUGE "T5 enregistrement de l'article" "enregistre mais $((AFTER-BEFORE)) diagnostic(s) : $DETAIL"
  else
    res VERT "T5 enregistrement de l'article" "contenu enregistre, 0 diagnostic"
  fi
else
  res ROUGE "T5 enregistrement de l'article" "le contenu n'a pas ete enregistre (HTTP $CODE)"
fi

# --- T6 : pages de reglages du plugin ---------------------------------------
BEFORE=$(diag_now)
BAD=""
for TAB in buttons global general posts editor extras user_specific database about; do
  CODE=$(curl -s -b "$COOKIE" -o "$LOGDIR/tab-$TAB.html" -w '%{http_code}' \
         "http://127.0.0.1:$PORT/wp-admin/admin.php?page=wp_edit_options&tab=$TAB" --max-time 60)
  [ "$CODE" = "200" ] || BAD="$BAD $TAB:$CODE"
  grep -qiE 'fatal error|uncaught (exception|error)' "$LOGDIR/tab-$TAB.html" && BAD="$BAD $TAB:fatal"
done
AFTER=$(diag_now)
DETAIL=$(plugin_diagnostics "$ENVDIR" | sed 's/.*plugins\/wp-edit\///' | head -3 | tr '\n' ';')
if [ -n "$BAD" ]; then
  res ROUGE "T6 pages de reglages" "HTTP non 200 :$BAD"
elif [ "$AFTER" -gt "$BEFORE" ]; then
  res ROUGE "T6 pages de reglages" "$((AFTER-BEFORE)) diagnostic(s) : $DETAIL"
else
  res VERT "T6 pages de reglages" "9 onglets HTTP 200, 0 diagnostic"
fi

# --- T7 : enregistrement des reglages (le cas fatal) ------------------------
# Chaque onglet a son propre formulaire et son propre nonce. On essaie
# chaque nonce de la page jusqu'a obtenir le message de confirmation : ce
# n'est qu'alors que le code de enregistrement a reellement tourne.
#
# Une erreur fatale PHP se manifeste par : HTTP 500, une page "There has been
# a critical error on this website.", et/ou une ligne "Uncaught ..." dans le
# log du serveur. On teste les trois.
BEFORE=$(diag_now)
FATALS=0; OKSAVES=0; BAD=""; FATAL_MSG=""
for TAB in global general posts editor extras user_specific; do
  F="$LOGDIR/tab-$TAB.html"
  case "$TAB" in
    global)        SUBMIT="submit_global"        ;;
    general)       SUBMIT="submit_general"       ;;
    posts)         SUBMIT="submit_posts"         ;;
    editor)        SUBMIT="submit_editor"        ;;
    extras)        SUBMIT="submit_extras"        ;;
    user_specific) SUBMIT="submit_user_specific" ;;
  esac
  DONE=0
  for N in $(grep -oP 'name="_wpnonce"[^>]*value="\K[a-f0-9]+' "$F" | tac); do
    LOGSZ=$(wc -c < "$ENVDIR/server.log" 2>/dev/null || echo 0)
    CODE=$(curl -s -b "$COOKIE" -o "$LOGDIR/save-$TAB.html" -w '%{http_code}' \
      --data-urlencode "$SUBMIT=1" \
      --data-urlencode "_wpnonce=$N" \
      --data-urlencode "_wp_http_referer=/wp-admin/admin.php?page=wp_edit_options&tab=$TAB" \
      "http://127.0.0.1:$PORT/wp-admin/admin.php?page=wp_edit_options&tab=$TAB" --max-time 60)
    NEWLOG=$(tail -c "+$((LOGSZ+1))" "$ENVDIR/server.log" 2>/dev/null || true)
    if [ "$CODE" = "500" ] \
       || grep -qiE 'Fatal error|Uncaught (TypeError|Error)|critical error on this website' "$LOGDIR/save-$TAB.html" \
       || echo "$NEWLOG" | grep -qE 'Uncaught (TypeError|Error)|PHP Fatal error'; then
      FATALS=$((FATALS+1)); DONE=1
      BAD="$BAD $TAB:fatale"
      [ -n "$FATAL_MSG" ] || FATAL_MSG=$(echo "$NEWLOG" | grep -oE 'Uncaught (TypeError|Error)[^$]*' | head -1)
      break
    fi
    if grep -qiE 'options (successfully )?saved|saved successfully' "$LOGDIR/save-$TAB.html"; then
      OKSAVES=$((OKSAVES+1)); DONE=1
      break
    fi
  done
  [ "$DONE" -eq 1 ] || BAD="$BAD $TAB:pas-de-confirmation"
done
AFTER=$(diag_now)
DETAIL=$(plugin_diagnostics "$ENVDIR" | sed 's/.*plugins\/wp-edit\///' | head -3 | tr '\n' ';')
if [ "$FATALS" -gt 0 ]; then
  res ROUGE "T7 enregistrement des reglages" "$FATALS erreur(s) fatale(s) :$BAD | ${FATAL_MSG:0:120}"
elif [ -n "$BAD" ]; then
  res ROUGE "T7 enregistrement des reglages" "$OKSAVES/6 enregistres :$BAD"
elif [ "$AFTER" -gt "$BEFORE" ]; then
  res ROUGE "T7 enregistrement des reglages" "$((AFTER-BEFORE)) diagnostic(s) : $DETAIL"
else
  res VERT "T7 enregistrement des reglages" "6 formulaires enregistres, 0 diagnostic"
fi

stop_server "$ENVDIR"

# --- conservation des preuves ------------------------------------------------
# Le log du serveur HTTP et le log de debug de WordPress sont copies dans le
# dossier du cas : ils sont ecrases au cas suivant (meme environnement).
cp -f "$ENVDIR/server.log" "$LOGDIR/server.log" 2>/dev/null || true
cp -f "$ENVDIR/wordpress/wp-content/debug.log" "$LOGDIR/debug.log" 2>/dev/null || true

# --- verdict ----------------------------------------------------------------
say ""
say "RESULTATS : $PASS vert(s), $FAIL rouge(s)"
printf '%s\n' "${RESULTS[@]}" > "$LOGDIR/resultats.txt"
if [ "$FAIL" -eq 0 ]; then
  say "VERDICT : VERT"
  exit 0
else
  say "VERDICT : ROUGE"
  exit 1
fi
