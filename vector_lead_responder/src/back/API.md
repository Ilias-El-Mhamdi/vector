# API — référence des routes (port 8731)

Toutes les routes sont préfixées `/api/`. Les paramètres d'URL sont des query strings ; les corps de requête sont du JSON.

---

## Catalogue

### `GET /api/catalog`
Retourne le contenu de `catalog.json` (produits, options, destinataire devis, template de réponse…).  
**Quand :** au démarrage de l'app (`app.js → loadCatalog`), une seule fois, pour alimenter `CATALOG`.

### `GET /api/config`
Retourne la configuration runtime issue de `env.txt` : `{ scanCount, anthropicApiKey, devisCreateurMail, replySignature }`.  
**Quand :** `app.js → init()` — injecte la clé Anthropic dans `window._anthropicKey`, la signature dans `window._replySignature`, et préremplit le champ `scanCount`.

---

## Leads

### `GET /api/leads`
Retourne la liste allégée de tous les leads (sans `body` ni `replyDraft`).  
**Quand :** au chargement initial et après chaque opération qui modifie la liste (scan, envoi, changement de statut).

### `GET /api/lead?id=<id>`
Retourne le détail complet d'un lead : tous les champs JSON + `hasQuote` (bool) + `quoteName` (string).  
**Quand :** à l'ouverture d'un lead dans le panneau de détail (`openLead`), et après un upload / match de devis pour rafraîchir `CURRENT`.

### `POST /api/lead?id=<id>`
**Body :** objet JSON avec les champs à patcher (`status`, `replyDraft`, `quoteDraft`, etc.).  
Met à jour partiellement le fichier JSON du lead.  
**Quand :**
- `lead-detail.js → changeStatus` : changement de statut via le badge cliquable.
- `reply-draft.js → scheduleAutoSave` : sauvegarde automatique (debounce 800 ms) du brouillon de réponse.
- `quote-panel.js → quoteDraftAutoSave` : sauvegarde automatique du brouillon de demande de devis.

### `POST /api/lead/refresh?id=<id>`
Re-lit `subject` et `body` depuis Outlook via `entryId`, met à jour le fichier JSON, retourne le lead complet.  
**Quand :** bouton "Rafraîchir" dans `lead-detail.js`, pour récupérer un corps de mail qui était vide lors du scan.

### `POST /api/match-quote?id=<id>`
Cherche dans `bdd/quotes/` un PDF `QUOTE_*.pdf` dont l'e-mail extrait correspond au lead, le copie dans le dossier du lead et passe le statut à `devis recu`.  
**Quand :** `quote-panel.js → tryMatchQuote` — appelé automatiquement à l'ouverture d'un lead sans devis, et manuellement via le bouton "🔍 Rechercher devis".

### `POST /api/delete-quote?id=<id>`
Supprime tous les PDF du dossier du lead, efface `hasQuote` / `quoteName` / `quoteId` dans le JSON, repasse le statut à `devis demande` si le lead était en `devis recu`.  
**Quand :** `quote-panel.js` — bouton "🗑 Supprimer le devis".

### `POST /api/upload-quote?id=<id>[&replace=1]`
**Body :** `{ filename, data }` — `data` est le PDF encodé en base64.  
Écrit le PDF dans le dossier du lead, passe le statut à `devis recu` (sauf si déjà `traite`). `replace=1` supprime les PDF existants avant d'écrire.  
**Quand :** `quote-panel.js → quoteUploadFile` — drag-and-drop ou sélection de fichier dans le panneau devis.

---

## Actions Outlook

### `GET /api/outlook-status`
Retourne `{ connected: bool }` — vérifie si le cache COM Outlook est actif et répond.  
**Quand :** `atoms/outlook-guard.js → withOutlook()` avant chaque opération Outlook.

### `POST /api/connect-outlook`
Force l'initialisation du client COM Outlook (cache interne).  
**Quand :** `app.js → init()` au démarrage, avant tout autre appel Outlook.

### `POST /api/scan[?count=N]`
Lit les `N` derniers mails de la boîte de réception (défaut 50), crée les leads manquants, détecte les pièces jointes `QUOTE_*.pdf` entrantes.  
**Quand :** bouton "Scanner" dans `app.js → scan()`.

### `POST /api/generate-quote?id=<id>[&preview=1]`
**Body :** `{ quoteDraft }` (optionnel — texte libre à utiliser comme corps du mail).  
Sans `preview` : envoie le mail de demande de devis en interne et passe le statut à `devis demande`.  
Avec `preview=1` : ouvre le brouillon dans Outlook sans l'envoyer.  
**Quand :** `quote-panel.js` — bouton "📋 Générer devis" (sans preview) ou "👁 Voir dans Outlook" (avec preview).

### `POST /api/send?id=<id>[&direct=1]`
**Body :** `{ replyDraft }` (optionnel — texte du mail de réponse).  
Sans `direct` : ouvre le brouillon de réponse dans Outlook avec le devis en PJ.  
Avec `direct=1` : envoie directement. Dans les deux cas, passe le statut à `traite`.  
**Quand :** `reply-draft.js → sendLead` — bouton "Ouvrir dans Outlook" ou "Envoyer directement".

### `POST /api/open-mail?id=<id>`
Ouvre le mail original du lead dans Outlook via son `entryId`.  
**Quand :** bouton "📧 Ouvrir le mail" dans `lead-detail.js`.

### `POST /api/open-folder?id=<id>`
Ouvre dans l'Explorateur Windows le dossier `bdd/leads/` du lead.  
**Quand :** bouton "📁 Ouvrir le dossier" dans `lead-detail.js`.

---

## Fichiers

### `GET /api/list-quotes`
Liste les fichiers `QUOTE_*.pdf` disponibles dans `bdd/quotes/`.  
*(Non utilisé côté front actuellement — réservé.)*

### `GET /api/file?id=<id>&name=<filename>`
Sert un fichier (PDF devis, image…) depuis le dossier du lead.  
**Quand :** `quote-panel.js` — `<iframe>` d'aperçu du devis : `src="/api/file?id=...&name=..."`.

### `GET /api/raw-file?path=<chemin_absolu>`
Sert n'importe quel fichier à l'intérieur de `$Root`. Vérifie que le chemin reste sous la racine du projet (protection path traversal).  
**Quand :** ⚠️ non appelée par le front actuellement — route préparée, jamais utilisée.

### `GET /<chemin>.js` / `GET /<chemin>.css`
Sert les fichiers statiques du frontend depuis `src/front/`.  
**Quand :** chargement initial de la page par le navigateur.

### `GET /` ou `GET /index.html`
Sert `index.html` (uniquement si `$ServeHtml` est actif).

---

## Codes de retour courants

| Code | Signification |
|------|---------------|
| 200 | Succès |
| 400 | Paramètre manquant ou invalide (ex : `entryId` absent) |
| 403 | Accès refusé (path traversal sur `/api/raw-file`) |
| 404 | Lead, fichier ou route introuvable |
| 500 | Exception PowerShell — corps JSON `{ "error": "..." }` |
