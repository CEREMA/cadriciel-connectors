#!/bin/sh
# Connecteur SFTP. Le serveur vient des variables CAD_SFTP_* (identifiant) ; elles deviennent la
# destination « sftp: » de rclone, que l'utilisateur emploie dans ses commandes. Le mot de passe
# et la clé ne passent que par l'environnement, jamais par la ligne de commande.
set -eu

: "${CAD_COMMANDS:?commandes manquantes}"
: "${CAD_SFTP_HOST:?hôte manquant}"
: "${CAD_SFTP_USER:?utilisateur manquant}"
PORT="${CAD_SFTP_PORT:-22}"
case "$PORT" in ''|*[!0-9]*) echo "Le port doit être un nombre entier" >&2; exit 2 ;; esac
if [ -z "${CAD_SFTP_PASSWORD:-}" ] && [ -z "${CAD_SFTP_KEY:-}" ]; then
  echo "L'identifiant ne donne ni mot de passe ni clé privée" >&2; exit 2
fi

# Toute la configuration vient de l'environnement ; un fichier vide évite l'avis « introuvable »
export RCLONE_CONFIG=/tmp/rclone.conf
: > "$RCLONE_CONFIG"
export RCLONE_CONFIG_SFTP_TYPE=sftp
export RCLONE_CONFIG_SFTP_HOST="$CAD_SFTP_HOST"
export RCLONE_CONFIG_SFTP_USER="$CAD_SFTP_USER"
export RCLONE_CONFIG_SFTP_PORT="$PORT"
# rclone attend un mot de passe « obscurci » dans sa configuration
if [ -n "${CAD_SFTP_PASSWORD:-}" ]; then
  RCLONE_CONFIG_SFTP_PASS=$(rclone obscure "$CAD_SFTP_PASSWORD"); export RCLONE_CONFIG_SFTP_PASS
fi
if [ -n "${CAD_SFTP_KEY:-}" ]; then export RCLONE_CONFIG_SFTP_KEY_PEM="$CAD_SFTP_KEY"; fi

mkdir -p /data/output
SCRIPT=/tmp/cad-commands.sh
printf '%s\n' "$CAD_COMMANDS" > "$SCRIPT"
exec sh -e "$SCRIPT"
