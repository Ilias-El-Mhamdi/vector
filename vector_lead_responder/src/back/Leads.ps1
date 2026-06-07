# ==========================================================================
#  Depot des leads & devis
# ==========================================================================

function Get-LeadDir([string]$email) {
    Join-Path $LeadsDir (ConvertTo-SafeName $email)
}

# Retourne le 1er PDF trouve dans le dossier du lead (le devis), sinon $null
function Get-QuoteFile([string]$leadDir) {
    if (-not (Test-Path $leadDir)) { return $null }
    $pdf = Get-ChildItem -Path $leadDir -Filter '*.pdf' -File -ErrorAction SilentlyContinue |
           Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($pdf) { return $pdf.FullName }
    return $null
}

# ---- Rapprochement devis (lecture PDF) ------------------------------------

# Helper C# : ASCII85 decode + inflate zlib sans les subtilites de boxing PowerShell
if (-not ([System.Management.Automation.PSTypeName]'PdfStreamHelper').Type) {
    Add-Type -Language CSharp -TypeDefinition @'
using System;
using System.IO;
using System.IO.Compression;
using System.Collections.Generic;
public static class PdfStreamHelper {
    public static byte[] DecodeAscii85(byte[] data) {
        string s = System.Text.Encoding.ASCII.GetString(data)
                       .Replace(" ","").Replace("\n","").Replace("\r","").Replace("\t","");
        int end = s.IndexOf("~>", StringComparison.Ordinal);
        if (end >= 0) s = s.Substring(0, end);
        var result = new List<byte>();
        int i = 0;
        while (i < s.Length) {
            if (s[i] == 'z') { result.AddRange(new byte[]{0,0,0,0}); i++; continue; }
            int len = Math.Min(5, s.Length - i);
            long val = 0;
            for (int k = 0; k < len; k++) val = val * 85 + (s[i+k] - 33);
            for (int k = len; k < 5; k++) val = val * 85 + 84;
            for (int p = 3; p >= 4 - (len - 1); p--)
                result.Add((byte)((val >> (p * 8)) & 0xFF));
            i += len;
        }
        return result.ToArray();
    }
    public static byte[] Inflate(byte[] data) {
        using (var ms = new MemoryStream(data, 2, data.Length - 2))
        using (var ds = new DeflateStream(ms, CompressionMode.Decompress))
        using (var output = new MemoryStream()) {
            ds.CopyTo(output);
            return output.ToArray();
        }
    }
}
'@
}

# Decompresse un stream zlib et decode les hex-strings PDF <xx> en texte lisible.
function Expand-PdfStream([byte[]]$raw) {
    $isZlib = $raw.Length -gt 2 -and $raw[0] -eq 0x78 -and
              ($raw[1] -eq 0x9C -or $raw[1] -eq 0x01 -or $raw[1] -eq 0xDA -or $raw[1] -eq 0x5E)
    if (-not $isZlib) { return $null }
    try {
        $inflated = [PdfStreamHelper]::Inflate($raw)
        if ($inflated.Length -eq 0) { return $null }
        $text = [System.Text.Encoding]::GetEncoding(28591).GetString($inflated)
        $text = [regex]::Replace($text, '<([0-9A-Fa-f]+)>', {
            param($hm)
            try {
                $hex = $hm.Groups[1].Value
                $b   = [byte[]]::new($hex.Length / 2)
                for ($k = 0; $k -lt $b.Length; $k++) { $b[$k] = [Convert]::ToByte($hex.Substring($k*2, 2), 16) }
                [System.Text.Encoding]::GetEncoding(28591).GetString($b)
            } catch { '' }
        })
        return $text
    } catch { return $null }
}

# Extrait tous les emails d'un PDF.
# Gere : texte en clair, ASCII85+FlateDecode (ReportLab), FlateDecode+hex-strings (devis Vector).
function Get-EmailFromPdf([string]$path) {
    try {
        $bytes = [System.IO.File]::ReadAllBytes($path)
        $latin = [System.Text.Encoding]::GetEncoding(28591).GetString($bytes)

        # Scan rapide : email en clair (PDFs non compresses)
        $m = [regex]::Match($latin, '[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}')
        if ($m.Success) { return @($m.Value.ToLower()) }

        $streamRx = [regex]::new('stream\r?\n(.+?)(?:\r?\n)?endstream',
            [System.Text.RegularExpressions.RegexOptions]::Singleline)
        $filterRx = [regex]::new('/Filter\s*(\[.*?\]|/\S+)',
            [System.Text.RegularExpressions.RegexOptions]::Singleline)
        $emailRx  = [regex]::new('(?<![a-zA-Z0-9])([a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,4})(?![a-zA-Z0-9])')
        $allEmails = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)

        foreach ($sm in $streamRx.Matches($latin)) {
            $lookback = [Math]::Min(400, $sm.Index)
            $before   = $latin.Substring($sm.Index - $lookback, $lookback)
            $fMatch   = $filterRx.Match($before)
            $filters  = if ($fMatch.Success) { $fMatch.Groups[1].Value } else { '' }
            $raw      = [System.Text.Encoding]::GetEncoding(28591).GetBytes($sm.Groups[1].Value)
            try {
                if ($filters -match 'ASCII85') { $raw = [PdfStreamHelper]::DecodeAscii85($raw) }
                $decoded = Expand-PdfStream $raw
                if (-not $decoded) { $decoded = [System.Text.Encoding]::GetEncoding(28591).GetString($raw) }
                foreach ($em in $emailRx.Matches($decoded)) { $null = $allEmails.Add($em.Groups[1].Value.ToLower()) }
            } catch {}
        }
        return @($allEmails)
    } catch {}
    return @()
}

function Get-QuoteCache {
    # Retourne toujours un Hashtable (pas OrderedDictionary) pour que .ContainsKey() marche
    $h = [hashtable]@{}
    if (Test-Path $QuoteCachePath) {
        $raw = ConvertTo-Hashtable (Read-Json $QuoteCachePath)
        if ($raw) { foreach ($k in @($raw.Keys)) { $h[$k] = $raw[$k] } }
    }
    return $h
}

function Save-QuoteCache([hashtable]$cache) {
    Write-Json $QuoteCachePath $cache
}

function Invoke-MatchQuote([string]$id) {
    $sw        = [System.Diagnostics.Stopwatch]::StartNew()
    $path      = Get-LeadPath $id
    $lead      = ConvertTo-Hashtable (Read-Json $path)
    if ($null -eq $lead) { throw "Lead introuvable" }
    $leadEmail = ([string]$lead.email).ToLower()
    $leadDir   = Split-Path $path -Parent   # sous-dossier du lead

    # Cache structure : { leadId -> pdfName }
    $cache = Get-QuoteCache

    # Ce lead a deja une quote assignee
    if ($cache.ContainsKey($id)) {
        $sw.Stop()
        Write-Log "MatchQuote" 'OK' $sw.ElapsedMilliseconds "cache hit: $($cache[$id])"
        return @{ matched = $true; quoteName = $cache[$id] }
    }

    # Set des PDFs supprimes volontairement (ne pas re-matcher)
    $deletedCache = [hashtable]@{}
    if (Test-Path $DeletedQuotesPath) {
        $raw = ConvertTo-Hashtable (Read-Json $DeletedQuotesPath)
        if ($raw) { foreach ($k in @($raw.Keys)) { $deletedCache[$k] = $raw[$k] } }
    }
    $deletedPdfs = [System.Collections.Generic.HashSet[string]]::new(
        [string[]]@($deletedCache.Values | Where-Object { $_ }),
        [StringComparer]::OrdinalIgnoreCase
    )

    # Set des PDFs deja assignes a d'autres leads (valeurs du cache)
    $assignedPdfs = [System.Collections.Generic.HashSet[string]]::new(
        [string[]]@($cache.Values | Where-Object { $_ }),
        [StringComparer]::OrdinalIgnoreCase
    )

    $pdfs = Get-ChildItem -Path $QuotesDir -Filter 'QUOTE_*.pdf' -File -ErrorAction SilentlyContinue
    Write-Log "MatchQuote" 'INFO' 0 "lead=$leadEmail pdfs=$($pdfs.Count)"
    foreach ($pdf in $pdfs) {
        if ($assignedPdfs.Contains($pdf.Name)) { continue }
        if ($deletedPdfs.Contains($pdf.Name))  { continue }

        $foundEmails = @(Get-EmailFromPdf $pdf.FullName | Where-Object { $_ })
        if ($foundEmails -contains $leadEmail) {
            $dest = Join-Path $leadDir $pdf.Name
            try { Copy-Item -Path $pdf.FullName -Destination $dest -Force } catch {}

            $cache[$id] = $pdf.Name
            Save-QuoteCache $cache

            $quoteId = if ($pdf.Name -match '^QUOTE_(\d+)_') { $Matches[1] } else { '' }

            $lead.hasQuote  = $true
            $lead.quoteName = $pdf.Name
            $lead.quoteId   = $quoteId
            if ($lead.status -ne 'traite') {
                $lead.status    = 'devis recu'
                $lead.updatedAt = (Get-Date).ToString('s')
            }
            Write-Json $path $lead
            $sw.Stop()
            Write-Log "MatchQuote" 'OK' $sw.ElapsedMilliseconds $pdf.Name
            return @{ matched = $true; quoteName = $pdf.Name; quoteId = $quoteId }
        }
    }
    $sw.Stop()
    Write-Log "MatchQuote" 'OK' $sw.ElapsedMilliseconds 'aucun match'
    return @{ matched = $false }
}

# ---- Supprime le devis d'un lead et le blackliste du matching automatique ---
function Invoke-DeleteQuote([string]$id) {
    $path    = Get-LeadPath $id
    $lead    = ConvertTo-Hashtable (Read-Json $path)
    if ($null -eq $lead) { throw "Lead introuvable" }

    $leadDir  = Split-Path $path -Parent
    $quoteName = [string]$lead.quoteName

    # 1. Supprimer le fichier PDF du dossier du lead
    if ($quoteName) {
        $pdfPath = Join-Path $leadDir $quoteName
        if (Test-Path $pdfPath) { Remove-Item -Path $pdfPath -Force }
    }

    # 2. Retirer l'entree du cache
    $cache = Get-QuoteCache
    if ($cache.ContainsKey($id)) {
        $cache.Remove($id)
        Save-QuoteCache $cache
    }

    # 3. Ajouter dans deleted_quotes.json pour exclure du matching futur
    if ($quoteName) {
        $deleted = [hashtable]@{}
        if (Test-Path $DeletedQuotesPath) {
            $raw = ConvertTo-Hashtable (Read-Json $DeletedQuotesPath)
            if ($raw) { foreach ($k in @($raw.Keys)) { $deleted[$k] = $raw[$k] } }
        }
        $deleted[$id] = $quoteName
        Write-Json $DeletedQuotesPath $deleted
    }

    # 4. Mettre a jour le lead (retirer hasQuote / quoteName, repasser a devis demande si applicable)
    $lead.hasQuote  = $false
    $lead.quoteName = ''
    if ($lead.status -eq 'devis recu') {
        $lead.status = 'devis demande'
    }
    $lead.updatedAt = (Get-Date).ToString('s')
    Write-Json $path $lead

    return @{ ok = $true; status = [string]$lead.status }
}

# ---- Utilitaire : chemin absolu depuis un id relatif -----------------------
function Get-LeadPath([string]$id) {
    # id = "safeemail/20240730T120000_safeemail.json"
    $safe = $id.Replace('/', [System.IO.Path]::DirectorySeparatorChar)
    Join-Path $LeadsDir $safe
}

# ---- Liste / detail des leads ----------------------------------------------
function Get-AllLeads {
    $swTotal = [System.Diagnostics.Stopwatch]::StartNew()
    if (-not (Test-Path $LeadsDir)) { return @() }
    $list = New-Object System.Collections.Generic.List[object]
    foreach ($f in (Get-ChildItem -Path $LeadsDir -Filter '*.json' -Recurse -File -ErrorAction SilentlyContinue)) {
        $swItem = [System.Diagnostics.Stopwatch]::StartNew()
        $lead = Read-Json $f.FullName
        if ($null -eq $lead) { continue }
        $relId = $f.FullName.Substring($LeadsDir.Length + 1).Replace('\','/')
        $swItem.Stop()
        if ($swItem.ElapsedMilliseconds -gt 50) {
            Write-Log "AllLeads item lent" 'INFO' $swItem.ElapsedMilliseconds $f.Name
        }
        $list.Add([ordered]@{
            id       = $relId
            email    = $lead.email
            prenom   = $lead.prenom
            nom      = $lead.nom
            subject  = $lead.subject
            date     = $lead.date
            status   = $lead.status
            products = @($lead.products)
            options  = @($lead.options)
            hasQuote = [bool]$lead.hasQuote
        })
    }
    $swSort = [System.Diagnostics.Stopwatch]::StartNew()
    $result = if ($list.Count -eq 0) { @() } else { @($list | Sort-Object { $_.date } -Descending) }
    $swSort.Stop()
    $swTotal.Stop()
    Write-Log "AllLeads" 'INFO' $swTotal.ElapsedMilliseconds "count=$($list.Count)  sort=$($swSort.ElapsedMilliseconds)ms"
    return $result
}

function Get-LeadDetail([string]$id) {
    $path = Get-LeadPath $id
    $lead = Read-Json $path
    if ($null -eq $lead) { return $null }

    $h = ConvertTo-Hashtable $lead
    $h.id        = $id
    $h.hasQuote  = [bool]$lead.hasQuote
    $h.quoteName = if ($lead.quoteName) { [string]$lead.quoteName } else { '' }
    $h.quoteId   = if ($lead.quoteId)   { [string]$lead.quoteId   } else { '' }
    return $h
}

function Update-Lead([string]$id, $patch) {
    $path = Get-LeadPath $id
    $lead = ConvertTo-Hashtable (Read-Json $path)
    if ($null -eq $lead) { return $null }
    foreach ($p in $patch.PSObject.Properties) { $lead[$p.Name] = $p.Value }
    $lead.updatedAt = (Get-Date).ToString('s')
    Write-Json $path $lead
    return $lead
}
