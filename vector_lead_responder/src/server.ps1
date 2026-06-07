# ============================================================================
#  Suivi des leads Outlook - Serveur local
#  - Sert l'interface index.html
#  - Lit les mails via Outlook (COM)
#  - Classe les leads et ecrit un dossier par adresse e-mail
#  - Cree le mail de reponse dans Outlook avec le devis en piece jointe
#
#  Lancer de preference via Lancer.cmd (force le mode STA).
# ============================================================================

param([int]$PortOverride = 0, [switch]$NoHtml)

$ErrorActionPreference = 'Stop'

# Racine du projet = dossier parent de src/ (entree STA lancee via Lancer.cmd)
$Root = Split-Path $PSScriptRoot -Parent

# Chargement des modules par dot-source (scope partage : $script:Outlook, $Root, ...)
# Config en premier (definit les chemins et cree les dossiers).
. "$PSScriptRoot/back/Config.ps1"
if ($PortOverride -gt 0) { $Port = $PortOverride }
$ServeHtml = -not $NoHtml.IsPresent
. "$PSScriptRoot/back/Logger.ps1"
. "$PSScriptRoot/back/Json.ps1"
. "$PSScriptRoot/back/Catalog.ps1"
. "$PSScriptRoot/back/Outlook.ps1"
. "$PSScriptRoot/back/Leads.ps1"
. "$PSScriptRoot/back/Mail.ps1"
. "$PSScriptRoot/back/Http.ps1"
. "$PSScriptRoot/back/Router.ps1"
. "$PSScriptRoot/back/Listener.ps1"

# Demarrage du serveur (boucle TcpListener)
Start-LeadServer
