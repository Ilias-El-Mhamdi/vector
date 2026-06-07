---
sidebar_position: 7
title: Déploiement
---

# Déploiement de la documentation

La documentation Docusaurus est déployée en site statique sur **Cloudflare R2**.

## Build

```bash
cd docs
npm install
npm run build
# → génère docs/build/
```

## Upload sur Cloudflare R2

### Prérequis

- [Wrangler CLI](https://developers.cloudflare.com/workers/wrangler/) installé : `npm install -g wrangler`
- Bucket R2 créé dans le dashboard Cloudflare
- Domaine personnalisé ou URL publique R2 configuré

### Configuration `wrangler.toml`

Créer `docs/wrangler.toml` :

```toml
name = "vector-france-docs"
compatibility_date = "2024-01-01"

[[r2_buckets]]
binding = "DOCS"
bucket_name = "vector-france-docs"
```

### Déploiement

```bash
# Authentification (une seule fois)
wrangler login

# Upload du build
wrangler r2 object put vector-france-docs/ \
  --file docs/build/ \
  --recursive
```

Ou avec un script shell :

```bash
#!/bin/bash
# deploy-docs.sh
cd docs
npm run build
wrangler r2 object put vector-france-docs \
  --file build/ \
  --recursive \
  --content-type "text/html"
```

## Développement local

```bash
cd docs
npm install
npm start
# → http://localhost:3000
```

## Structure du build

```
docs/build/
├── index.html
├── assets/
│   ├── css/
│   └── js/
└── [pages]/
    └── index.html
```

Tous les fichiers sont statiques — aucun serveur Node.js n'est requis en production.

## Mise à jour

Après modification de la documentation :

```bash
cd docs
npm run build
# Re-uploader build/ sur R2
```

:::tip Cache R2
Penser à invalider le cache Cloudflare après chaque déploiement si un domaine CDN est configuré devant le bucket.
:::
