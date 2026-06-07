# ==========================================================================
#  Primitives COM Outlook
# ==========================================================================

$script:Outlook = $null

# Probe reelle via GetNamespace (detecte RPC stale 0x800706BA que .Version rate)
function Test-OutlookAlive {
    if ($null -eq $script:Outlook) { return $false }
    try { $null = $script:Outlook.GetNamespace('MAPI'); return $true } catch { return $false }
}

function Get-Outlook {
    if (-not (Test-OutlookAlive)) {
        $script:Outlook = $null
        $script:Outlook = New-Object -ComObject Outlook.Application
        $null = $script:Outlook.GetNamespace('MAPI')   # force init MAPI
    }
    return $script:Outlook
}

# Recupere l'adresse SMTP reelle (gere les comptes Exchange)
function Get-SmtpAddress($mail) {
    try {
        if ($mail.SenderEmailType -eq 'EX') {
            $exUser = $mail.Sender.GetExchangeUser()
            if ($exUser) { return $exUser.PrimarySmtpAddress }
        }
    } catch {}
    return $mail.SenderEmailAddress
}

# Devine prenom / nom depuis le nom affiche de l'expediteur
function Split-Name([string]$displayName) {
    $res = @{ prenom = ''; nom = '' }
    if ([string]::IsNullOrWhiteSpace($displayName)) { return $res }
    $dn = $displayName.Trim()
    if ($dn -match '^(.*),\s*(.*)$') {       # "Nom, Prenom"
        $res.nom = $matches[1].Trim()
        $res.prenom = $matches[2].Trim()
    } else {
        $parts = $dn -split '\s+'
        if ($parts.Count -ge 2) {
            $res.prenom = $parts[0]
            $res.nom = ($parts[1..($parts.Count-1)] -join ' ')
        } else {
            $res.prenom = $dn
        }
    }
    return $res
}
