# Connecteurs de workflows Cadriciel

Le catalogue des connecteurs utilisables dans les workflows de Cadriciel, la plateforme de
développement du Cerema.

Un connecteur, c'est **une fiche et une recette de pod**. La fiche dit ce que l'utilisateur règle et
quel identifiant il faut ; la recette dit quelle image Docker lancer et comment lui passer le tout.
Chaque étape d'un workflow s'exécute dans son propre pod : un connecteur peut donc s'appuyer sur
n'importe quelle image.

> **État : brouillon.** Le format est arrêté. Les scripts ont été essayés un par un dans Docker ;
> aucun connecteur n'a encore tourné dans un workflow de la plateforme.

## Connecteurs

| Connecteur | Identifiant | Image | Script essayé |
|---|---|---|---|
| [PostgreSQL](connectors/postgres) | `postgres` | `postgres:16-alpine` | oui, contre une base PostgreSQL 16 |
| [Requête HTTP](connectors/http-request) | `httpHeader` (facultatif) | `curlimages/curl` | oui, contre un serveur d'écho |
| [OpenAI](connectors/openai) | `openai` | `oven/bun` | contre un faux service seulement, pas contre OpenAI |

## Organisation du dépôt

```
connectors/<id>/fiche.json     la fiche du connecteur
connectors/<id>/run.*          le script exécuté dans le pod
credentials/<type>.json        un type d'identifiant : ses champs, son essai de connexion
```

## La fiche d'un connecteur

```json
{
  "id": "postgres",
  "name": "PostgreSQL",
  "version": "0.1.0",
  "category": "data",
  "image": "postgres:16-alpine",
  "credential": { "type": "postgres", "env": { "PGHOST": "host", "PGPASSWORD": "password" } },
  "parameters": [
    { "key": "query", "type": "sql", "label": "Requête", "required": true, "env": "CAD_QUERY" }
  ],
  "script": "run.sh",
  "command": ["sh", "/opt/cadriciel/run.sh"],
  "produces": [{ "key": "rows", "type": "json", "path": "/data/output/rows.json" }]
}
```

| Champ | Rôle |
|---|---|
| `id`, `name`, `version`, `category`, `icon`, `color` | Identité du connecteur dans la palette. Une étape de workflow note la version qu'elle utilise. |
| `image` | L'image Docker du pod. |
| `credential` | Le type d'identifiant réclamé (`optional` s'il est facultatif) et, pour chacun de ses champs, la variable d'environnement qui le reçoit. |
| `parameters` | Les réglages de l'étape. L'éditeur en tire le formulaire. Chaque paramètre arrive au pod dans la variable nommée par `env`. |
| `script`, `command` | Le script livré avec la fiche, monté dans le pod sous `/opt/cadriciel/`, et la commande qui le lance. |
| `produces` | Ce que le pod rend : un fichier par résultat, avec son type. |
| `resources`, `timeout` | Limites du pod. |

### Types de paramètres

| Type | Champ dans l'éditeur | Valeur reçue par le pod |
|---|---|---|
| `text` | Une ligne de texte | Le texte |
| `number` | Un nombre, borné par `min` et `max` | Le nombre |
| `choice` | Un choix parmi `options` | La valeur choisie |
| `boolean` | Oui / non | `true` ou `false` |
| `sql`, `code` | Un éditeur multiligne | Le texte |
| `pairs` | Une liste de paires nom / valeur | Une paire par ligne, `Nom: valeur` |

Un paramètre peut porter `default`, `required`, et `showIf` pour ne s'afficher que selon la valeur
d'un autre. Il accepte les références `{{input.x}}` et `{{steps.Nom.cle}}`, résolues avant le
lancement du pod.

### Règles

- **Tout passe au pod par des variables d'environnement.** Une valeur saisie par l'utilisateur
  n'est jamais recollée dans une ligne de commande : elle ne peut pas être interprétée par le shell.
- **L'identifiant** est choisi par son nom dans l'étape. À l'exécution, sa valeur pour
  l'environnement courant est placée dans un secret Kubernetes le temps du pod, puis retirée. Elle
  n'apparaît ni dans le workflow, ni dans le dépôt du projet, ni dans les journaux.
- **Le résultat** est écrit par le script dans `/data/output/`. Types : `json`, `number`, `text`,
  `file`.
- **Un échec** se signale par un code de sortie différent de zéro et un message lisible sur la
  sortie d'erreur. Le code 2 est réservé aux réglages invalides.

## Un type d'identifiant

```json
{
  "id": "postgres",
  "name": "PostgreSQL",
  "fields": [
    { "key": "host", "type": "text", "label": "Hôte", "required": true },
    { "key": "password", "type": "secret", "label": "Mot de passe", "required": true }
  ],
  "test": { "image": "postgres:16-alpine", "env": { "PGHOST": "host" }, "command": ["psql", "-At", "-c", "select 1"] }
}
```

`fields` décrit le formulaire de l'écran Identifiants ; un champ `secret` est masqué. `test` est le
pod lancé par « Tester la connexion » : il réussit si la commande sort avec le code zéro.

## Versions

La plateforme ne lit pas la branche `main` : elle épingle une version publiée du catalogue. Une
nouvelle version est d'abord prise par la plateforme de recette, puis promue en production.
