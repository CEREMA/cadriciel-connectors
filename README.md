# Connecteurs de workflows Cadriciel

Le catalogue des connecteurs utilisables dans les workflows de Cadriciel, la plateforme de
développement du Cerema.

Un connecteur, c'est **une fiche et une recette de pod**. La fiche dit ce que l'utilisateur règle et
quel identifiant il faut ; la recette dit quelle image Docker lancer et comment lui passer le tout.
Chaque étape d'un workflow s'exécute dans son propre pod : un connecteur peut donc s'appuyer sur
n'importe quelle image.

> **État : brouillon.** Le format est arrêté. La colonne « Essayé » dit ce qui a réellement tourné
> (plateforme de recette, 6 octobre 2026).

## Connecteurs

| Connecteur | Sert à | Identifiant | Essayé |
|---|---|---|---|
| [PostgreSQL](connectors/postgres) | Lire ou modifier une base par une requête SQL | `postgres` | dans un workflow de la plateforme, contre une base PostgreSQL 16 |
| [MySQL](connectors/mysql) | Lire ou modifier une base MySQL ou MariaDB par une requête SQL | `mysql` | script et essai de connexion, dans l'image du connecteur contre un serveur MySQL 8.4 (hors plateforme) |
| [Requête HTTP](connectors/http-request) | Appeler une adresse HTTP | `httpHeader` (facultatif) | dans un workflow de la plateforme, avec et sans identifiant |
| [OpenAI](connectors/openai) | Envoyer un message à un modèle | `openai` | script, contre un faux service seulement |
| [S3](connectors/s3) | Lire, déposer, synchroniser des fichiers | `s3` | dans un workflow de la plateforme, contre un stockage S3 simulé |
| [GDAL](connectors/gdal) | Convertir des données géographiques : format, système de coordonnées | — | script, dans l'image du connecteur (hors plateforme) : GeoJSON, GeoPackage, Shapefile, CSV, liste de coordonnées |
| [FFmpeg](connectors/ffmpeg) | Traiter de la vidéo et du son | — | dans un workflow de la plateforme |
| [ImageMagick](connectors/imagemagick) | Traiter des images | — | dans un workflow de la plateforme |
| [MediaInfo](connectors/mediainfo) | Lire les caractéristiques d'un fichier média | — | dans un workflow de la plateforme |
| [Git clone](connectors/git-clone) | Récupérer un dépôt git public | — | dans un workflow de la plateforme |
| [Docker build](connectors/docker-build) | Construire une image Docker | — | non ; demande un pod privilégié |
| [Envisaas (Envigis)](connectors/envisaas) | Traiter des données maritimes AIS | — | non |
| [Code Bun](connectors/code-bun) | Écrire du code TypeScript ou JavaScript | — | repris de la plateforme, pas réessayé depuis la fiche |
| [Code Python](connectors/code-python) | Écrire du code Python | — | repris de la plateforme, pas réessayé depuis la fiche |

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
| `script`, `command` | Le script livré avec la fiche et la commande qui le lance. La plateforme dépose le script dans le volume de travail du pod et adapte le chemin : `/opt/cadriciel/` dans `command` est une convention d'écriture, pas un emplacement garanti. |
| `produces` | Ce que le pod rend : un fichier par résultat, avec son type. |
| `resources`, `timeout` | Limites du pod. |

### Trois sortes de connecteurs

- **À réglages** (PostgreSQL, Requête HTTP, OpenAI, MediaInfo, Git clone) : l'utilisateur remplit un
  formulaire ; le script de la fiche fait le travail et rend des résultats fixés par la fiche.
- **À commandes** (FFmpeg, ImageMagick, S3, Envisaas) : l'utilisateur écrit les commandes de
  l'outil dans un réglage `commands`. Avec `"outputs": "custom"`, il déclare aussi lui-même les
  fichiers que l'étape produit ; `produces` n'en donne alors que la proposition de départ, et
  `examples` des commandes prêtes à reprendre.
- **De code** (`"kind": "code"` : Code Bun, Code Python) : l'utilisateur écrit du code, exécuté par
  la plateforme dans l'image de la fiche. `code` donne le langage et le modèle de départ.

`requires` signale ce qu'un connecteur exige de la plateforme (par exemple un pod privilégié) :
elle peut refuser de le lancer.

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

## Licence

[MIT](LICENSE) — © 2026 Cerema.
