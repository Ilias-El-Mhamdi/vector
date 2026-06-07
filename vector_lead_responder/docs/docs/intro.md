---
slug: /
sidebar_position: 1
title: Introduction
---

# Suivi des leads Outlook — Vector France

Application desktop **Windows uniquement** qui détecte des leads commerciaux dans Outlook et gère le workflow complet **devis → envoi**.

## En bref

| Couche | Technologie |
|--------|-------------|
| Backend | PowerShell 5.1+, mode STA obligatoire |
| Outlook | COM (`Microsoft.Office.Interop.Outlook`) |
| HTTP | `TcpListener` custom, port **8731** |
| Frontend | Vanilla JS — pas de framework, pas de bundler |
| Données | Fichiers JSON dans `bdd/` |

## Workflow

```
Outlook inbox
     │
     ▼  POST /api/scan
Détection produits (catalog matching)
     │
     ▼
Lead créé → status: "devis non demande"
     │
     ▼  POST /api/generate-quote
Mail interne de demande de devis
     │
     ▼  (réception PDF)
status: "devis recu"
     │
     ▼  POST /api/send
Réponse client envoyée → status: "traite"
```

## Démarrage rapide

```batch
double-clic sur Lancer.cmd
```

Ouvre le navigateur sur `http://localhost:8731` automatiquement.

:::warning Windows uniquement
L'application repose sur le COM Outlook — elle ne fonctionne pas sur macOS ou Linux.
:::
