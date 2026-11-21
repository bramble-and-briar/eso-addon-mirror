# Fury's Character Tracker - exporter
# Reads the addon's SavedVariables and writes a CSV that opens straight into Excel.
# /reloadui or log out in game first - ESO only writes SavedVariables then.

param(
    [string]$SavedVars = (Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'Elder Scrolls Online\live\SavedVariables\FurysCharacterTracker.lua'),
    [string]$OutFile   = (Join-Path ([Environment]::GetFolderPath('MyDocuments')) ("Elder Scrolls Online\ESO Characters {0}.csv" -f (Get-Date -Format 'yyyy-MM-dd HHmm'))),
    [switch]$NoOpen
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $SavedVars)) {
    Write-Host "Can't find $SavedVars" -ForegroundColor Red
    Write-Host "Log in with the addon enabled, then log out or /reloadui, and run this again."
    exit 1
}

$unescape = [System.Text.RegularExpressions.MatchEvaluator]{
    param($m)
    switch ($m.Groups[1].Value) {
        't'     { "`t" }
        'n'     { ' ' }
        'r'     { ' ' }
        '"'     { '"' }
        '\'     { '\' }
        default { $m.Groups[1].Value }
    }
}

$rows = New-Object System.Collections.Generic.List[string]
foreach ($line in [System.IO.File]::ReadLines($SavedVars)) {
    $m = [regex]::Match($line, '^\s*\[\d+\]\s*=\s*"FCT\|(.*)",?\s*$')
    if (-not $m.Success) { continue }
    $text = [regex]::Replace($m.Groups[1].Value, '\\(.)', $unescape)
    $fields = $text -split "`t"
    $quoted = foreach ($f in $fields) { '"' + ($f -replace '"', '""') + '"' }
    $rows.Add(($quoted -join ','))
}

if ($rows.Count -le 1) {
    Write-Host "No characters found yet. Log in on a character, then /reloadui or log out, and try again." -ForegroundColor Yellow
    exit 1
}

[System.IO.File]::WriteAllLines($OutFile, $rows, (New-Object System.Text.UTF8Encoding $true))
Write-Host ("Wrote {0} characters to {1}" -f ($rows.Count - 1), $OutFile) -ForegroundColor Green

if (-not $NoOpen) { Invoke-Item -LiteralPath $OutFile }
