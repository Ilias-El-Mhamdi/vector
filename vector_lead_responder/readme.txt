============================================================
  Suivi des leads Outlook - Vector France
  Serveur local HTTP (port 8731)
============================================================

LANCEMENT
---------
Double-cliquer sur Lancer.cmd (force le mode STA requis par Outlook COM).
Le navigateur s'ouvre automatiquement sur http://localhost:8731/


STRUCTURE DU PROJET
-------------------
Lancer.cmd              Lance src/server.ps1 en mode STA
src/
  server.ps1            Point d'entree : charge les modules et demarre le serveur
  back/
    Config.ps1          Chemins, port, creation des dossiers au demarrage
    Json.ps1            Lecture/ecriture JSON, helpers fichiers
    Catalog.ps1         Catalogue produits, detection de mots-cles dans les mails
    Outlook.ps1         Connexion COM Outlook (cache + reconnexion automatique)
    Leads.ps1           Persistance des leads, liste, detail, mise a jour
    Mail.ps1            Scan boite de reception, generation devis, envoi reponse
    Http.ps1            Infrastructure HTTP brute (TcpListener, parsing, reponses)
    Router.ps1          Dispatch des routes API (4 groupes de routes)
    Listener.ps1        Boucle principale TcpListener (Start-LeadServer)
    catalog.json        Config metier : produits, mots-cles, templates mail, filtres
    API.md              Reference complete de toutes les routes HTTP
    SCHEMA.md           Contrat canonique du schema JSON d'un lead
  front/
    index.html          Interface web (dashboard leads + devis)
    atoms/              Composants primitifs (badge, toast, busy, outlook-guard)
    molecules/          Composants composes (api, lead-item, mselect)
    organisms/          Sections completes (lead-detail, reply-draft, quote-panel)
bdd/
  leads/                Un sous-dossier par adresse email, un fichier JSON par mail
  quotes/               PDFs devis recus (recuperes depuis les mails Outlook)
env.txt                 Variables d'environnement (NON versionne) — voir ci-dessous


CONFIGURATION (src/back/catalog.json)
--------------------------------------
products            Produits a detecter avec leurs mots-cles (insensible a la casse)
options_globales    Options commerciales transversales (licence, maintenance, formation...)
replyTemplate       Corps du mail de reponse client (placeholders : {{prenom}}, {{produits}}, {{signature}})
replySubject        Objet du mail de reponse (placeholder : {{produits}})
templateAttachment  Chemin vers une PJ systematique (laisser vide si aucune)
quoteRecipient      Email interne destinataire des demandes de devis
_ignoreSenders      Expediteurs a ignorer pendant le scan (newsletters, no-reply...)

VARIABLES D'ENVIRONNEMENT (env.txt)
------------------------------------
ANTHROPIC_API_KEY       Cle API Claude (pour la generation de brouillons IA)
DEVIS_CREATEUR_MAIL     Email de l'expediteur des demandes de devis internes
REPLY_SIGNATURE         Signature apposee en bas des mails de reponse
SCAN_COUNT              Nombre de mails scanes par defaut (defaut : 50)
IGNORE_DOMAINS          Domaines a ignorer lors du scan (virgule-separes)


ROUTES API
----------
GET  /                         Sert index.html
GET  /api/catalog              Retourne catalog.json
GET  /api/config               Retourne scanCount, cle Anthropic, email expediteur, signature
GET  /api/leads                Liste tous les leads (subset : sans body ni replyDraft)
GET  /api/lead?id=...          Detail complet d'un lead (+ hasQuote, quoteName)
POST /api/lead?id=...          Met a jour un lead (patch partiel)
POST /api/lead/refresh?id=     Resynchronise sujet/corps depuis Outlook
GET  /api/outlook-status       Retourne { connected: bool }
POST /api/connect-outlook      Initialise la connexion COM Outlook
POST /api/scan?count=N         Scanne les N derniers mails (defaut 50)
POST /api/generate-quote?id=   Cree un brouillon de demande de devis interne
POST /api/send?id=...          Cree le mail de reponse Outlook avec PJ devis
POST /api/match-quote?id=      Rapproche un PDF devis depuis bdd/quotes/ avec le lead
POST /api/delete-quote?id=     Supprime le PDF devis d'un lead
POST /api/upload-quote?id=     Upload un PDF devis (base64) dans le dossier du lead
GET  /api/list-quotes          Liste les PDFs dans bdd/quotes/
GET  /api/file?id=&name=       Sert un fichier depuis le dossier d'un lead
GET  /api/raw-file?path=       Sert n'importe quel fichier du projet (acces restreint)
POST /api/open-mail?id=        Ouvre le mail original dans Outlook
POST /api/open-folder?id=      Ouvre le dossier du lead dans l'Explorateur


STATUTS D'UN LEAD
-----------------
ignore              Aucun produit detecte dans le mail
devis non demande   Produit detecte, pas encore de demande de devis
devis demande       Demande de devis envoyee au commercial interne
devis recu          PDF devis present dans le dossier du lead
traite              Mail de reponse envoye au client


PREREQUIS
---------
- Windows + Outlook installe et configure (compte mail actif)
- PowerShell 5.1+ (pre-installe sur Windows 10/11)
- Lancer.cmd execute en mode STA (requis pour le COM Outlook)
- env.txt rempli a la racine du projet (voir modele ci-dessus)

Windows Defender : ajouter une exclusion sur le dossier racine entier
(celui qui contient Lancer.cmd), pas seulement sur bdd/.
Sans ca, Defender peut bloquer l'ecriture des JSON ou la lecture des PJ.


============================================================
  NOTES / TODO
============================================================

— Déplacer catalogue dans src/config.json
— Généré la doc + mise en place d'un changeLog
- Creation de version automatisé
    — l'utilisateur doit importer bdd + env.txt
    — new_env.txt pour les nouvelles variables d'env
    — erreur front si pas de "/bdd" ou env.txt ou clé manquante
    — maj doc + changelog : docusaurus + loom
    — création du zip
    — script de migration quand c'est nécessaire
