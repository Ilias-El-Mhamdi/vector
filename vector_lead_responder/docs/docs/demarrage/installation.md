---
sidebar_position: 1
title: Installation
---

# Installation

## Prérequis

- **Windows 10/11** avec Outlook installé et configuré
- **PowerShell 5.1+** (inclus dans Windows)
- Outlook doit être ouvert et connecté au compte MAPI avant le premier lancement

## Structure des fichiers

```
vector/
├── Lancer.cmd          ← point d'entrée unique
├── src/
│   ├── server.ps1      ← charge tous les modules
│   └── back/
│       ├── Config.ps1
│       ├── catalog.json  ← catalogue produits (à configurer)
│       └── ...
├── bdd/                ← créé automatiquement au premier démarrage
│   ├── leads/
│   └── quotes/
└── env.txt             ← variables d'environnement (à créer)
```

## Première configuration

### 1. Créer `env.txt` à la racine

```ini
SCAN_COUNT=50
ANTHROPIC_API_KEY=sk-ant-api03-...
DEVIS_CREATEUR_MAIL=commercial@monentreprise.fr
REPLY_SIGNATURE=Bien cordialement,\nVector France
```

| Variable | Obligatoire | Description |
|----------|-------------|-------------|
| `SCAN_COUNT` | Non (défaut 50) | Nombre de mails scannés par `Invoke-Scan` |
| `ANTHROPIC_API_KEY` | Non | Clé API pour la génération IA des brouillons |
| `DEVIS_CREATEUR_MAIL` | Oui | Adresse interne qui reçoit les demandes de devis |
| `REPLY_SIGNATURE` | Non | Signature insérée dans les mails clients |

### 2. Configurer le catalogue

Éditer [`src/back/catalog.json`](../../donnees/catalogue) avec les produits Vector à détecter.

### 3. Exclusion Windows Defender

Ajouter une exclusion sur le **dossier racine entier** (celui contenant `Lancer.cmd`).  
Sans ça, Defender peut bloquer l'écriture des JSON ou la lecture des pièces jointes.

## Lancement

```batch
double-clic sur Lancer.cmd
```

`Lancer.cmd` force le mode STA (`-STA`) requis pour les appels COM Outlook :

```batch
powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File "src\server.ps1"
```

:::danger Ne pas lancer `server.ps1` directement depuis PowerShell ISE ou un shell non-STA
Les appels COM Outlook échoueront silencieusement ou lèveront une exception RPC.
:::

Le serveur démarre sur `http://localhost:8731`. Ouvrir cette URL dans le navigateur.
