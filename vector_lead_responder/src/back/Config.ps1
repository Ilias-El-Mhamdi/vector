# ==========================================================================
#  Configuration & bootstrap (chemins, dossiers)
# ==========================================================================

# $Root est defini par server.ps1 (point d'entree) via $PSScriptRoot.
$Port        = 8731
$BddDir      = Join-Path $Root 'bdd'
$LeadsDir    = Join-Path $BddDir 'leads'
$QuotesDir   = Join-Path $BddDir 'quotes'
$CatalogPath    = Join-Path $Root 'src\back\catalog.json'
$QuoteCachePath        = Join-Path $QuotesDir 'quote_cache.json'
$DeletedQuotesPath     = Join-Path $QuotesDir 'deleted_quotes.json'
$IndexPath   = Join-Path $Root 'src\front\index.html'

if (-not (Test-Path $BddDir))    { New-Item -ItemType Directory -Path $BddDir    | Out-Null }
if (-not (Test-Path $QuotesDir)) { New-Item -ItemType Directory -Path $QuotesDir | Out-Null }
if (-not (Test-Path $LeadsDir))  { New-Item -ItemType Directory -Path $LeadsDir  | Out-Null }

# Chargement env.txt
$EnvFile = Join-Path $Root 'env.txt'
if (Test-Path $EnvFile) {
    Get-Content $EnvFile -Encoding UTF8 | ForEach-Object {
        if ($_ -match '^\s*([^#=]+?)\s*=\s*(.*?)\s*$') {
            [System.Environment]::SetEnvironmentVariable($Matches[1], $Matches[2], 'Process')
        }
    }
}
