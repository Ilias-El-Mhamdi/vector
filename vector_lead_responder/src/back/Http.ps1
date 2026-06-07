# ==========================================================================
#  Infrastructure HTTP (TcpListener)
# ==========================================================================

function Get-ContentType([string]$path) {
    switch ([System.IO.Path]::GetExtension($path).ToLower()) {
        '.html' { 'text/html; charset=utf-8' }
        '.json' { 'application/json; charset=utf-8' }
        '.pdf'  { 'application/pdf' }
        '.png'  { 'image/png' }
        '.jpg'  { 'image/jpeg' }
        '.css'  { 'text/css; charset=utf-8' }
        '.js'   { 'application/javascript; charset=utf-8' }
        default { 'application/octet-stream' }
    }
}

function New-Response($status, $contentType, $bytes) {
    return @{ status = $status; contentType = $contentType; bytes = $bytes }
}
function New-JsonResponse($obj) {
    $json = $obj | ConvertTo-Json -Depth 12
    if ($null -eq $json) { $json = 'null' }
    New-Response '200 OK' 'application/json; charset=utf-8' ([System.Text.Encoding]::UTF8.GetBytes($json))
}
# Force une serialisation en TABLEAU JSON (gere 0 et 1 element, que PowerShell deballe sinon)
function New-JsonArrayResponse($arr) {
    $a = @($arr | Where-Object { $null -ne $_ })
    if ($a.Count -eq 0) {
        $json = '[]'
    } elseif ($a.Count -eq 1) {
        $json = '[' + ($a[0] | ConvertTo-Json -Depth 12) + ']'
    } else {
        $json = ConvertTo-Json -InputObject $a -Depth 12
    }
    New-Response '200 OK' 'application/json; charset=utf-8' ([System.Text.Encoding]::UTF8.GetBytes($json))
}
function New-TextResponse($status, $text) {
    New-Response $status 'text/plain; charset=utf-8' ([System.Text.Encoding]::UTF8.GetBytes($text))
}

# Decode les %xx d'une querystring
function Decode-Url([string]$s) { [System.Uri]::UnescapeDataString($s) }

function Parse-Query([string]$qs) {
    $h = @{}
    if ([string]::IsNullOrWhiteSpace($qs)) { return $h }
    foreach ($pair in $qs.Split('&')) {
        $kv = $pair.Split('=', 2)
        $k = Decode-Url $kv[0]
        $v = if ($kv.Count -gt 1) { Decode-Url $kv[1] } else { '' }
        $h[$k] = $v
    }
    return $h
}

function Read-HttpRequest($stream) {
    # Sur localhost les données arrivent en <10ms — si rien après 500ms c'est une connexion morte
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    while (-not $stream.DataAvailable -and $sw.ElapsedMilliseconds -lt 500) {
        [System.Threading.Thread]::Sleep(5)
    }
    if (-not $stream.DataAvailable) { return $null }

    $ms = New-Object System.IO.MemoryStream
    $buf = New-Object byte[] 8192
    $headerEnd = -1
    $sep = [byte[]](13,10,13,10)

    while ($true) {
        $read = $stream.Read($buf, 0, $buf.Length)
        if ($read -le 0) { break }
        $ms.Write($buf, 0, $read)
        $arr = $ms.ToArray()
        $headerEnd = Find-Sep $arr $sep
        if ($headerEnd -ge 0) {
            # On a tous les headers, verifier Content-Length
            $headerText = [System.Text.Encoding]::ASCII.GetString($arr, 0, $headerEnd)
            $clen = 0
            foreach ($line in ($headerText -split "`r`n")) {
                if ($line -match '^(?i)Content-Length:\s*(\d+)') { $clen = [int]$matches[1] }
            }
            $bodyStart = $headerEnd + 4
            $have = $arr.Length - $bodyStart
            if ($have -ge $clen) { break }
        }
    }

    $arr = $ms.ToArray()
    if ($headerEnd -lt 0) { return $null }
    $headerText = [System.Text.Encoding]::ASCII.GetString($arr, 0, $headerEnd)
    $lines = $headerText -split "`r`n"
    $requestLine = $lines[0] -split ' '
    $method = $requestLine[0]
    $path = $requestLine[1]
    $clen = 0
    foreach ($line in $lines) { if ($line -match '^(?i)Content-Length:\s*(\d+)') { $clen = [int]$matches[1] } }
    $bodyStart = $headerEnd + 4
    $bodyStr = ''
    if ($clen -gt 0 -and ($arr.Length - $bodyStart) -ge $clen) {
        $bodyStr = [System.Text.Encoding]::UTF8.GetString($arr, $bodyStart, $clen)
    }
    return @{ method = $method; path = $path; body = $bodyStr }
}

# Cherche la sequence $sep dans $arr, retourne l'index ou -1
function Find-Sep([byte[]]$arr, [byte[]]$sep) {
    $max = $arr.Length - $sep.Length
    for ($i = 0; $i -le $max; $i++) {
        $ok = $true
        for ($j = 0; $j -lt $sep.Length; $j++) {
            if ($arr[$i + $j] -ne $sep[$j]) { $ok = $false; break }
        }
        if ($ok) { return $i }
    }
    return -1
}
