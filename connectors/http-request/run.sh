#!/bin/sh
# Connecteur Requête HTTP. Les options de curl sont écrites dans un fichier de configuration :
# aucune valeur saisie par l'utilisateur n'est interprétée par le shell.
#
# CAD_HEADERS : une paire par ligne, « Nom: valeur » (c'est ainsi que la plateforme transmet un
# paramètre de type « pairs »).
set -eu

: "${CAD_URL:?adresse manquante}"
METHOD="${CAD_METHOD:-GET}"
TIMEOUT="${CAD_TIMEOUT:-30}"
case "$METHOD" in GET|POST|PUT|PATCH|DELETE) ;; *) echo "Méthode inconnue : $METHOD" >&2; exit 2 ;; esac
case "$TIMEOUT" in ''|*[!0-9]*) echo "Le délai doit être un nombre entier" >&2; exit 2 ;; esac
case "$CAD_URL" in http://*|https://*) ;; *) echo "L'adresse doit commencer par http:// ou https://" >&2; exit 2 ;; esac

OUT="${CAD_OUTPUT_DIR:-/data/output}"
mkdir -p "$OUT"
CONF=$(mktemp)
BODY=$(mktemp)
trap 'rm -f "$CONF" "$BODY"' EXIT

# Échappe une valeur pour un fichier de configuration curl (entre guillemets doubles)
quote() { printf '%s' "$1" | tr -d '\r\n' | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'; }

{
  printf 'url = "%s"\n' "$(quote "$CAD_URL")"
  printf 'request = "%s"\n' "$METHOD"
  printf 'max-time = %s\n' "$TIMEOUT"
  if [ -n "${CAD_AUTH_NAME:-}" ] && [ -n "${CAD_AUTH_VALUE:-}" ]; then
    printf 'header = "%s: %s"\n' "$(quote "$CAD_AUTH_NAME")" "$(quote "$CAD_AUTH_VALUE")"
  fi
} > "$CONF"

if [ -n "${CAD_HEADERS:-}" ]; then
  printf '%s\n' "$CAD_HEADERS" | while IFS= read -r line; do
    case "$line" in *:*) printf 'header = "%s"\n' "$(quote "$line")" >> "$CONF" ;; esac
  done
fi

case "$METHOD" in
  POST|PUT|PATCH)
    printf '%s' "${CAD_BODY:-}" > "$BODY"
    printf 'data-binary = "@%s"\n' "$BODY" >> "$CONF"
    ;;
esac

STATUS=$(curl -sS --config "$CONF" -o "$OUT/body" -w '%{http_code}')
printf '%s' "$STATUS" > "$OUT/status"

if [ "${CAD_FAIL_ON_ERROR:-true}" = "true" ] && [ "$STATUS" -ge 400 ]; then
  echo "Le serveur a répondu $STATUS" >&2
  head -c 2000 "$OUT/body" >&2 || true
  exit 22
fi
