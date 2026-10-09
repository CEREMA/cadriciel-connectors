#!/bin/sh
# Connecteur Géocodage : service de géocodage de la Géoplateforme (IGN), sans clé.
# Dans tous les cas le résultat est un fichier CSV : les lignes reçues, complétées des colonnes
# trouvées par le service. Aucune valeur saisie n'est interprétée, ni par le shell ni par curl :
# elles ne partent que comme champs littéraux du formulaire.
set -eu

BASE="${CAD_GEOCODE_URL:-https://data.geopf.fr/geocodage}"
OPERATION="${CAD_OPERATION:-address}"
TIMEOUT="${CAD_TIMEOUT:-120}"
case "$TIMEOUT" in ''|*[!0-9]*) echo "Le délai doit être un nombre entier" >&2; exit 2 ;; esac

OUT=/data/output
mkdir -p "$OUT"
RESULT="$OUT/adresses.csv"
WORK="${TMPDIR:-/tmp}/cad-geocodage.csv"

# Une colonne par ligne dans le fichier de configuration de curl. « form-string » et non « form » :
# avec « form », un nom commençant par @ ou < ferait envoyer par curl un fichier du pod.
CONF="${TMPDIR:-/tmp}/cad-geocodage.conf"
: > "$CONF"
add_columns() { # $1 = nom du champ du service, $2 = liste séparée par des virgules
  printf '%s' "$2" | tr ',' '\n' | while IFS= read -r column; do
    column=$(printf '%s' "$column" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
    [ -n "$column" ] || continue
    printf 'form-string = "%s=%s"\n' "$1" "$(printf '%s' "$column" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g')" >> "$CONF"
  done
}

case "$OPERATION" in
  address)
    : "${CAD_ADDRESS:?adresse manquante}"
    # Une adresse = un fichier d'une ligne ; les guillemets sont doublés, comme le veut le CSV
    printf 'adresse\n"%s"\n' "$(printf '%s' "$CAD_ADDRESS" | tr '\n' ' ' | sed 's/"/""/g')" > "$WORK"
    add_columns columns adresse
    ENDPOINT="$BASE/search/csv"
    ;;
  csv)
    FILE="${CAD_FILE:?fichier manquant}"
    [ -f "$FILE" ] || { echo "Fichier introuvable : $FILE" >&2; ls -la "$(dirname "$FILE")" >&2 || true; exit 2; }
    cp "$FILE" "$WORK"
    add_columns columns "${CAD_COLUMNS:?colonnes de l'adresse manquantes}"
    [ -z "${CAD_POSTCODE:-}" ] || add_columns postcode "$CAD_POSTCODE"
    [ -z "${CAD_CITYCODE:-}" ] || add_columns citycode "$CAD_CITYCODE"
    ENDPOINT="$BASE/search/csv"
    ;;
  reverse)
    FILE="${CAD_FILE:?fichier manquant}"
    [ -f "$FILE" ] || { echo "Fichier introuvable : $FILE" >&2; ls -la "$(dirname "$FILE")" >&2 || true; exit 2; }
    cp "$FILE" "$WORK"
    ENDPOINT="$BASE/reverse/csv"
    ;;
  *) echo "Opération inconnue : $OPERATION" >&2; exit 2 ;;
esac

STATUS=$(curl --silent --show-error --max-time "$TIMEOUT" --config "$CONF" \
  --form "data=@$WORK;type=text/csv" --output "$RESULT" --write-out '%{http_code}' "$ENDPOINT")
if [ "$STATUS" != "200" ]; then
  echo "Le service de géocodage a répondu $STATUS" >&2
  head -c 500 "$RESULT" >&2 || true
  exit 1
fi
# Nombre de lignes rendues, sans l'en-tête
awk 'END { print (NR > 0) ? NR - 1 : 0 }' "$RESULT" > "$OUT/count"
