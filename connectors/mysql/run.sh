#!/bin/sh
# Connecteur MySQL. La connexion vient des variables CAD_MYSQL_* (identifiant), les réglages des
# variables CAD_*. Rien n'est lu sur la ligne de commande ; le mot de passe passe par
# l'environnement du client (MYSQL_PWD) ou son entrée standard, jamais par ses arguments.
set -eu

: "${CAD_QUERY:?requête manquante}"
: "${CAD_MYSQL_HOST:?hôte manquant}"
: "${CAD_MYSQL_USER:?utilisateur manquant}"
OPERATION="${CAD_OPERATION:-query}"
LIMIT="${CAD_LIMIT:-1000}"
PORT="${CAD_MYSQL_PORT:-3306}"
SSL="${CAD_MYSQL_SSLMODE:-PREFERRED}"
case "$LIMIT" in ''|*[!0-9]*) echo "« Lignes au plus » doit être un nombre entier" >&2; exit 2 ;; esac
case "$PORT" in ''|*[!0-9]*) echo "Le port doit être un nombre entier" >&2; exit 2 ;; esac

mkdir -p /data/output
export MYSQL_PWD="${CAD_MYSQL_PASSWORD:-}"
client() {
  mysql --host="$CAD_MYSQL_HOST" --port="$PORT" --user="$CAD_MYSQL_USER" --ssl-mode="$SSL" \
    --connect-timeout=10 --default-character-set=utf8mb4 --batch --skip-column-names ${CAD_MYSQL_DATABASE:+--database="$CAD_MYSQL_DATABASE"} "$@"
}

if [ "$OPERATION" = "query" ]; then
  # Le point-virgule final gênerait l'emploi de la requête comme sous-requête
  QUERY=$(printf '%s' "$CAD_QUERY" | sed -e 's/[[:space:]]*$//' -e 's/;$//')
  BOUNDED="SELECT * FROM ($QUERY) AS _cad_query LIMIT $LIMIT"
  # Le client classique ne sait pas rendre du JSON : c'est MySQL Shell qui écrit les lignes
  printf '%s\n' "$MYSQL_PWD" | mysqlsh --sql --passwords-from-stdin --result-format=json/array --quiet-start=2 \
    --host="$CAD_MYSQL_HOST" --port="$PORT" --user="$CAD_MYSQL_USER" --ssl-mode="$SSL" \
    ${CAD_MYSQL_DATABASE:+--schema="$CAD_MYSQL_DATABASE"} -e "$BOUNDED" > /tmp/cad-rows.raw
  # MySQL Shell écrit sa demande de mot de passe (en gras) sur la sortie, devant le résultat
  sed -e 's/\x1b\[[0-9;]*m//g' -e "1s/^Please provide the password for '[^']*': //" /tmp/cad-rows.raw > /data/output/rows.json
  [ -s /data/output/rows.json ] || echo '[]' > /data/output/rows.json
  client -e "SELECT count(*) FROM ($BOUNDED) AS _cad_count" > /data/output/count
else
  STATEMENT=$(printf '%s' "$CAD_QUERY" | sed -e 's/[[:space:]]*$//' -e 's/;$//')
  # ROW_COUNT() : les lignes touchées par la dernière instruction. Une erreur ferme la connexion
  # avant COMMIT : la transaction est alors abandonnée par le serveur.
  if [ "${CAD_TRANSACTION:-true}" = "true" ]; then
    client -e "START TRANSACTION; $STATEMENT; SELECT ROW_COUNT(); COMMIT;" > /data/output/result.txt
  else
    client -e "$STATEMENT; SELECT ROW_COUNT();" > /data/output/result.txt
  fi
  echo '[]' > /data/output/rows.json
  awk 'END { n = $NF; print (n ~ /^[0-9]+$/) ? n : 0 }' /data/output/result.txt > /data/output/count
fi
