#!/bin/sh
# Connecteur Docker build. Demande un pod privilégié (moteur Docker dans le pod) : la plateforme
# peut refuser de le lancer.
set -eu

: "${CAD_CONTEXT:?dossier à construire manquant}"
: "${CAD_TAG:?nom manquant pour cette image}"
case "$CAD_CONTEXT" in /data/*) ;; *) echo "Le dossier doit se trouver sous /data/" >&2; exit 2 ;; esac
case "$CAD_TAG" in -*) echo "Nom d'image invalide" >&2; exit 2 ;; esac
[ -d "$CAD_CONTEXT" ] || { echo "Dossier introuvable : $CAD_CONTEXT" >&2; exit 2; }

mkdir -p /data/output
dockerd-entrypoint.sh >/tmp/dockerd.log 2>&1 &
i=0
until docker info >/dev/null 2>&1; do
  i=$((i + 1))
  [ "$i" -gt 30 ] && { echo "Le moteur Docker ne démarre pas (pod non privilégié ?)" >&2; tail -n 5 /tmp/dockerd.log >&2; exit 1; }
  sleep 1
done

docker build -t "$CAD_TAG" -f "$CAD_CONTEXT/${CAD_DOCKERFILE:-Dockerfile}" "$CAD_CONTEXT"
docker image inspect --format '{{.Id}}' "$CAD_TAG" | tr -d '\n' > /data/output/image-id
