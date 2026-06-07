# ==========================================================================
#  Routage HTTP (dispatch des routes)
# ==========================================================================

# --------------------------------------------------------------------------
#  Catalogue
# --------------------------------------------------------------------------
function Invoke-CatalogRoutes($method, $pathOnly, $q, $body) {
    if ($pathOnly -eq '/api/catalog') {
        return New-JsonResponse (Get-Catalog)
    }
    if ($pathOnly -eq '/api/config') {
        $sc = $env:SCAN_COUNT -as [int]
        if (-not $sc -or $sc -le 0) { $sc = 50 }
        return New-JsonResponse @{ scanCount = $sc; anthropicApiKey = $env:ANTHROPIC_API_KEY; devisCreateurMail = $env:DEVIS_CREATEUR_MAIL; replySignature = $env:REPLY_SIGNATURE }
    }
    return $null
}

# --------------------------------------------------------------------------
#  Leads (CRUD + upload devis + rapprochement)
# --------------------------------------------------------------------------
function Invoke-LeadsRoutes($method, $pathOnly, $q, $body) {
    if ($pathOnly -eq '/api/leads') {
        return New-JsonArrayResponse (Get-AllLeads)
    }
    if ($pathOnly -eq '/api/lead' -and $method -eq 'GET') {
        $d = Get-LeadDetail $q['id']
        if ($null -eq $d) { return New-TextResponse '404 Not Found' 'lead introuvable' }
        return New-JsonResponse $d
    }
    if ($pathOnly -eq '/api/lead' -and $method -eq 'POST') {
        $patch = $body | ConvertFrom-Json
        $d = Update-Lead $q['id'] $patch
        if ($null -eq $d) { return New-TextResponse '404 Not Found' 'lead introuvable' }
        return New-JsonResponse @{ ok = $true }
    }
    if ($pathOnly -eq '/api/lead/refresh' -and $method -eq 'POST') {
        return New-JsonResponse (Invoke-LeadRefresh $q['id'])
    }
    if ($pathOnly -eq '/api/match-quote' -and $method -eq 'POST') {
        return New-JsonResponse (Invoke-MatchQuote $q['id'])
    }
    if ($pathOnly -eq '/api/delete-quote' -and $method -eq 'POST') {
        return New-JsonResponse (Invoke-DeleteQuote $q['id'])
    }
    if ($pathOnly -eq '/api/upload-quote' -and $method -eq 'POST') {
        $payload  = $body | ConvertFrom-Json
        $leadPath = Get-LeadPath $q['id']
        $leadDir  = Split-Path $leadPath -Parent
        if (-not (Test-Path $leadDir)) { return New-TextResponse '404 Not Found' 'lead introuvable' }
        $filename = [System.IO.Path]::GetFileName([string]$payload.filename)
        if (-not $filename) { $filename = 'devis.pdf' }
        if ($filename -notmatch '\.pdf$') { $filename = [System.IO.Path]::GetFileNameWithoutExtension($filename) + '.pdf' }
        if ($q['replace'] -eq '1') {
            Get-ChildItem -Path $leadDir -Filter '*.pdf' -File -ErrorAction SilentlyContinue | Remove-Item -Force
        }
        $fileBytes = [Convert]::FromBase64String([string]$payload.data)
        [System.IO.File]::WriteAllBytes((Join-Path $leadDir $filename), $fileBytes)
        $lead = ConvertTo-Hashtable (Read-Json $leadPath)
        if ($lead) {
            $lead.hasQuote  = $true
            $lead.quoteName = $filename
            $lead.quoteId   = if ($filename -match '^QUOTE_(\d+)_') { $Matches[1] } else { '' }
            if ($lead.status -ne 'traite') {
                $lead.status    = 'devis recu'
                $lead.updatedAt = (Get-Date).ToString('s')
            }
            Write-Json $leadPath $lead
        }
        return New-JsonResponse @{ ok = $true; filename = $filename; quoteId = $lead.quoteId }
    }
    return $null
}

# --------------------------------------------------------------------------
#  Actions Outlook (scan, devis, envoi, ouverture)
# --------------------------------------------------------------------------
function Invoke-MailRoutes($method, $pathOnly, $q, $body) {
    if ($pathOnly -eq '/api/outlook-status' -and $method -eq 'GET') {
        return New-JsonResponse @{ connected = (Test-OutlookAlive) }
    }
    if ($pathOnly -eq '/api/connect-outlook' -and $method -eq 'POST') {
        $null = Get-Outlook
        return New-JsonResponse @{ ok = $true }
    }
    if ($pathOnly -eq '/api/scan' -and $method -eq 'POST') {
        $count = 50
        if ($q['count']) { [int]::TryParse($q['count'], [ref]$count) | Out-Null }
        return New-JsonResponse (Invoke-Scan $count)
    }
    if ($pathOnly -eq '/api/generate-quote' -and $method -eq 'POST') {
        $preview    = ($q['preview'] -eq '1')
        $payload    = $null
        try { $payload = $body | ConvertFrom-Json } catch {}
        $quoteDraft = if ($payload -and $payload.quoteDraft) { [string]$payload.quoteDraft } else { '' }
        return New-JsonResponse (Invoke-GenerateQuote $q['id'] $preview $quoteDraft)
    }
    if ($pathOnly -eq '/api/send' -and $method -eq 'POST') {
        $direct = ($q['direct'] -eq '1')
        $payload = $null
        try { $payload = $body | ConvertFrom-Json } catch {}
        $replyText = if ($payload -and $payload.replyDraft) { [string]$payload.replyDraft } else { '' }
        return New-JsonResponse (Invoke-Send $q['id'] $direct $replyText)
    }
    if ($pathOnly -eq '/api/open-mail' -and $method -eq 'POST') {
        $lead = Read-Json (Get-LeadPath $q['id'])
        if ($null -eq $lead) { return New-TextResponse '404 Not Found' 'lead introuvable' }
        $entryId = [string]$lead.entryId
        if ([string]::IsNullOrWhiteSpace($entryId)) { return New-TextResponse '400 Bad Request' 'pas d entryId' }
        $ol = Get-Outlook
        $ns = $ol.GetNamespace('MAPI')
        try { $item = $ns.GetItemFromID($entryId); $item.Display($false) } catch { throw "Mail introuvable dans Outlook (entryId invalide ou boite incorrecte)" }
        return New-JsonResponse @{ ok = $true }
    }
    if ($pathOnly -eq '/api/open-folder' -and $method -eq 'POST') {
        $leadDir = Split-Path (Get-LeadPath $q['id']) -Parent
        if (Test-Path $leadDir) { Start-Process explorer.exe $leadDir }
        return New-JsonResponse @{ ok = $true }
    }
    return $null
}

# --------------------------------------------------------------------------
#  Fichiers (devis PDF, fichiers lead, fichiers statiques)
# --------------------------------------------------------------------------
function Invoke-FileRoutes($method, $pathOnly, $q, $body) {
    if ($pathOnly -eq '/api/list-quotes' -and $method -eq 'GET') {
        return New-JsonArrayResponse (Get-QuotesList)
    }
    if ($pathOnly -eq '/api/raw-file' -and $method -eq 'GET') {
        $file = Decode-Url $q['path']
        if (-not $file.StartsWith($Root)) { return New-TextResponse '403 Forbidden' 'Acces refuse' }
        if (-not (Test-Path $file))       { return New-TextResponse '404 Not Found' 'Fichier introuvable' }
        return New-Response '200 OK' (Get-ContentType $file) ([System.IO.File]::ReadAllBytes($file))
    }

    if ($pathOnly -eq '/api/file' -and $method -eq 'GET') {
        $leadPath = Get-LeadPath $q['id']
        $leadDir  = Split-Path $leadPath -Parent
        $file = Join-Path $leadDir ([System.IO.Path]::GetFileName($q['name']))
        if (-not (Test-Path $file)) { return New-TextResponse '404 Not Found' 'fichier introuvable' }
        return New-Response '200 OK' (Get-ContentType $file) ([System.IO.File]::ReadAllBytes($file))
    }
    if ($method -eq 'GET' -and $pathOnly -match '\.(js|css)$') {
        $relative = $pathOnly.TrimStart('/').Replace('/', [System.IO.Path]::DirectorySeparatorChar)
        $file     = Join-Path (Join-Path $Root 'src\front') $relative
        if (-not (Test-Path $file)) { return New-TextResponse '404 Not Found' 'Fichier introuvable' }
        return New-Response '200 OK' (Get-ContentType $file) ([System.IO.File]::ReadAllBytes($file))
    }
    if ($pathOnly -eq '/' -or $pathOnly -eq '/index.html') {
        if (-not $ServeHtml) { return New-TextResponse '404 Not Found' 'not available' }
        return New-Response '200 OK' 'text/html; charset=utf-8' ([System.IO.File]::ReadAllBytes($IndexPath))
    }
    return $null
}

# --------------------------------------------------------------------------
#  Dispatcher principal
# --------------------------------------------------------------------------
function Handle-Request([string]$method, [string]$rawPath, [string]$body) {
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $pathOnly = $rawPath
    $qs = ''
    $qIdx = $rawPath.IndexOf('?')
    if ($qIdx -ge 0) {
        $pathOnly = $rawPath.Substring(0, $qIdx)
        $qs       = $rawPath.Substring($qIdx + 1)
    }
    $q = Parse-Query $qs

    if ($pathOnly.StartsWith('/api')) { Write-Log "$method $pathOnly" 'INFO' }

    try {
        foreach ($handler in @(
            { Invoke-CatalogRoutes $method $pathOnly $q $body },
            { Invoke-LeadsRoutes   $method $pathOnly $q $body },
            { Invoke-MailRoutes    $method $pathOnly $q $body },
            { Invoke-FileRoutes    $method $pathOnly $q $body }
        )) {
            $resp = & $handler
            if ($null -ne $resp) {
                $sw.Stop()
                $status = if ($pathOnly.StartsWith('/api')) { 'OK' } else { 'INFO' }
                Write-Log "$method $pathOnly" $status $sw.ElapsedMilliseconds
                return $resp
            }
        }
        $sw.Stop()
        Write-Log "$method $pathOnly" 'KO' $sw.ElapsedMilliseconds '404'
        return New-TextResponse '404 Not Found' "Route inconnue: $pathOnly"
    }
    catch {
        $sw.Stop()
        Write-Log "$method $pathOnly" 'KO' $sw.ElapsedMilliseconds $_.Exception.Message
        return New-Response '500 Internal Server Error' 'application/json; charset=utf-8' `
            ([System.Text.Encoding]::UTF8.GetBytes((@{ error = $_.Exception.Message } | ConvertTo-Json)))
    }
}
