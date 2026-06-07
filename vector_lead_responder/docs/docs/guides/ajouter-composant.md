---
sidebar_position: 2
title: Ajouter un composant frontend
---

# Ajouter un composant frontend

## Choisir la bonne couche

| Couche | Dossier | Quand l'utiliser |
|--------|---------|-----------------|
| **Atom** | `atoms/` | Fonction pure, pas d'appel réseau, pas d'accès à l'état global |
| **Molecule** | `molecules/` | Helper ou rendu composé, peut appeler `api()` |
| **Organism** | `organisms/` | Section complète, peut lire `CURRENT`/`CATALOG`, peut appeler `api()` |

## Créer le fichier

```javascript
// src/front/atoms/mon-composant.js

function maFonction(param) {
  return `<div class="mon-composant">${esc(param)}</div>`;
}
```

## Enregistrer dans `index.html`

Ajouter la balise `<script>` **après ses dépendances, avant ses consommateurs** :

```html
<!-- Atoms -->
<script src="atoms/toast.js"></script>
<script src="atoms/badge.js"></script>
<script src="atoms/mon-composant.js"></script>  <!-- ← ici -->

<!-- Molecules (peuvent utiliser mon-composant) -->
<script src="molecules/api.js"></script>
```

:::caution Pas d'`export`/`import`
Toutes les fonctions sont globales sur `window`. L'ordre des balises `<script>` est la seule résolution de dépendances.
:::

## Exemple — Atom : indicateur de connexion

```javascript
// atoms/connection-dot.js

function renderConnectionDot(connected) {
  const cls = connected ? 'dot-green' : 'dot-red';
  const label = connected ? 'Connecté' : 'Déconnecté';
  return `<span class="connection-dot ${cls}" title="${label}"></span>`;
}
```

```html
<!-- index.html, après badge.js -->
<script src="atoms/connection-dot.js"></script>
```

## Exemple — Organism : panneau de statistiques

```javascript
// organisms/stats-panel.js

async function renderStatsPanel() {
  const stats = await api('/api/stats');
  document.getElementById('stats').innerHTML = `
    <div class="stats-panel">
      <span>${stats.total} leads</span>
      <span>${stats.traites} traités</span>
    </div>
  `;
}
```

```html
<!-- index.html, dans la section organisms -->
<script src="organisms/stats-panel.js"></script>
```

## Appeler depuis `app.js`

`app.js` est le seul endroit qui orchestre le rendu global :

```javascript
// app.js
async function init() {
  await loadCatalog();
  await loadLeads();
  await renderStatsPanel();  // ← appel du nouvel organism
  render();
}
```
