#!/bin/sh
# Connecteur Git clone : récupère un dépôt public dans /data/output/repo.
# « Profondeur » 0 = tout l'historique.
set -eu

: "${CAD_REPOSITORY:?adresse du dépôt manquante}"
case "$CAD_REPOSITORY" in https://*) ;; *) echo "L'adresse du dépôt doit commencer par https://" >&2; exit 2 ;; esac
DEPTH="${CAD_DEPTH:-1}"
case "$DEPTH" in ''|*[!0-9]*) echo "La profondeur doit être un nombre entier" >&2; exit 2 ;; esac
case "${CAD_REF:-}" in -*) echo "Branche ou étiquette invalide" >&2; exit 2 ;; esac

mkdir -p /data/output
rm -rf /data/output/repo

set -- clone --quiet
[ "$DEPTH" -gt 0 ] && set -- "$@" --depth "$DEPTH"
[ -n "${CAD_REF:-}" ] && set -- "$@" --branch "$CAD_REF"
# Jamais de demande de mot de passe : un dépôt privé échoue tout de suite, lisiblement
GIT_TERMINAL_PROMPT=0 git "$@" -- "$CAD_REPOSITORY" /data/output/repo

git -C /data/output/repo rev-parse HEAD | tr -d '\n' > /data/output/commit
