# ==========================================================================
#  Logger — trace des actions, timing, statut
# ==========================================================================

function Write-Log {
    param(
        [string]$Action,
        [string]$Status = 'INFO',   # OK | KO | INFO
        [int]$Ms = -1,
        [string]$Detail = ''
    )
    $ts     = (Get-Date).ToString('HH:mm:ss.fff')
    $msStr  = if ($Ms -ge 0) { " ${Ms}ms" } else { '' }
    $det    = if ($Detail) { "  $Detail" } else { '' }
    $line   = "[$ts] $($Status.PadRight(4))$msStr  $Action$det"
    $col  = switch ($Status) {
        'OK'   { 'Green' }
        'KO'   { 'Red'   }
        default { 'DarkGray' }
    }
    Write-Host $line -ForegroundColor $col
}
