---
sidebar_position: 1
title: Vue d'ensemble
---

# Architecture — Vue d'ensemble

## Schéma général

```
┌─────────────────────────────────────────────────────┐
│                   Windows Desktop                   │
│                                                     │
│  ┌─────────────┐        ┌──────────────────────┐   │
│  │   Outlook   │◄──COM──│   PowerShell (STA)   │   │
│  │   (MAPI)    │        │                      │   │
│  └─────────────┘        │  server.ps1           │   │
│                         │  ├── Config.ps1       │   │
│  ┌─────────────┐        │  ├── Catalog.ps1      │   │
│  │  bdd/       │◄──R/W──│  ├── Leads.ps1        │   │
│  │  ├─leads/   │        │  ├── Mail.ps1         │   │
│  │  └─quotes/  │        │  ├── Router.ps1       │   │
│  └─────────────┘        │  └── Listener.ps1    │   │
│                         │         │             │   │
│                         │   TcpListener:8731    │   │
│                         └──────────┬───────────┘   │
│                                    │ HTTP           │
│                         ┌──────────▼───────────┐   │
│                         │   Navigateur          │   │
│                         │   localhost:8731      │   │
│                         │                      │   │
│                         │   index.html          │   │
│                         │   app.js (état)       │   │
│                         │   organisms/          │   │
│                         │   molecules/          │   │
│                         │   atoms/              │   │
│                         └──────────────────────┘   │
└─────────────────────────────────────────────────────┘
```

## Flux d'une requête HTTP

1. Le navigateur envoie une requête HTTP sur `localhost:8731`
2. `Listener.ps1` (`TcpListener`) accepte la connexion TCP
3. `Http.ps1` parse les headers et le body brut
4. `Router.ps1` (`Handle-Request`) dispatche vers le bon handler
5. Le handler appelle les fonctions métier (`Leads.ps1`, `Mail.ps1`, etc.)
6. La réponse JSON est sérialisée et renvoyée au navigateur

## Ordre de chargement des modules

`server.ps1` dot-source les modules dans cet ordre précis — **l'ordre compte** :

```
Config.ps1    → variables globales ($Root, $BddDir, $Port…)
Json.ps1      → Read-Json, Write-Json, ConvertTo-Hashtable
Catalog.ps1   → Get-Catalog, Find-Matches
Outlook.ps1   → Get-Outlook (cache COM), Invoke-LeadRefresh
Leads.ps1     → Get-AllLeads, Get-LeadDetail, Update-Lead…
Mail.ps1      → Invoke-Scan, Invoke-GenerateQuote, Invoke-Send
Http.ps1      → New-JsonResponse, Read-HttpRequest, Parse-Query
Router.ps1    → Handle-Request, Invoke-*Routes
Listener.ps1  → Start-LeadServer (boucle principale)
```

## Contraintes fondamentales

| Contrainte | Raison |
|-----------|--------|
| Mode **STA** obligatoire | Les objets COM Outlook ne sont pas thread-safe — STA garantit un seul thread d'appartenance |
| Pas de `HttpListener` .NET | `HttpListener` requiert des privilèges élevés ou une réservation `netsh` ; `TcpListener` sur loopback n'en a pas besoin |
| JSON flat files | Pas de dépendance externe (SQLite, etc.), déploiement xcopy |
| Vanilla JS | Pas de Node.js, pas de build step, zéro dépendance runtime côté frontend |
