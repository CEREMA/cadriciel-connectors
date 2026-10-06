#!/bin/sh
# Connecteur PostgreSQL. La connexion vient des variables PG* (identifiant), les réglages des
# variables CAD_*. Rien n'est lu sur la ligne de commande.
set -eu

: "${CAD_QUERY:?requête manquante}"
OPERATION="${CAD_OPERATION:-query}"
LIMIT="${CAD_LIMIT:-1000}"
case "$LIMIT" in ''|*[!0-9]*) echo "« Lignes au plus » doit être un nombre entier" >&2; exit 2 ;; esac

mkdir -p /data/output
export PGCONNECT_TIMEOUT="${PGCONNECT_TIMEOUT:-10}"

if [ "$OPERATION" = "query" ]; then
  # Le point-virgule final gênerait l'emploi de la requête comme sous-requête
  QUERY=$(printf '%s' "$CAD_QUERY" | sed -e 's/[[:space:]]*$//' -e 's/;$//')
  psql -X -q -v ON_ERROR_STOP=1 -At <<SQL
CREATE TEMP TABLE _cad_rows AS SELECT * FROM ($QUERY) AS _cad_query LIMIT $LIMIT;
\o /data/output/rows.json
SELECT coalesce(json_agg(t), '[]'::json) FROM _cad_rows t;
\o /data/output/count
SELECT count(*) FROM _cad_rows;
SQL
else
  if [ "${CAD_TRANSACTION:-true}" = "true" ]; then TX="--single-transaction"; else TX=""; fi
  # shellcheck disable=SC2086
  # Sans -q : c'est la ligne « UPDATE 3 » que psql écrit qui donne le nombre de lignes
  psql -X -v ON_ERROR_STOP=1 $TX -c "$CAD_QUERY" > /data/output/result.txt
  echo '[]' > /data/output/rows.json
  # « UPDATE 3 », « INSERT 0 2 », « DELETE 1 » : le dernier nombre est celui des lignes touchées
  awk 'END { n = $NF; print (n ~ /^[0-9]+$/) ? n : 0 }' /data/output/result.txt > /data/output/count
fi
