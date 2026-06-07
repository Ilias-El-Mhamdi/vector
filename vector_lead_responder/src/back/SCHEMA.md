# Schéma Lead JSON — contrat canonique

**Écrit par :** `Mail.ps1` `Invoke-Scan` (création), `Leads.ps1` `Update-Lead` (patches)
**Lu par :** `Leads.ps1` `Get-AllLeads` / `Get-LeadDetail`, tous les `organisms/*.js`

---

## Fichier lead (`bdd/leads/{safeemail}/{timestamp}_{safeemail}.json`)

| Champ | Type | Description |
|-------|------|-------------|
| `id` | string | Chemin relatif depuis `bdd/leads/` : `"safeemail/20240730T120000_safeemail.json"` — utilisé comme paramètre `?id=` dans l'API |
| `entryId` | string | MAPI Entry ID Outlook (pour rouvrir le mail via COM) |
| `email` | string | Adresse SMTP en minuscules |
| `prenom` | string | Prénom extrait de `SenderName` Outlook |
| `nom` | string | Nom extrait de `SenderName` Outlook |
| `subject` | string | Objet du mail |
| `date` | string | ISO 8601, heure de réception (ex : `"2026-05-30T02:09:18"`) |
| `body` | string | Corps du mail en texte brut (HTML strippé) |
| `status` | string | Voir machine à états ci-dessous |
| `products` | string[] | Noms des produits Vector détectés par `Catalog.ps1` |
| `options` | string[] | Options détectées (par produit + `options_globales`) |
| `replyDraft` | string | Texte de réponse client édité dans l'UI (auto-sauvegardé toutes les 800 ms) |
| `quoteDraft` | string | Texte de la demande de devis interne édité dans l'UI (auto-sauvegardé) |
| `quoteId` | string | Identifiant numérique extrait du nom de fichier PDF (`QUOTE_<id>_...pdf`), ou `""` |
| `createdAt` | string | ISO 8601 |
| `updatedAt` | string | ISO 8601, mis à jour à chaque `Write-Json` |

---

## Machine à états (`status`)

```
ignore  →  devis non demande  →  devis demande  →  devis recu  →  traite
```

| Valeur | Déclencheur |
|--------|-------------|
| `ignore` | Aucun produit Vector détecté au scan |
| `devis non demande` | Produit détecté, aucune action encore |
| `devis demande` | `Invoke-GenerateQuote` exécuté |
| `devis recu` | PDF attaché au lead (upload ou `Invoke-ApplyMatches`) |
| `traite` | `Invoke-Send` exécuté |

---

## Réponse `/api/leads` — liste (subset)

Retourné par `Get-AllLeads`. Champs **absents** : `body`, `replyDraft`, `quoteDraft`, `entryId`, `createdAt`.

| Champ | Type |
|-------|------|
| `id` | string |
| `email` | string |
| `prenom` | string |
| `nom` | string |
| `subject` | string |
| `date` | string |
| `status` | string |
| `products` | string[] |
| `options` | string[] |
| `hasQuote` | bool — calculé à la volée (présence d'un `.pdf` dans le dossier) |

---

## Réponse `/api/lead?id=...` — détail complet

Retourné par `Get-LeadDetail`. Tous les champs du fichier JSON + :

| Champ ajouté | Type | Description |
|--------------|------|-------------|
| `hasQuote` | bool | Présence d'un PDF dans le dossier du lead |
| `quoteName` | string | Nom du fichier PDF, ou `""` si absent |

---

## Schéma prévu — non encore implémenté

`lead-item.js` gère déjà un champ `items[]` en fallback (affichage par produit/quantité) :

```json
"items": [
  { "produit": "CANoe", "quantite": 1, "options": ["Maintenance"] }
]
```

Ce champ **n'est pas encore écrit par le backend**. Il est destiné à remplacer les tableaux plats `products[]` / `options[]` pour porter la quantité par produit. Ne pas utiliser avant que `Invoke-Scan` l'implémente.
