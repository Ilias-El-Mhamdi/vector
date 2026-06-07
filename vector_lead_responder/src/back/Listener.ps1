# ==========================================================================
#  Cycle de vie du serveur
# ==========================================================================

function Start-LeadServer {
$listener = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Loopback, $Port)
$listener.Start()
$url = "http://localhost:$Port/"

Write-Host ""
Write-Host "  Suivi des leads Outlook" -ForegroundColor Cyan
Write-Host "  Serveur démarré sur $url" -ForegroundColor Green
Write-Host "  (Laissez cette fenêtre ouverte. Fermez-la pour arrêter.)" -ForegroundColor DarkGray
Write-Host ""

if ($ServeHtml) { Start-Process $url }

try {
    while ($true) {
        $client = $listener.AcceptTcpClient()
        try {
            $stream = $client.GetStream()
            $stream.ReadTimeout = 3000
            $req = Read-HttpRequest $stream
            if ($null -ne $req) {
                if ($req.method -eq 'OPTIONS') {
                    $headers = "HTTP/1.1 204 No Content`r`n" +
                               "Access-Control-Allow-Origin: http://localhost:8731`r`n" +
                               "Access-Control-Allow-Methods: GET, POST, OPTIONS`r`n" +
                               "Access-Control-Allow-Headers: Content-Type`r`n" +
                               "Content-Length: 0`r`n" +
                               "Connection: close`r`n`r`n"
                    $hb = [System.Text.Encoding]::ASCII.GetBytes($headers)
                    $stream.Write($hb, 0, $hb.Length); $stream.Flush()
                    continue
                }
                $resp = Handle-Request $req.method $req.path $req.body
                $cors = if (-not $ServeHtml) { "Access-Control-Allow-Origin: http://localhost:8731`r`n" } else { '' }
                $headers = "HTTP/1.1 $($resp.status)`r`n" +
                           "Content-Type: $($resp.contentType)`r`n" +
                           "Content-Length: $($resp.bytes.Length)`r`n" +
                           "Cache-Control: no-store`r`n" +
                           $cors +
                           "Connection: close`r`n`r`n"
                $headerBytes = [System.Text.Encoding]::ASCII.GetBytes($headers)
                $stream.Write($headerBytes, 0, $headerBytes.Length)
                if ($resp.bytes.Length -gt 0) { $stream.Write($resp.bytes, 0, $resp.bytes.Length) }
                $stream.Flush()
            }
        } catch {
            Write-Host ("Erreur connexion: " + $_.Exception.Message) -ForegroundColor DarkYellow
        } finally {
            $client.Close()
        }
    }
} finally {
    $listener.Stop()
}
}
