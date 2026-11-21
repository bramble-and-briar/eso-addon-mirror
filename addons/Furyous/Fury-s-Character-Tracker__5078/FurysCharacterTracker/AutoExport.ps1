# Fury's Character Tracker - Auto Export
# Writes "ESO Characters.csv" to Documents\Elder Scrolls Online by itself, a few seconds after you
# click Export to Excel in game. Nothing to run by hand once it is on.
#
#   Turn On Auto Export.cmd   starts it now and every time you sign in to Windows (no admin needed)
#   Turn Off Auto Export.cmd  stops it and removes it from startup
#
# How it works: the Export button saves a timestamp and reloads the UI, which makes ESO write
# SavedVariables. This watches that file; when it holds a newer timestamp than the last export,
# it runs ExportToExcel.ps1. It checks every few seconds and uses next to no CPU.

param([switch]$On, [switch]$Off, [switch]$Watch)

$dir       = Split-Path -Parent $MyInvocation.MyCommand.Path
$docs      = [Environment]::GetFolderPath('MyDocuments')
$savedVars = Join-Path $docs 'Elder Scrolls Online\live\SavedVariables\FurysCharacterTracker.lua'
$outDir    = Join-Path $docs 'Elder Scrolls Online'
$outFile   = Join-Path $outDir 'ESO Characters.csv'
$stateFile = Join-Path $dir 'AutoExport.state'
$logFile   = Join-Path $dir 'AutoExport.log'
$startup   = Join-Path ([Environment]::GetFolderPath('Startup')) "Fury's Character Tracker Auto Export.vbs"

function Log($text) {
    Add-Content -LiteralPath $logFile -Value ("{0}  {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $text)
}

function Stop-Watchers {
    Get-CimInstance Win32_Process -Filter "Name = 'powershell.exe'" |
        Where-Object { $_.CommandLine -like '*AutoExport.ps1*-Watch*' -and $_.ProcessId -ne $PID } |
        ForEach-Object { Invoke-CimMethod -InputObject $_ -MethodName Terminate | Out-Null }
}

if ($On) {
    # A tiny .vbs in the Startup folder launches the watcher hidden at every Windows sign-in.
    $self = $MyInvocation.MyCommand.Path
    $vbs = "CreateObject(""WScript.Shell"").Run ""powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File """"$self"""" -Watch"", 0, False"
    Set-Content -LiteralPath $startup -Value $vbs -Encoding ASCII
    Stop-Watchers
    Start-Process wscript.exe -ArgumentList "`"$startup`""
    Log 'Auto Export turned on'
    Write-Host 'Auto Export is on. It runs in the background now and every time you sign in to Windows.' -ForegroundColor Green
    Write-Host "Click Export to Excel in game and ESO Characters.csv appears in $outDir a few seconds later."
    exit 0
}

if ($Off) {
    Remove-Item -LiteralPath $startup -ErrorAction SilentlyContinue
    Stop-Watchers
    Log 'Auto Export turned off'
    Write-Host 'Auto Export is off. You can still run ExportToExcel.cmd by hand.' -ForegroundColor Yellow
    exit 0
}

if (-not $Watch) {
    Write-Host 'Use "Turn On Auto Export.cmd" or "Turn Off Auto Export.cmd" in this folder.'
    exit 0
}

# --- Watching -------------------------------------------------------------------------------------

$created = $false
$mutex = New-Object System.Threading.Mutex($false, 'FurysCharacterTrackerAutoExport', [ref]$created)
if (-not $created) { exit 0 }   # already running

Log 'Watching for exports'
$lastWrite = [datetime]::MinValue
while ($true) {
    Start-Sleep -Seconds 3
    try {
        if (-not (Test-Path -LiteralPath $savedVars)) { continue }
        $write = (Get-Item -LiteralPath $savedVars).LastWriteTimeUtc
        if ($write -eq $lastWrite) { continue }
        $lastWrite = $write
        Start-Sleep -Seconds 2   # let ESO finish writing the file

        $m = [regex]::Match([System.IO.File]::ReadAllText($savedVars), '\["exportRequestedAt"\]\s*=\s*(\d+)')
        if (-not $m.Success) { continue }
        $requested = [long]$m.Groups[1].Value
        $done = 0L
        if (Test-Path -LiteralPath $stateFile) { [long]::TryParse((Get-Content -LiteralPath $stateFile -Raw).Trim(), [ref]$done) | Out-Null }
        if ($requested -le $done) { continue }

        # If Excel has the file open it can't be replaced: write a dated copy beside it instead.
        $target = $outFile
        try { [System.IO.File]::Open($outFile, 'OpenOrCreate', 'ReadWrite', 'None').Dispose() }
        catch { $target = Join-Path $outDir ("ESO Characters {0}.csv" -f (Get-Date -Format 'yyyy-MM-dd HHmm')) }

        & (Join-Path $dir 'ExportToExcel.ps1') -SavedVars $savedVars -OutFile $target -NoOpen | Out-Null
        Set-Content -LiteralPath $stateFile -Value $requested
        Log "Exported to $target"
    }
    catch {
        Log ("Error: " + $_.Exception.Message)
    }
}
