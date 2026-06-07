# Suivi des leads Outlook — Vector France

Application desktop Windows qui détecte des leads commerciaux dans Outlook et gère le workflow devis → envoi.

## Stack & contraintes

| Couche | Technologie |
|--------|-------------|
| Backend | PowerShell 5.1+, STA obligatoire |
| Outlook | COM (`Microsoft.Office.Interop.Outlook`), Windows uniquement |
| HTTP | `System.Net.Sockets.TcpListener` custom, port **8731** |
| Frontend | Vanilla JS (pas de framework, pas de bundler, pas de npm) |
| Données | Fichiers JSON dans `bdd/` (pas de base de données) |

Démarrage : double-cliquer `Lancer.cmd` (force STA). Ne pas lancer `server.ps1` directement depuis un shell IST/non-STA — les appels COM Outlook échoueront.

---

## Backend — ordre de chargement (dot-source)

`server.ps1` charge les modules dans cet ordre exact. L'ordre compte : les modules suivants dépendent des variables définies par les précédents (notamment `$Root`, `$LeadsDir`, `$Port`).

```
Config.ps1   → chemins ($Root, $BddDir, $LeadsDir, $QuotesDir, $CatalogPath), port, chargement env.txt
Json.ps1     → Read-Json, Write-Json, ConvertTo-Hashtable, ConvertTo-SafeName
Catalog.ps1  → Get-Catalog, Find-Matches
Outlook.ps1  → Get-Outlook (cache COM), Test-OutlookAlive, Invoke-LeadRefresh
Leads.ps1    → Get-AllLeads, Get-LeadDetail, Update-Lead, Get-LeadPath, Get-QuotesList, Invoke-MatchQuote, Invoke-DeleteQuote
Mail.ps1     → Invoke-Scan, Invoke-GenerateQuote, Invoke-Send
Http.ps1     → New-JsonResponse, New-JsonArrayResponse, New-TextResponse, New-Response, Parse-Query, Read-HttpRequest
Router.ps1   → Handle-Request, Invoke-CatalogRoutes, Invoke-LeadsRoutes, Invoke-MailRoutes, Invoke-FileRoutes
Listener.ps1 → Start-LeadServer (boucle TcpListener principale)
```

Toutes les variables de `Config.ps1` (`$Port`, `$LeadsDir`, etc.) sont des **globales dot-sourcées** — elles ne sont pas passées en paramètre, elles sont visibles par tous les modules suivants dans le même scope.

---

## Frontend — ordre de chargement JS

`index.html` charge les scripts dans cet ordre. Pas de module ES6, pas d'import — l'ordre des balises `<script>` est la seule résolution de dépendances.

```
atoms/toast.js      → toast()
atoms/badge.js      → STATUS_LABELS, statusClass(), renderBadge(), renderChip()
molecules/api.js    → api(), esc(), fullName()
molecules/mselect.js → buildPanel(), toggleMSelect(), getChecked(), onFilterChange()
molecules/lead-item.js → renderLeadItem()
organisms/reply-draft.js → renderReplyCard(), scheduleAutoSave()
organisms/quote-panel.js → renderQuotePanel()
organisms/lead-detail.js → renderDetail(), changeStatus()
app.js              → LEADS, CATALOG, CURRENT (état global), loadLeads(), render(), openLead(), scan()
```

**Règles par layer :**
- **Atoms** : fonctions pures, pas d'appel `api()`, pas de lecture de `LEADS`/`CURRENT`
- **Molecules** : helpers et rendus composés, `api()` autorisé, pas de mutation d'état global
- **Organisms** : sections complètes, peuvent appeler `api()` et lire `CURRENT`/`CATALOG`
- **app.js** : seul endroit qui mute `LEADS`, `CATALOG`, `CURRENT`

---

## Ajouter une route backend

1. Dans `Router.ps1`, ajouter le handler dans la fonction `Invoke-*Routes` appropriée (Catalog / Leads / Mail / File) ou créer une nouvelle `Invoke-*Routes` et l'ajouter au tableau du dispatcher dans `Handle-Request`.
2. Pattern standard :
   ```powershell
   if ($pathOnly -eq '/api/ma-route' -and $method -eq 'POST') {
       $payload = $body | ConvertFrom-Json
       return New-JsonResponse (Ma-Fonction $q['id'] $payload)
   }
   ```
3. Erreurs : `throw "message"` — `Handle-Request` attrape tout et retourne 500 avec le message.
4. Pour les 404 : `return New-TextResponse '404 Not Found' 'message'`

---

## Ajouter un composant frontend

1. Choisir le bon layer (voir règles ci-dessus).
2. Créer le fichier dans le bon dossier (`atoms/`, `molecules/`, `organisms/`).
3. Ajouter la balise `<script src="...">` dans `index.html` au bon endroit (après ses dépendances, avant ses consommateurs).
4. Pas de `export`/`import` — les fonctions sont globales au `window`.

---

## Machine à états des leads

Pipeline dans l'ordre (valeur JSON → signification) :

```
ignore             → aucun produit Vector détecté
devis non demande  → produit détecté, devis interne pas encore envoyé
devis demande      → mail de demande de devis envoyé en interne
devis recu         → PDF devis reçu et attaché au lead
traite             → mail de réponse envoyé au client
```

Ces valeurs sont des **string literals** aujourd'hui (à canonicaliser via `$LEAD_STATUSES` dans `Config.ps1` — voir plan maintenabilité P1-E).

Côté JS, `STATUS_LABELS` dans `badge.js` et `ALL_STATUSES` dans `mselect.js` doivent rester synchronisés avec ces valeurs.

---

## Schéma Lead JSON

Voir [`src/back/SCHEMA.md`](src/back/SCHEMA.md) pour la définition canonique.

En résumé : chaque lead est un fichier `bdd/leads/{safeemail}/{timestamp}_{safeemail}.json`.
L'API `/api/leads` retourne un **subset** (sans `body`, sans `replyDraft`).
L'API `/api/lead?id=...` retourne le **détail complet** + `hasQuote` (bool) + `quoteName` (string).

---

## Dette connue

| Élément | État | Action |
|---------|------|--------|
| `l.items[]{produit, quantite}` dans `lead-item.js` | Schéma futur, backend pas encore implémenté | Implémenter côté PS quand besoin |
| `STATUS_LABELS` dans `badge.js` et `ALL_STATUSES` dans `mselect.js` | Dupliqués — doivent rester synchronisés manuellement | Créer `atoms/status.js` unique (voir `plan/maintenabilite.md` P2-C) |
| Machine à états en string literals éparpillés | `Mail.ps1`, `Leads.ps1`, `badge.js`, `mselect.js` | Ajouter `$LEAD_STATUSES` dans `Config.ps1` (voir plan P1-E) |
