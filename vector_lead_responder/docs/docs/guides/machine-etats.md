---
sidebar_position: 3
title: Machine à états des leads
---

# Machine à états des leads

## Diagramme

```
                     Scan Outlook
                          │
                          ▼
              ┌─────────────────────┐
              │  Produits détectés? │
              └─────────────────────┘
                  Oui │       │ Non
                      ▼       ▼
             ┌──────────┐  ┌────────┐
             │  devis   │  │ ignore │
             │non demandé│  └────────┘
             └──────────┘
                   │
                   │  POST /api/generate-quote
                   ▼
          ┌───────────────┐
          │ devis demandé │
          └───────────────┘
                   │
                   │  (réception PDF dans bdd/quotes/)
                   │  POST /api/match-quote ou upload
                   ▼
          ┌───────────────┐
          │  devis reçu  │
          └───────────────┘
                   │
                   │  POST /api/send?direct=1
                   ▼
          ┌───────────────┐
          │    traité     │
          └───────────────┘
```

## Valeurs JSON

| Valeur JSON | Label UI | Déclencheur |
|-------------|----------|-------------|
| `ignore` | Ignoré | Scan sans produit détecté |
| `devis non demande` | Devis non demandé | Scan avec produit détecté |
| `devis demande` | Devis demandé | `POST /api/generate-quote` (envoi réel) |
| `devis recu` | Devis reçu | PDF associé au lead |
| `traite` | Traité | `POST /api/send?direct=1` |

## Transitions automatiques

### Lors du scan (`Invoke-Scan`)

```powershell
if ($products.Count -eq 0) {
    $status = 'ignore'
} else {
    $status = 'devis non demande'
}
# Si un QUOTE_*.pdf est détecté en PJ du mail
if ($hasQuotePdf) {
    $status = 'devis recu'
}
```

### Lors de l'envoi de la demande de devis

`Invoke-GenerateQuote` → `devis demande` (seulement si `preview=0`)

### Lors de l'association d'un devis

`Invoke-MatchQuote` ou upload → si `status == 'devis demande'` → `devis recu`

### Lors de l'envoi client

`Invoke-Send` avec `direct=1` → `traite`

## Synchronisation frontend

Le statut affiché dans l'UI est lu depuis `CURRENT.status` (état global `app.js`).

- **`badge.js`** : `STATUS_LABELS` mappe les valeurs JSON → labels affichés
- **`mselect.js`** : `ALL_STATUSES` liste les statuts pour les filtres

Ces deux constantes doivent rester synchronisées avec les valeurs JSON ci-dessus.

## Modification manuelle du statut

L'utilisateur peut changer le statut manuellement via le badge cliquable dans `lead-detail.js` :

```javascript
async function changeStatus(s) {
  await api(`/api/lead?id=${CURRENT.id}`, { method: 'POST', body: { status: s } });
  CURRENT.status = s;
  renderDetail();
}
```

Il n'y a pas de validation des transitions côté backend — tout statut valide est accepté.
