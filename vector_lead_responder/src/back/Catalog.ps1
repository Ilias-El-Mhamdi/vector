# ==========================================================================
#  Catalogue produits & detection
# ==========================================================================

function Get-Catalog { Read-Json $CatalogPath }

function Get-ProductQuantity([string]$text, $keywords, [string]$style = 'before') {
    $words = @{
        'un'=1;'une'=1;'one'=1;'ein'=1;'eine'=1;
        'deux'=2;'two'=2;'zwei'=2;
        'trois'=3;'three'=3;'drei'=3;
        'quatre'=4;'four'=4;'vier'=4;
        'cinq'=5;'five'=5;'funf'=5;'fünf'=5;
        'six'=6;'sechs'=6;
        'sept'=7;'seven'=7;'sieben'=7;
        'huit'=8;'eight'=8;'acht'=8;
        'neuf'=9;'nine'=9;'neun'=9;
        'dix'=10;'ten'=10;'zehn'=10
    }
    $wordPat = ($words.Keys | ForEach-Object { [regex]::Escape($_) }) -join '|'
    $ic = [System.Text.RegularExpressions.RegexOptions]::IgnoreCase

    foreach ($k in $keywords) {
        $e = [regex]::Escape($k)

        # Patterns avec x : toujours actifs, non ambigus
        foreach ($pat in @("(\d+)[xX]\s{0,2}$e", "$e\s{0,2}[xX](\d+)")) {
            $m = [regex]::Match($text, $pat, $ic)
            if ($m.Success) {
                $v = [int]$m.Groups[1].Value
                if ($v -gt 0 -and $v -le 999) { return $v }
            }
        }

        # Bare number : essaie les deux sens, style comme tiebreaker
        $mBefore = [regex]::Match($text, "(\d+)\s{0,2}$e",  $ic)
        $mAfter  = [regex]::Match($text, "$e\s{0,2}(\d+)",  $ic)
        $hasBefore = $mBefore.Success -and [int]$mBefore.Groups[1].Value -gt 0 -and [int]$mBefore.Groups[1].Value -le 999
        $hasAfter  = $mAfter.Success  -and [int]$mAfter.Groups[1].Value  -gt 0 -and [int]$mAfter.Groups[1].Value  -le 999
        if ($hasBefore -and $hasAfter) {
            if ($style -eq 'after') { return [int]$mAfter.Groups[1].Value } else { return [int]$mBefore.Groups[1].Value }
        } elseif ($hasBefore) { return [int]$mBefore.Groups[1].Value }
        elseif  ($hasAfter)  { return [int]$mAfter.Groups[1].Value  }

        # Mots ecrits : meme logique
        $wBefore = [regex]::Match($text, "($wordPat)\s{0,2}$e", $ic)
        $wAfter  = [regex]::Match($text, "$e\s{0,2}($wordPat)", $ic)
        $hwBefore = $wBefore.Success -and $words.ContainsKey($wBefore.Groups[1].Value.ToLower().Replace('ü','u'))
        $hwAfter  = $wAfter.Success  -and $words.ContainsKey($wAfter.Groups[1].Value.ToLower().Replace('ü','u'))
        if ($hwBefore -and $hwAfter) {
            $w = if ($style -eq 'after') { $wAfter.Groups[1].Value } else { $wBefore.Groups[1].Value }
            return $words[$w.ToLower().Replace('ü','u')]
        } elseif ($hwBefore) { return $words[$wBefore.Groups[1].Value.ToLower().Replace('ü','u')] }
        elseif  ($hwAfter)  { return $words[$wAfter.Groups[1].Value.ToLower().Replace('ü','u')]  }
    }
    return 1
}

# Detecte le style dominant : chiffre avant ou apres le produit
function Get-QuantityStyle([string]$text, $matchedList) {
    $before = 0; $after = 0
    $ic = [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
    foreach ($m in $matchedList) {
        foreach ($k in $m.hitKeys) {
            $e = [regex]::Escape($k)
            if ([regex]::IsMatch($text, "\d+\s{0,2}$e",  $ic)) { $before++ }
            if ([regex]::IsMatch($text, "$e\s{0,2}\d+",  $ic)) { $after++  }
        }
    }
    if ($after -gt $before) { return 'after' } else { return 'before' }
}

# Detecte produits + options dans un texte selon le catalogue
function Find-Matches([string]$text, $catalog) {
    $t = $text.ToLower()
    $options = New-Object System.Collections.Generic.List[string]

    # 1er passage : collecter les produits matchés avec leurs keywords
    $matched = @()
    foreach ($p in $catalog.products) {
        $hitKeys = [System.Collections.Generic.List[string]]::new()
        foreach ($k in $p.keywords) {
            if ($k -and $t.Contains($k.ToLower())) { $hitKeys.Add([string]$k) }
        }
        if ($hitKeys.Count -gt 0 -and -not ($matched | Where-Object { $_.name -eq $p.name })) {
            $matched += @{ name = [string]$p.name; hitKeys = $hitKeys.ToArray(); catalogEntry = $p }
        }
    }

    # Detecte le style de l'auteur (chiffre avant ou apres)
    $style = Get-QuantityStyle $text $matched

    # 2eme passage : quantites + options
    $products = New-Object System.Collections.Generic.List[object]
    foreach ($m in $matched) {
        $qty = Get-ProductQuantity $text $m.hitKeys $style
        $products.Add(@{ name = $m.name; quantity = $qty })

        foreach ($o in $m.catalogEntry.options) {
            foreach ($k in $o.keywords) {
                if ($k -and $t.Contains($k.ToLower())) {
                    if (-not $options.Contains([string]$o.name)) { $options.Add([string]$o.name) }
                    break
                }
            }
        }
    }

    if ($catalog.options_globales) {
        foreach ($o in $catalog.options_globales) {
            foreach ($k in $o.keywords) {
                if ($k -and $t.Contains($k.ToLower())) {
                    if (-not $options.Contains([string]$o.name)) { $options.Add([string]$o.name) }
                    break
                }
            }
        }
    }

    # .ToArray() convertit List[object]/List[string] en tableaux PS natifs (object[]/string[])
    # Necessaire : @(Generic.List[object]) leve ArgumentException en PowerShell 5.1
    return @{ products = $products.ToArray(); options = $options.ToArray() }
}
