#!/bin/sh
# Connecteur MediaInfo : rend en JSON les caractéristiques d'un fichier.
# L'outil est installé au lancement (quelques secondes) : l'image de base ne l'embarque pas.
set -eu

: "${CAD_FILE:?fichier manquant}"
case "$CAD_FILE" in /data/*) ;; *) echo "Le fichier doit se trouver sous /data/" >&2; exit 2 ;; esac
case "$CAD_FILE" in *..*) echo "Chemin de fichier invalide" >&2; exit 2 ;; esac
[ -f "$CAD_FILE" ] || { echo "Fichier introuvable : $CAD_FILE" >&2; exit 2; }

apk add --no-cache --quiet mediainfo >/dev/null
mkdir -p /data/output
mediainfo --Output=JSON "$CAD_FILE" > /data/output/info.json
