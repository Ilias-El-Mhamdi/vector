---
sidebar_position: 2
title: Configuration
---

# Configuration

## Variables d'environnement (`env.txt`)

Le fichier `env.txt` est lu au démarrage par `Config.ps1` et injecté dans l'environnement du processus PowerShell. Format : `CLE=valeur`, les lignes commençant par `#` sont ignorées.

```ini
# Nombre de mails à scanner
SCAN_COUNT=50

# Clé Anthropic pour la génération IA
ANTHROPIC_API_KEY=sk-ant-api03-...

# Adresse qui reçoit les demandes de devis internes
DEVIS_CREATEUR_MAIL=devis@monentreprise.fr

# Signature insérée dans les réponses clients
REPLY_SIGNATURE=Bien cordialement,\nVector France

# Domaines à ignorer lors du scan (séparés par des virgules)
IGNORE_DOMAINS=newsletter.com,noreply.example.com
```

:::tip
`env.txt` est ignoré par git — ne pas le committer. Utiliser un gestionnaire de secrets ou le distribuer manuellement.
:::

## Catalogue produits (`src/back/catalog.json`)

Voir la [référence complète du catalogue](../donnees/catalogue).

Les champs clés à configurer :

| Champ | Description |
|-------|-------------|
| `products[].name` | Nom affiché du produit |
| `products[].keywords` | Mots-clés déclencheurs (insensible à la casse) |
| `products[].options` | Options spécifiques au produit |
| `options_globales` | Options communes à tous les produits |
| `replyTemplate` | Template du mail de réponse client |
| `replySubject` | Objet du mail de réponse |
| `templateAttachment` | Chemin absolu d'une PJ systématique |
| `_ignoreSenders` | Expéditeurs à ignorer lors du scan |

## Chemins calculés par `Config.ps1`

`Config.ps1` définit toutes les variables globales à partir de `$Root` (dossier contenant `server.ps1`) :

```powershell
$Port           = 8731
$BddDir         = Join-Path $Root 'bdd'
$LeadsDir       = Join-Path $BddDir 'leads'
$QuotesDir      = Join-Path $BddDir 'quotes'
$CatalogPath    = Join-Path $Root 'src\back\catalog.json'
$QuoteCachePath = Join-Path $QuotesDir 'quote_cache.json'
$IndexPath      = Join-Path $Root 'src\front\index.html'
```

Ces variables sont **dot-sourcées** — elles sont visibles par tous les modules chargés après `Config.ps1`.

## Accès depuis le frontend

L'endpoint `GET /api/config` expose une sélection de la configuration au frontend :

```json
{
  "scanCount": 50,
  "anthropicApiKey": "sk-ant-...",
  "devisCreateurMail": "devis@...",
  "replySignature": "Bien cordialement,\nVector France"
}
```

La clé Anthropic est transmise au JS pour les appels directs au SDK Anthropic côté navigateur.
