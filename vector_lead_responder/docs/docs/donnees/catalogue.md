---
sidebar_position: 2
title: Catalogue produits
---

# Catalogue produits (`catalog.json`)

Fichier de référence pour la détection automatique des produits Vector dans les mails. Situé dans `src/back/catalog.json`.

## Structure complète

```json
{
  "products": [
    {
      "name": "CANoe",
      "keywords": ["canoe", "can oe", "55000", "ma-55000"],
      "options": [
        {
          "name": "Maintenance",
          "keywords": ["maintenance", "ma-", "update", "support"]
        }
      ]
    },
    {
      "name": "CANdb++",
      "keywords": ["candb", "can db", "dbc"]
    }
  ],
  "options_globales": [
    {
      "name": "Licence perpétuelle",
      "keywords": ["perpetual", "licence perpetuelle", "perpetuel"]
    },
    {
      "name": "Formation",
      "keywords": ["formation", "training"]
    }
  ],
  "replyTemplate": "Bonjour {{prenom}},\n\nSuite à votre demande concernant {{produits}}...",
  "replySubject": "Offre Commerciale Vector France — {{produits}}",
  "templateAttachment": "",
  "_ignoreSenders": ["noreply", "no-reply", "mailer-daemon", "newsletter"]
}
```

## Champs

### `products[]`

| Champ | Type | Description |
|-------|------|-------------|
| `name` | string | Nom affiché du produit dans l'UI |
| `keywords` | string[] | Mots-clés à chercher (insensible à la casse) |
| `options` | objet[] | Options spécifiques à ce produit |

### `options_globales[]`

Options communes à tous les produits. Un lead se voit attribuer une option globale dès qu'un de ses produits est détecté **et** que le mot-clé de l'option apparaît dans le mail.

### Templates de réponse

| Champ | Description |
|-------|-------------|
| `replyTemplate` | Corps du mail de réponse client. Supporte les variables `{{…}}`. |
| `replySubject` | Objet du mail de réponse. |
| `templateAttachment` | Chemin absolu d'une PJ à joindre systématiquement (laisser vide si inutilisé). |

### Variables disponibles dans les templates

| Variable | Valeur |
|----------|--------|
| `{{prenom}}` | Prénom du contact |
| `{{produits}}` | Liste des produits séparés par des virgules |
| `{{options_phrase}}` | ` (options : Maintenance, Formation)` ou vide |
| `{{quoteId}}` | Numéro du devis ou vide |
| `{{signature}}` | Valeur de `REPLY_SIGNATURE` dans `env.txt` |

### `_ignoreSenders[]`

Sous-chaînes à chercher dans l'adresse expéditeur pour ignorer le mail lors du scan. Utile pour filtrer les notifications automatiques.

## Logique de détection

`Find-Matches` dans `Catalog.ps1` :

1. Concatène sujet + corps du mail en minuscules
2. Pour chaque produit, teste si au moins un mot-clé est présent
3. Si produit détecté, teste les options du produit + les options globales
4. Retourne `{ products: [...], options: [...] }`

La détection de quantité parse les patterns :
- `2x CANoe`, `CANoe x2`
- `deux CANoe`, `trois licences`
- `CANoe (2)`

## Accès depuis l'API

`GET /api/catalog` retourne le contenu brut du fichier.  
`GET /api/config` expose les champs de configuration (pas les produits).
