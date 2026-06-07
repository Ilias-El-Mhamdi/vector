---
slug: /
sidebar_position: 1
title: Introduction
---

# Suivi des leads Outlook — Vector France

<div style={{position: 'relative', paddingBottom: '56.25%', height: 0, overflow: 'hidden', borderRadius: '8px', marginBottom: '1.5rem'}}>
  <iframe
    src="https://www.youtube.com/embed/X-mTNZIGBJc"
    title="Aperçu de l'application"
    style={{position: 'absolute', top: 0, left: 0, width: '100%', height: '100%', border: 0}}
    allowFullScreen
  />
</div>

Application desktop **Windows uniquement** qui détecte des leads commerciaux dans Outlook et gère le workflow complet **devis → envoi**.

## En bref

| Couche | Technologie |
|--------|-------------|
| Backend | PowerShell 5.1+, mode STA obligatoire |
| Outlook | COM (`Microsoft.Office.Interop.Outlook`) |
| HTTP | `TcpListener` custom, port **8731** |
| Frontend | Vanilla JS — pas de framework, pas de bundler |
| Données | Fichiers JSON dans `bdd/` |
| IA | API Anthropic (Claude Haiku) — brouillons de réponse et de devis |

## Workflow

```
Outlook inbox
     │
     ▼  POST /api/connect-outlook (démarrage auto)
Connexion COM Outlook établie
     │
     ▼  POST /api/scan?count=N
Détection produits Vector (catalog matching)
     │
     ▼
Lead créé → status: "devis non demande"
     │
     ▼  POST /api/generate-quote  (+ ✦ IA optionnel)
Mail interne de demande de devis
     │  status: "devis demande"
     │
     ▼  upload PDF / match automatique
status: "devis recu"
     │
     ▼  POST /api/send  (+ ✦ IA optionnel)
Réponse client envoyée → status: "traite"
```

## Configuration

L'application se configure via deux fichiers **non versionnés** :

- **`env.txt`** à la racine — clé Anthropic, email expéditeur des devis, signature, nombre de mails à scanner par défaut
- **`src/back/catalog.json`** — liste des produits Vector à détecter, mots-clés, templates de mail

## Démarrage rapide

```batch
double-clic sur Lancer.cmd
```

Ouvre le navigateur sur `http://localhost:8731` automatiquement.

:::warning Windows uniquement
L'application repose sur le COM Outlook — elle ne fonctionne pas sur macOS ou Linux.
:::