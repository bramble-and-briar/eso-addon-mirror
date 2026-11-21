# Fury's Character Tracker - offline viewer
# Reads the addon's saved data (every account and megaserver that plays on this PC), builds
# "Fury's Character Tracker.html" in Documents\Elder Scrolls Online and opens it in your browser.
# No game needed. ESO writes the saved data when you log out or /reloadui.
# Plain text: open it in Notepad to see what it does. It reads one file, writes one file, and
# never connects to the internet.

param(
    [string]$SavedVars = (Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'Elder Scrolls Online\live\SavedVariables\FurysCharacterTracker.lua'),
    [string]$OutFile   = (Join-Path ([Environment]::GetFolderPath('MyDocuments')) "Elder Scrolls Online\Fury's Character Tracker.html"),
    [switch]$NoOpen
)

$ErrorActionPreference = 'Stop'
$template = Join-Path $PSScriptRoot 'Viewer\viewer.html'

if (-not (Test-Path -LiteralPath $SavedVars)) {
    Write-Host "Can't find $SavedVars" -ForegroundColor Red
    Write-Host "Log in with the addon enabled, then log out or /reloadui, and run this again."
    exit 1
}
if (-not (Test-Path -LiteralPath $template)) {
    Write-Host "Can't find $template - reinstall the addon." -ForegroundColor Red
    exit 1
}

$utf8 = New-Object System.Text.UTF8Encoding($false)
$lua  = [IO.File]::ReadAllText($SavedVars, $utf8)
$json = ConvertTo-Json -InputObject $lua -Compress          # the file as one safe JavaScript string
$time = [DateTimeOffset]::new((Get-Item -LiteralPath $SavedVars).LastWriteTimeUtc).ToUnixTimeSeconds()

$version = ''
$manifest = Join-Path $PSScriptRoot 'FurysCharacterTracker.txt'
if (Test-Path -LiteralPath $manifest) {
    $m = Select-String -LiteralPath $manifest -Pattern '^## Version:\s*(.+)$' | Select-Object -First 1
    if ($m) { $version = $m.Matches[0].Groups[1].Value.Trim() }
}

$html = [IO.File]::ReadAllText($template, $utf8)
$html = $html.Replace('"__FCT_DATA__"', $json).Replace('__FCT_FILETIME__', [string]$time).Replace('__FCT_VERSION__', $version)
[IO.File]::WriteAllText($OutFile, $html, $utf8)

Write-Host "Wrote $OutFile"
if (-not $NoOpen) { Start-Process -FilePath $OutFile }
