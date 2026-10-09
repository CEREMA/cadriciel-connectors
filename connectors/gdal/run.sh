#!/bin/sh
# Connecteur à commandes : exécute, ligne après ligne, les commandes écrites par l'utilisateur dans
# le réglage « Commandes ». Elles tournent dans SON pod, avec l'image du connecteur ; la première
# qui échoue arrête l'étape.
set -eu

: "${CAD_COMMANDS:?commandes manquantes}"
mkdir -p /data/output
SCRIPT=$(mktemp)
printf '%s\n' "$CAD_COMMANDS" > "$SCRIPT"
exec sh -e "$SCRIPT"
