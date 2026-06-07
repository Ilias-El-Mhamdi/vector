---
sidebar_position: 3
title: Frontend (Vanilla JS)
---

# Frontend — Vanilla JavaScript

Pas de framework, pas de bundler, pas de npm. Les scripts sont chargés dans `index.html` dans un ordre précis — c'est la seule résolution de dépendances.

## Ordre de chargement

```html
<!-- Atoms (fonctions pures) -->
<script src="atoms/toast.js"></script>
<script src="atoms/badge.js"></script>
<script src="atoms/busy.js"></script>
<script src="atoms/outlook-guard.js"></script>

<!-- Molecules (helpers) -->
<script src="molecules/api.js"></script>
<script src="molecules/mselect.js"></script>
<script src="molecules/lead-item.js"></script>

<!-- Organisms (sections complètes) -->
<script src="organisms/reply-draft.js"></script>
<script src="organisms/quote-panel.js"></script>
<script src="organisms/lead-detail.js"></script>

<!-- État global -->
<script src="app.js"></script>
```

## Règles par couche

| Couche | Peut appeler | Peut muter l'état global |
|--------|-------------|--------------------------|
| **Atoms** | Rien | Non |
| **Molecules** | `api()` | Non |
| **Organisms** | `api()`, lire `CURRENT`/`CATALOG` | Non |
| **app.js** | Tout | Oui (`LEADS`, `CATALOG`, `CURRENT`) |

## État global (`app.js`)

```javascript
let LEADS   = [];    // tableau depuis GET /api/leads
let CATALOG = {};    // depuis GET /api/catalog
let CURRENT = null;  // lead sélectionné (détail complet)
```

Seul `app.js` mute ces trois variables.

## Atoms

### `toast.js`
```javascript
toast(msg)  // notification auto-dismiss 2,6s
```

### `badge.js`
```javascript
STATUS_LABELS   // { 'ignore': 'Ignoré', 'devis non demande': 'Devis non demandé', … }
statusClass(s)  // → classe CSS 'st-ignore', 'st-traite', …
renderBadge(status)   // → <span class="badge st-…">Label</span>
renderChip(text, type) // → <span class="chip prod|opt">…</span>
```

### `busy.js`
```javascript
withBusy(label, fn)  // affiche un overlay spinner pendant fn()
```

### `outlook-guard.js`
```javascript
withOutlook(fn)  // vérifie la connexion COM, reconnecte si nécessaire, puis exécute fn
```

## Molecules

### `api.js`
```javascript
esc(s)             // échappe les entités HTML
api(path, opts)    // fetch avec gestion d'erreur unifiée
fullName(l)        // → "Prénom Nom"
```

### `mselect.js` — Filtres multi-sélection
```javascript
ALL_STATUSES         // liste des statuts pour les filtres
buildPanel(id, items, defaultChecked)  // construit les checkboxes
toggleMSelect(id)    // ouvre/ferme le dropdown
getChecked(panelId)  // retourne les valeurs cochées
onFilterChange()     // re-render la liste
```

### `lead-item.js`
```javascript
renderLeadItem(l, emailCount)  // → HTML d'un item de liste
// Affiche : nom, badge statut, email, chips produits/options, date
```

## Organisms

### `lead-detail.js`
- Header du lead sélectionné : nom, email, badge statut éditable, toolbar
- `changeStatus(s)` → `PATCH /api/lead?id=...`
- `refreshLead()` → re-lecture depuis Outlook
- `openFolder()` → ouvre `bdd/leads/{id}/` dans l'explorateur
- `openMailOutlook()` → ouvre le mail original via son `entryId`

### `quote-panel.js`
- Zone devis : iframe PDF si `hasQuote`, sinon textarea de brouillon
- `aiQuoteDraft()` → génération IA (Claude Haiku) du brouillon de demande interne
- `searchQuote()` → auto-association via `POST /api/match-quote`
- Upload PDF par drag-drop ou `<input type="file">` (base64 → `POST /api/upload-quote`)
- Auto-save du brouillon (debounce 800 ms)

### `reply-draft.js`
- Zone réponse client : textarea + boutons Aperçu / Envoyer
- `loadTemplate()` → applique `catalog.replyTemplate` avec les variables `{{prenom}}`, `{{produits}}`, etc.
- `aiReplyDraft()` → génération IA de la réponse client (Claude Haiku)
- `sendLead(direct)` → `POST /api/send?direct=0|1`
- Auto-save du brouillon (debounce 800 ms)

## SDK Anthropic

Chargé depuis CDN via `<script type="module">` dans `index.html` :

```javascript
import Anthropic from 'https://esm.sh/@anthropic-ai/sdk';
window._Anthropic = Anthropic;
```

Utilisé dans `quote-panel.js` et `reply-draft.js` avec `claude-haiku-4-5-20251001` pour la génération des brouillons. La clé est lue depuis `window._anthropicKey` (injectée via `GET /api/config`).
