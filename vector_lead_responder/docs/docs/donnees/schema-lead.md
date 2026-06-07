---
sidebar_position: 1
title: Schéma Lead
---

# Schéma Lead JSON

Chaque lead est un fichier JSON stocké dans :

```
bdd/leads/{safeemail}/{timestamp}_{safeemail}.json
```

Exemple : `bdd/leads/john.doe@example.com/20260601T120000_john.doe@example.com.json`

## Champs

```json
{
  "id":           "john.doe@example.com/20260601T120000_john.doe@example.com.json",
  "entryId":      "000000001234ABCD...",
  "email":        "john.doe@example.com",
  "prenom":       "John",
  "nom":          "Doe",
  "subject":      "Demande de devis CANoe",
  "date":         "2026-06-01T12:00:00",
  "body":         "Bonjour, nous sommes intéressés par...",
  "status":       "devis non demande",
  "products":     ["CANoe", "CANdb++"],
  "options":      ["Maintenance"],
  "replyDraft":   "Bonjour John,\n\nMerci de votre intérêt...",
  "quoteDraft":   "Bonjour,\nNous avons besoin de 2x CANoe...",
  "hasQuote":     true,
  "quoteName":    "QUOTE_539302_john.doe@example.com.pdf",
  "quoteId":      "539302",
  "createdAt":    "2026-06-01T12:00:00",
  "updatedAt":    "2026-06-01T14:30:00"
}
```

## Description des champs

| Champ | Type | Description |
|-------|------|-------------|
| `id` | string | Chemin relatif depuis `bdd/leads/` — sert d'identifiant dans l'API |
| `entryId` | string | MAPI Entry ID Outlook — permet de retrouver le mail original |
| `email` | string | Adresse email de l'expéditeur |
| `prenom` | string | Prénom extrait du nom d'affichage Outlook |
| `nom` | string | Nom de famille |
| `subject` | string | Objet du mail |
| `date` | ISO 8601 | Date de réception |
| `body` | string | Corps du mail (HTML nettoyé ou texte brut) |
| `status` | string | Statut courant (voir machine à états) |
| `products` | string[] | Produits Vector détectés |
| `options` | string[] | Options détectées (globales + par produit) |
| `replyDraft` | string | Brouillon de réponse client (auto-sauvegardé) |
| `quoteDraft` | string | Brouillon de demande de devis interne |
| `hasQuote` | bool | Un PDF devis est associé |
| `quoteName` | string | Nom du fichier PDF (`QUOTE_*.pdf`) |
| `quoteId` | string | Identifiant extrait du nom du PDF |
| `createdAt` | ISO 8601 | Date de création du lead |
| `updatedAt` | ISO 8601 | Dernière modification |

## Ce que retourne l'API

### `GET /api/leads` (liste)

Retourne un **subset** — les champs `body`, `replyDraft`, `quoteDraft`, `entryId`, `createdAt` sont exclus pour alléger le payload.

### `GET /api/lead?id=...` (détail)

Retourne le lead complet **plus** les champs calculés : `hasQuote`, `quoteName`, `quoteId`.

## Machine à états

Voir la [page dédiée](../guides/machine-etats).

```
ignore → devis non demande → devis demande → devis recu → traite
```

## Stockage physique

```
bdd/
└── leads/
    └── john.doe@example.com/       ← ConvertTo-SafeName(email)
        ├── 20260601T120000_john.doe@example.com.json   ← le lead
        └── QUOTE_539302_john.doe@example.com.pdf       ← copié depuis bdd/quotes/
```

Le dossier est créé par `Invoke-Scan` à la première détection du contact. Plusieurs leads peuvent coexister dans le même dossier (plusieurs mails du même expéditeur).
