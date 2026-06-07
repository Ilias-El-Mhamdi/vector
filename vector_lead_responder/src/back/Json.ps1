# ==========================================================================
#  Utilitaires JSON / fichiers
# ==========================================================================

function Read-Json($path) {
    if (-not (Test-Path $path)) { return $null }
    try { $raw = [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8) } catch { return $null }
    if ([string]::IsNullOrWhiteSpace($raw)) { return $null }
    return ($raw | ConvertFrom-Json)
}

function Write-Json($path, $obj) {
    $json = $obj | ConvertTo-Json -Depth 12
    [System.IO.File]::WriteAllText($path, $json, [System.Text.UTF8Encoding]::new($false))
}

# Nettoie une adresse e-mail pour en faire un nom de dossier valide
function ConvertTo-SafeName([string]$email) {
    $name = $email.Trim().ToLower()
    foreach ($c in [System.IO.Path]::GetInvalidFileNameChars()) {
        $name = $name.Replace([string]$c, '_')
    }
    return $name
}

# Convertit un PSCustomObject (issu de ConvertFrom-Json) en hashtable ordonnee
function ConvertTo-Hashtable($obj) {
    if ($null -eq $obj) { return $null }
    if ($obj -is [System.Collections.IDictionary]) { return $obj }
    $h = [ordered]@{}
    foreach ($p in $obj.PSObject.Properties) { $h[$p.Name] = $p.Value }
    return $h
}
