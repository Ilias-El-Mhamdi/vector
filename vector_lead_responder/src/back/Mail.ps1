# ==========================================================================
#  Actions metier Outlook (scan / devis / envoi)
# ==========================================================================

# ---- Genere un mail de demande de devis interne ----------------------------
function Invoke-GenerateQuote([string]$id, [bool]$preview = $false, [string]$quoteDraft = '') {
    $path = Get-LeadPath $id
    $lead = ConvertTo-Hashtable (Read-Json $path)
    if ($null -eq $lead) { throw "Lead introuvable" }

    $prenom  = [string]$lead.prenom
    $nom     = [string]$lead.nom
    $email   = [string]$lead.email
    $subject = [string]$lead.subject
    $body    = [string]$lead.body
    $prodLines = (@($lead.products) | Where-Object { $_ } | ForEach-Object {
        $n = if ($_.name) { [string]$_.name } else { [string]$_ }
        $q = if ($_.quantity -and [int]$_.quantity -gt 0) { [int]$_.quantity } else { 1 }
        "- $q $n"
    }) -join "`n"
    $optLines  = (@($lead.options)  | Where-Object { $_ } | ForEach-Object { "- $_" }) -join "`n"

    $ol   = Get-Outlook
    $mail = $null
    try { $mail = $ol.CreateItem(0) } catch {
        $script:Outlook = $null; $ol = Get-Outlook
        try { $mail = $ol.CreateItem(0) } catch {
            throw "Un brouillon Outlook est déjà ouvert. Fermez-le puis réessayez."
        }
    }

    $nom_complet = "$prenom $nom".Trim()
    if ([string]::IsNullOrWhiteSpace($nom_complet)) { $nom_complet = $email }

    $catalog  = Get-Catalog
    $recipient = $env:DEVIS_CREATEUR_MAIL
    if ([string]::IsNullOrWhiteSpace($recipient)) { throw "DEVIS_CREATEUR_MAIL non defini dans env.txt" }
    $mail.To      = $recipient
    $mail.Subject = "Demande de devis - $nom_complet"

    if (-not [string]::IsNullOrWhiteSpace($quoteDraft)) {
        $mail.Body = $quoteDraft + "`n`n--- Message original du client ---`nObjet : $subject`n`n$body"
    } else {
        $mail.Body = @"
Bonjour,

Merci de bien vouloir établir un devis pour le client suivant :

Client  : $nom_complet
E-mail  : $email

Produits :
$prodLines

Options :
$optLines

--- Message original du client ---
Objet : $subject

$body
"@
    }

    if ($preview) {
        $mail.Display($false)
        return @{ ok = $true; status = [string]$lead.status }
    }

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $mail.Send()
    $sw.Stop()

    $lead.status    = 'devis demande'
    $lead.updatedAt = (Get-Date).ToString('s')
    Write-Json $path $lead

    Write-Log "GenerateQuote" 'OK' $sw.ElapsedMilliseconds $id
    return @{ ok = $true; status = 'devis demande' }
}

# ---- Refresh : re-lit subject/body depuis Outlook via entryId --------------
function Invoke-LeadRefresh([string]$id) {
    $path = Get-LeadPath $id
    $lead = ConvertTo-Hashtable (Read-Json $path)
    if ($null -eq $lead) { throw "Lead introuvable" }
    $entryId = [string]$lead.entryId
    if ([string]::IsNullOrWhiteSpace($entryId)) { throw "Pas d'entryId dans ce lead" }

    $ol   = Get-Outlook
    $ns   = $ol.GetNamespace('MAPI')
    $item = $null
    try { $item = $ns.GetItemFromID($entryId) } catch { throw "Mail introuvable dans Outlook (entryId invalide ou boite incorrecte)" }

    $subject = ''; try { $subject = [string]$item.Subject } catch {}
    $body    = ''; try { $body    = [string]$item.Body    } catch {}
    if ([string]::IsNullOrWhiteSpace($body)) {
        try { $html = [string]$item.HTMLBody; if ($html) { $body = ($html -replace '<[^>]+>','' -replace '&nbsp;',' ' -replace '&amp;','&' -replace '&lt;','<' -replace '&gt;','>').Trim() } } catch {}
    }

    $lead.subject    = $subject
    $lead.body       = $body
    $lead.updatedAt  = (Get-Date).ToString('s')
    Write-Json $path $lead

    # Retourne le lead mis a jour avec infos de devis
    $leadDir = Split-Path $path -Parent
    $quote   = Get-QuoteFile $leadDir
    $lead.hasQuote  = [bool]$quote
    $lead.quoteName = if ($quote) { Split-Path $quote -Leaf } else { '' }
    return $lead
}

# ---- Scan de la boite de reception ----------------------------------------
function Invoke-Scan([int]$count) {
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    if ($count -le 0) { $count = 50 }
    $catalog = Get-Catalog
    $ignore = [System.Collections.Generic.List[string]]::new()
    if ($catalog._ignoreSenders) { foreach ($s in $catalog._ignoreSenders) { $ignore.Add($s) } }
    if (-not [string]::IsNullOrWhiteSpace($env:DEVIS_CREATEUR_MAIL)) { $ignore.Add($env:DEVIS_CREATEUR_MAIL) }
    if (-not [string]::IsNullOrWhiteSpace($env:IGNORE_DOMAINS)) {
        foreach ($d in ($env:IGNORE_DOMAINS -split ',')) {
            $d = $d.Trim(); if ($d) { $ignore.Add($d) }
        }
    }

    $ol = Get-Outlook
    $ns = $ol.GetNamespace('MAPI')
    $inbox = $ns.GetDefaultFolder(6)   # olFolderInbox
    $items = $inbox.Items
    $items.Sort('[ReceivedTime]', $true)   # plus recent en premier

    # Pre-charge tous les entryIds connus pour eviter de lire les JSON dans la boucle
    $knownIds = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($f in (Get-ChildItem -Path $LeadsDir -Filter '*.json' -Recurse -File -ErrorAction SilentlyContinue)) {
        $j = Read-Json $f.FullName
        if ($j -and $j.entryId) { $knownIds.Add([string]$j.entryId) | Out-Null }
    }

    $scanned = 0
    $leadsCreated = 0
    $leadsUpdated = 0
    $total = $items.Count

    # On itere par index (plus fiable que foreach sur les collections COM Outlook)
    for ($idx = 1; $idx -le $total -and $scanned -lt $count; $idx++) {
        $item = $null
        try { $item = $items.Item($idx) } catch { continue }
        if ($null -eq $item) { continue }
        try {
            if ($item.Class -ne 43) { continue }   # 43 = olMail
        } catch { continue }

        # Dedup rapide : 1 seul appel COM avant toute lecture couteuse
        $entryId = ''; try { $entryId = [string]$item.EntryID } catch {}
        if ($entryId -and $knownIds.Contains($entryId)) { continue }

        $scanned++

        $subject = ''; try { $subject = [string]$item.Subject } catch {}
        $body    = ''; try { $body    = [string]$item.Body    } catch {}
        # Fallback HTML -> texte brut si Body est vide
        if ([string]::IsNullOrWhiteSpace($body)) {
            try {
                $html = [string]$item.HTMLBody
                if ($html) { $body = ($html -replace '<[^>]+>','' -replace '&nbsp;',' ' -replace '&amp;','&' -replace '&lt;','<' -replace '&gt;','>').Trim() }
            } catch {}
        }

        # Extraction email avec fallback Exchange
        $email = ''; try { $email = Get-SmtpAddress $item } catch {}
        if ([string]::IsNullOrWhiteSpace($email)) {
            try { $email = [string]$item.SenderEmailAddress } catch {}
        }
        if ([string]::IsNullOrWhiteSpace($email)) { continue }

        # --- Devis entrant : expedie par DEVIS_CREATEUR_MAIL, PJ au format QUOTE_*.pdf
        if (-not [string]::IsNullOrWhiteSpace($env:DEVIS_CREATEUR_MAIL) -and
            $email.ToLower() -eq $env:DEVIS_CREATEUR_MAIL.ToLower()) {
            try {
                $attachments = $item.Attachments
                for ($ai = 1; $ai -le $attachments.Count; $ai++) {
                    $att = $attachments.Item($ai)
                    $attName = [string]$att.FileName
                    if ($attName -match '^QUOTE_.+\.pdf$') {
                        $dest = Join-Path $QuotesDir $attName
                        if (-not (Test-Path $dest)) {
                            $att.SaveAsFile($dest)
                            $leadsUpdated++
                        }
                    }
                }
            } catch {}
            continue   # pas de lead pour ce mail
        }

        $haystack = "$subject `n $body"

        try {
            $matchResult = Find-Matches $haystack $catalog
            $isLead = ($matchResult.products.Count -gt 0)

            $skip = $false
            foreach ($ig in $ignore) { if ($email.ToLower().Contains($ig.ToLower())) { $skip = $true; break } }
            if ($skip) { continue }

            $names    = Split-Name ([string]$item.SenderName)
            $received = ''; try { $received = $item.ReceivedTime.ToString('s') } catch {}
            $leadDir  = Get-LeadDir $email
            if (-not (Test-Path $leadDir)) { New-Item -ItemType Directory -Path $leadDir | Out-Null }

            # Structure : bdd/leads/<safeemail>/<leadname>/<leadname>.json
            $datePart   = if ($received) { $received.Replace(':','').Replace('-','').Substring(0,15) } else { (Get-Date).ToString('yyyyMMddTHHmmss') }
            $safeMail   = ConvertTo-SafeName $email
            $leadName   = "$datePart`_$safeMail"
            $leadSubDir = Join-Path $leadDir $leadName
            if (-not (Test-Path $leadSubDir)) { New-Item -ItemType Directory -Path $leadSubDir | Out-Null }
            $leadPath   = Join-Path $leadSubDir "$leadName.json"

            # Auto-status si PDF present dans le sous-dossier du lead
            $autoStatus = if ($isLead) { 'devis non demande' } else { 'ignore' }
            $quote = Get-QuoteFile $leadSubDir
            if ($quote -and $isLead) { $autoStatus = 'devis recu' }

            $lead = [ordered]@{
                id         = "$safeMail/$leadName/$leadName.json"
                entryId    = $entryId
                email      = $email
                prenom     = $names.prenom
                nom        = $names.nom
                subject    = $subject
                date       = $received
                body       = $body
                status     = $autoStatus
                products   = $matchResult.products
                options    = $matchResult.options
                replyDraft = ''
                createdAt  = (Get-Date).ToString('s')
                updatedAt  = (Get-Date).ToString('s')
            }

            Write-Json $leadPath $lead
            $leadsCreated++
        } catch { throw }
    }

    $sw.Stop()
    Write-Log "Scan($count)" 'OK' $sw.ElapsedMilliseconds "lus=$scanned  crees=$leadsCreated  devis=$leadsUpdated"
    return @{ scanned = $scanned; created = $leadsCreated; quotesSaved = $leadsUpdated }
}

# ---- Envoi : cree le mail Outlook avec PJ ----------------------------------
function Invoke-Send([string]$id, [bool]$direct = $false, [string]$replyText = '') {
    $path    = Get-LeadPath $id
    $lead    = ConvertTo-Hashtable (Read-Json $path)
    if ($null -eq $lead) { throw "Lead introuvable" }
    $catalog = Get-Catalog
    $leadDir = Split-Path $path -Parent

    $ol      = Get-Outlook
    $entryId = [string]$lead.entryId
    $mail    = $null
    $usedReply = $false

    Write-Log "Send" "entryId='$entryId' direct=$direct" 0 $id

    # Tenter une reponse threaded (2 essais : COM peut etre stale/RPC mort)
    if (-not [string]::IsNullOrWhiteSpace($entryId)) {
        for ($attempt = 1; $attempt -le 2 -and $null -eq $mail; $attempt++) {
            try {
                $ns       = $ol.GetNamespace('MAPI')
                $origMail = $ns.GetItemFromID($entryId)
                Write-Log "Send" "GetItemFromID OK class=$([string]$origMail.Class) attempt=$attempt" 0 $id
                $mail      = $origMail.Reply()
                $usedReply = $true
                Write-Log "Send" "Reply() OK To='$([string]$mail.To)'" 0 $id
            } catch {
                Write-Log "Send" "Reply() FAIL attempt=$attempt : $($_.Exception.Message)" 0 $id
                $script:Outlook = $null
                $ol   = Get-Outlook
                $mail = $null
            }
        }
    } else {
        Write-Log "Send" "entryId vide -> CreateItem" 0 $id
    }

    # Fallback : nouveau mail si Reply() impossible
    if ($null -eq $mail) {
        try {
            $mail = $ol.CreateItem(0)
        } catch {
            $msg = $_.Exception.Message
            if ($msg -match 'operation failed|0x80004005|busy') {
                throw "Un brouillon Outlook est déjà ouvert. Fermez-le puis réessayez."
            }
            $script:Outlook = $null
            $ol = Get-Outlook
            try { $mail = $ol.CreateItem(0) } catch {
                throw "Impossible de creer le mail Outlook. Verifiez qu'Outlook est ouvert et aucun brouillon en cours."
            }
        }
        $produits = (@($lead.products) | Where-Object { $_ } | ForEach-Object { if ($_.name) { [string]$_.name } else { [string]$_ } }) -join ', '
        $subj = [string]$catalog.replySubject
        $subj = $subj.Replace('{{produits}}', $produits)
        $mail.To      = [string]$lead.email
        $mail.Subject = $subj
    }

    $replyBody = if (-not [string]::IsNullOrWhiteSpace($replyText)) { $replyText } else { Build-ReplyBody $lead $catalog }
    $mail.Body = $replyBody

    $quote = Get-QuoteFile $leadDir
    if ($quote) { $mail.Attachments.Add($quote) | Out-Null }
    if ($catalog.templateAttachment -and (Test-Path $catalog.templateAttachment)) {
        $mail.Attachments.Add($catalog.templateAttachment) | Out-Null
    }

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    if ($direct) { $mail.Send() } else { $mail.Display($false) }
    $sw.Stop()

    # Mise a jour statut uniquement sur envoi reel (pas preview)
    if ($direct) {
        $lead.status    = 'traite'
        $lead.updatedAt = (Get-Date).ToString('s')
        Write-Json $path $lead
    }

    Write-Log "Send(direct=$direct,reply=$usedReply)" 'OK' $sw.ElapsedMilliseconds $id
    return @{ ok = $true; status = [string]$lead.status }
}

function Build-ReplyBody($lead, $catalog) {
    $tpl = [string]$catalog.replyTemplate
    $prenom = [string]$lead.prenom
    if ([string]::IsNullOrWhiteSpace($prenom)) { $prenom = 'Madame, Monsieur' }
    $produits = (@($lead.products) | Where-Object { $_ } | ForEach-Object { if ($_.name) { [string]$_.name } else { [string]$_ } }) -join ', '
    $optPhrase = ''
    if (@($lead.options).Count -gt 0) {
        $optPhrase = " (options : " + ((@($lead.options)) -join ', ') + ")"
    }
    $tpl = $tpl.Replace('{{prenom}}', $prenom)
    $tpl = $tpl.Replace('{{produits}}', $produits)
    $tpl = $tpl.Replace('{{options_phrase}}', $optPhrase)
    return $tpl
}
