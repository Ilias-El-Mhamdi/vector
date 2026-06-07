---
sidebar_position: 1
title: Ajouter une route backend
---

# Ajouter une route backend

## Pattern standard

Toutes les routes sont dans `Router.ps1`. Chaque groupe de routes est une fonction `Invoke-*Routes`.

### 1. Choisir le bon groupe

| Groupe | Fonction | Quand l'utiliser |
|--------|----------|-----------------|
| Catalogue | `Invoke-CatalogRoutes` | Lecture/écriture du catalogue |
| Leads | `Invoke-LeadsRoutes` | Opérations sur les leads |
| Mail | `Invoke-MailRoutes` | Interactions Outlook |
| Fichiers | `Invoke-FileRoutes` | Servir des fichiers |

### 2. Ajouter le handler dans la fonction

```powershell
function Invoke-LeadsRoutes($method, $pathOnly, $q, $body) {
    # ... routes existantes ...

    if ($pathOnly -eq '/api/ma-route' -and $method -eq 'POST') {
        $payload = $body | ConvertFrom-Json
        return New-JsonResponse (Ma-Fonction $q['id'] $payload)
    }
}
```

### 3. Créer la fonction métier dans le module approprié

```powershell
# Dans Leads.ps1
function Ma-Fonction($id, $payload) {
    $lead = Get-LeadDetail $id
    # ... logique ...
    return @{ ok = $true }
}
```

## Conventions

| Cas | Code |
|-----|------|
| Succès | `return New-JsonResponse @{ ... }` |
| Erreur métier | `throw "Message d'erreur lisible"` — catchée → HTTP 500 |
| Ressource introuvable | `return New-TextResponse '404 Not Found' 'message'` |
| Route non matchée | `return $null` — le dispatcher essaie le groupe suivant |

## Exemple complet — export CSV des leads

```powershell
# Dans Router.ps1 → Invoke-LeadsRoutes
if ($pathOnly -eq '/api/leads/export' -and $method -eq 'GET') {
    return New-JsonResponse (Export-LeadsCsv)
}

# Dans Leads.ps1
function Export-LeadsCsv {
    $leads = Get-AllLeads
    $csv = $leads | ConvertTo-Csv -NoTypeInformation
    return @{ csv = ($csv -join "`n") }
}
```

## Ajouter un nouveau groupe de routes

Si aucun groupe existant ne convient :

```powershell
# 1. Créer la fonction dans Router.ps1
function Invoke-StatsRoutes($method, $pathOnly, $q, $body) {
    if ($pathOnly -eq '/api/stats' -and $method -eq 'GET') {
        return New-JsonResponse (Get-Stats)
    }
}

# 2. L'ajouter au tableau du dispatcher dans Handle-Request
$handlers = @(
    { Invoke-CatalogRoutes $method $pathOnly $q $body },
    { Invoke-LeadsRoutes   $method $pathOnly $q $body },
    { Invoke-MailRoutes    $method $pathOnly $q $body },
    { Invoke-StatsRoutes   $method $pathOnly $q $body },  # ← nouveau
    { Invoke-FileRoutes    $method $pathOnly $q $body }
)
```

:::warning Les fichiers statiques en dernier
`Invoke-FileRoutes` doit toujours rester le dernier handler — il sert de fallback pour les assets et l'`index.html`.
:::
