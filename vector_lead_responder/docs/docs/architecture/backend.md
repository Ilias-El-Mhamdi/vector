---
sidebar_position: 2
title: Backend (PowerShell)
---

# Backend — Modules PowerShell

## Config.ps1

Définit toutes les variables globales de chemins et le port. Lit `env.txt` et l'injecte dans l'environnement du processus.

```powershell
$Port        = 8731
$BddDir      = Join-Path $Root 'bdd'
$LeadsDir    = Join-Path $BddDir 'leads'
$QuotesDir   = Join-Path $BddDir 'quotes'
$CatalogPath = Join-Path $Root 'src\back\catalog.json'
```

Crée les dossiers `bdd/`, `bdd/leads/`, `bdd/quotes/` s'ils n'existent pas.

---

## Json.ps1

Fonctions utilitaires de sérialisation JSON et de système de fichiers.

| Fonction | Description |
|----------|-------------|
| `Read-Json($path)` | Lit un fichier JSON, retourne `$null` si absent |
| `Write-Json($path, $obj)` | Écrit en UTF-8 sans BOM |
| `ConvertTo-Hashtable($obj)` | Convertit `PSCustomObject` → `Hashtable` ordonné (résout les problèmes de sérialisation de tableaux à 1 élément) |
| `ConvertTo-SafeName($email)` | Sanitise une adresse email pour usage en nom de dossier |

---

## Catalog.ps1

Moteur de détection des produits Vector dans le texte d'un mail.

| Fonction | Description |
|----------|-------------|
| `Get-Catalog` | Charge `catalog.json` |
| `Find-Matches($text, $catalog)` | Retourne `{ products, options }` détectés |
| `Get-ProductQuantity($text, $keywords, $style)` | Parse les quantités ("2x CANoe", "CANoe 2", "deux CANoe") |
| `Get-QuantityStyle($text)` | Auto-détecte si la quantité précède ou suit le mot-clé |

La détection est insensible à la casse et cherche dans le sujet + le corps.

---

## Outlook.ps1

Interface COM Outlook avec cache et reconnexion automatique.

| Fonction | Description |
|----------|-------------|
| `Get-Outlook` | Retourne l'objet COM mis en cache ; reconnecte si le RPC est mort |
| `Test-OutlookAlive` | Probe via `GetNamespace('MAPI')` pour détecter un COM périmé |
| `Get-SmtpAddress($mail)` | Extrait l'adresse SMTP réelle pour les comptes Exchange (type EX) |
| `Split-Name($displayName)` | Parse "Prénom Nom" ou "Nom, Prénom" |

L'objet COM est stocké dans `$script:Outlook` et réutilisé entre les requêtes.

---

## Leads.ps1

Persistance et logique métier des leads.

| Fonction | Description |
|----------|-------------|
| `Get-AllLeads` | Liste tous les leads (subset sans `body`/`replyDraft`) |
| `Get-LeadDetail($id)` | Lead complet + `hasQuote`, `quoteName`, `quoteId` |
| `Update-Lead($id, $patch)` | Mise à jour partielle + `updatedAt` |
| `Get-LeadPath($id)` | Convertit l'id relatif en chemin absolu |
| `Invoke-MatchQuote($id)` | Auto-association d'un PDF devis par extraction d'email |
| `Invoke-DeleteQuote($id)` | Supprime le devis, met à jour le statut, blackliste le PDF |

### Association automatique des devis

Le PDF est trouvé dans `bdd/quotes/QUOTE_*.pdf` en extrayant les emails du contenu PDF (décodage ASCII85 + décompression zlib). Un cache `quote_cache.json` accélère les recherches suivantes.

---

## Mail.ps1

Logique métier principale : scan, génération de devis, envoi.

### `Invoke-Scan($count)`

1. Lit les N derniers mails de la boîte de réception Outlook
2. Détecte les produits via `Find-Matches`
3. Crée le dossier `bdd/leads/{safeemail}/{timestamp}_{safeemail}/` et le JSON
4. Détecte les PJ `QUOTE_*.pdf` entrants
5. Déduplique par `entryId`
6. Statut automatique : `ignore` → `devis non demande` → `devis recu`

### `Invoke-GenerateQuote($id, $preview, $quoteDraft)`

- Crée un mail interne de demande de devis avec la liste des produits détectés
- `preview=1` : affiche dans Outlook sans envoyer
- Met à jour le statut → `devis demande`

### `Invoke-Send($id, $direct, $replyText)`

- Répond en threading au mail original (`reply.Reply()`)
- Attache le PDF devis + l'éventuelle PJ template
- `direct=1` : envoie immédiatement ; sinon affiche dans Outlook
- Met à jour le statut → `traite`

---

## Http.ps1

Parsing HTTP custom (sans `HttpListener` .NET).

| Fonction | Description |
|----------|-------------|
| `Read-HttpRequest($stream)` | Parse headers + body (gère `Content-Length`) |
| `New-JsonResponse($obj)` | Sérialise en JSON + headers HTTP/1.1 200 |
| `New-TextResponse($status, $text)` | Réponse texte brut |
| `Parse-Query($qs)` | Parse la query string en hashtable |
| `Decode-Url($s)` | Décode les séquences `%xx` |

---

## Router.ps1

Dispatcher de routes. `Handle-Request` essaie chaque groupe dans l'ordre :

```powershell
$handlers = @(
    { Invoke-CatalogRoutes $method $pathOnly $q $body },
    { Invoke-LeadsRoutes   $method $pathOnly $q $body },
    { Invoke-MailRoutes    $method $pathOnly $q $body },
    { Invoke-FileRoutes    $method $pathOnly $q $body }
)
```

Toute exception levée dans un handler est catchée et retournée en HTTP 500 avec le message d'erreur.

---

## Listener.ps1

Boucle `TcpListener` principale :

```powershell
$listener = [System.Net.Sockets.TcpListener]::new([IPAddress]::Loopback, $Port)
$listener.Start()
while ($true) {
    $client = $listener.AcceptTcpClient()
    # parse → route → respond
}
```

Le bloc `finally` arrête le listener proprement à l'arrêt du processus (Ctrl+C dans `Lancer.cmd`).

---

## Logger.ps1

```powershell
Write-Log -Action 'GET /api/leads' -Status 'OK' -Ms 12
```

Sortie colorée en console : `OK` = vert, `KO` = rouge, `INFO` = gris.
