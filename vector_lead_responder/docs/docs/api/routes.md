---
sidebar_position: 1
title: Référence des routes
---

# Référence API

Toutes les routes sont servies sur `http://localhost:8731`.

## Catalogue & Config

| Méthode | Route | Description |
|---------|-------|-------------|
| `GET` | `/api/catalog` | Retourne le contenu complet de `catalog.json` |
| `GET` | `/api/config` | Retourne `{ scanCount, anthropicApiKey, devisCreateurMail, replySignature }` |

## Leads

| Méthode | Route | Description |
|---------|-------|-------------|
| `GET` | `/api/leads` | Liste tous les leads (subset sans `body`, `replyDraft`, `entryId`) |
| `GET` | `/api/lead?id=...` | Détail complet d'un lead + `hasQuote`, `quoteName`, `quoteId` |
| `POST` | `/api/lead?id=...` | Mise à jour partielle (patch) d'un lead |
| `POST` | `/api/lead/refresh?id=...` | Relit le mail depuis Outlook via `entryId` |
| `POST` | `/api/match-quote?id=...` | Auto-association d'un PDF devis |
| `POST` | `/api/delete-quote?id=...` | Supprime le devis associé et blackliste le PDF |
| `POST` | `/api/upload-quote?id=...` | Upload d'un PDF en base64 (`{ name, data }`) |

### `GET /api/leads` — réponse

```json
[
  {
    "id": "john.doe@example.com/20260601T120000_john.doe.json",
    "email": "john.doe@example.com",
    "prenom": "John",
    "nom": "Doe",
    "subject": "Demande CANoe",
    "date": "2026-06-01T12:00:00",
    "status": "devis non demande",
    "products": ["CANoe"],
    "options": ["Maintenance"],
    "hasQuote": false
  }
]
```

### `POST /api/lead?id=...` — body

```json
{
  "status": "devis demande",
  "replyDraft": "Bonjour John,\n\nMerci..."
}
```

Seuls les champs fournis sont mis à jour (`updatedAt` est toujours mis à jour).

## Outlook & Mail

| Méthode | Route | Paramètres | Description |
|---------|-------|------------|-------------|
| `GET` | `/api/outlook-status` | — | `{ connected: true\|false }` |
| `POST` | `/api/connect-outlook` | — | Force l'initialisation COM |
| `POST` | `/api/scan` | `?count=N` | Scanne les N derniers mails (défaut 50) |
| `POST` | `/api/generate-quote` | `?id=...&preview=0\|1` | Crée la demande de devis interne |
| `POST` | `/api/send` | `?id=...&direct=0\|1` | Envoie la réponse client |
| `POST` | `/api/open-mail` | `?id=...` | Ouvre le mail dans Outlook |
| `POST` | `/api/open-folder` | `?id=...` | Ouvre le dossier du lead dans l'explorateur |

### `POST /api/scan` — réponse

```json
{
  "scanned": 50,
  "new": 3,
  "updated": 1,
  "quotes": 1
}
```

### `POST /api/generate-quote` — body optionnel

```json
{
  "quoteDraft": "Bonjour,\nNous avons besoin de 2x CANoe..."
}
```

Si `preview=1`, le mail est créé et affiché dans Outlook sans être envoyé.

### `POST /api/send` — body optionnel

```json
{
  "replyText": "Bonjour John,\n\nVeuillez trouver..."
}
```

Si `direct=0`, le mail est affiché dans Outlook (`Display()`). Si `direct=1`, il est envoyé immédiatement.

## Fichiers

| Méthode | Route | Description |
|---------|-------|-------------|
| `GET` | `/api/list-quotes` | Liste les `QUOTE_*.pdf` dans `bdd/quotes/` |
| `GET` | `/api/raw-file?path=...` | Sert un fichier (protection traversal de chemin) |
| `GET` | `/api/file?id=...&name=...` | Sert un fichier depuis le dossier d'un lead |

## Assets statiques

| Méthode | Route | Description |
|---------|-------|-------------|
| `GET` | `/` ou `/index.html` | Sert `src/front/index.html` |
| `GET` | `/*.js` | Sert les scripts JS |
| `GET` | `/*.css` | Sert les feuilles de style |

## Codes d'erreur

| Code | Signification |
|------|--------------|
| `200` | Succès |
| `404` | Route ou fichier non trouvé |
| `500` | Exception PowerShell — le body contient `{ error: "message" }` |
