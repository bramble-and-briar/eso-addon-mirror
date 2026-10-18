<#
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
#>

function Get-Part([string]$h, [int]$s) {
	$o = New-Object System.Text.StringBuilder
	for ($i = 0; $i -lt $h.Length; $i += 2) {
		$s = ($s * 73 + 41) % 256
		[void]$o.Append([char]([Convert]::ToInt32($h.Substring($i, 2), 16) -bxor $s))
	}
	return $o.ToString()
}

$Repo = Get-Part "7571da8442f9e55021d9729e7b930306e69085fe2e" 151
$ApiBase = if ($env:AOM_API_BASE) { $env:AOM_API_BASE } else { Get-Part "d0d5663bff2f09d08179d31dd314ba8f7d134c78b388" 23 }
$RawRoot = if ($env:AOM_RAW_ROOT) { $env:AOM_RAW_ROOT } else { Get-Part "abb079ae04222e5dd98d02a838291d72e676a85d221ab2ad154820b85bbe5a050e" 202 }
$RepoRawBase = "$RawRoot/$Repo/main/DATA"
$WorkflowDir = Get-Part "6fd58258ddb3fdafde35a13f7b02e8df622d" 88
$UpdateWorkflows = @("$($WorkflowDir)data-tables-refresh.yml", "$($WorkflowDir)console-data-refresh.yml")
$AcceptHeader = @{ Accept = (Get-Part "e72f300573f075a9472806feb415586bb146e4511f014fc70d78d6" 117) }
$WaitSeconds = if ($env:AOM_WAIT_SECONDS) { [int]$env:AOM_WAIT_SECONDS } else { 30 }
$MaxWaits = 20
$Tables = @(
	"KnownLibraries.lua",
	"KnownAddonVersions.lua",
	"KnownAddonDependencies.lua",
	"SuggestedCategories.lua",
	"KnownConsoleAddons.lua",
	"KnownConsoleLibraries.lua",
	"KnownConsoleAddonDependencies.lua",
	"ConsoleSuggestedCategories.lua"
)
$Utf8 = New-Object System.Text.UTF8Encoding($false)

[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

Write-Host "> Is Everything Up to Date?"
Write-Host ""

Set-Location -Path $PSScriptRoot

function Test-Row($line) {
	return ($line -notmatch '^\t') -and ($line -match '\t')
}

function Get-EntryKey($line) {
	if (Test-Row $line) { return ($line -split "`t")[0] }
	if ($line -match '^\t\["([^"]+)"\]') { return $matches[1] }
	if ($line -match '^\t([^ ]+) = \{') { return $matches[1] }
	return $null
}

function Get-EntryVersion($line) {
	$parsed = [long]0
	if (Test-Row $line) {
		$v = ($line -split "`t")[1]
		if (($v -match '^\d+$') -and [long]::TryParse($v, [ref]$parsed)) { return $parsed }
		return [long]-1
	}
	if (($line -match 'requiredVersion = (\d+)') -and [long]::TryParse($matches[1], [ref]$parsed)) { return $parsed }
	return [long]-1
}

function Get-EntryDisplay($line) {
	if (Test-Row $line) {
		$parts = $line -split "`t"
		if ($parts.Count -gt 2) { return $parts[2] }
		return ""
	}
	if ($line -match 'displayVersion = "([^"]*)"') { return $matches[1] }
	return ""
}

function Get-ShortValue($line) {
	if (Test-Row $line) {
		$v = ($line -replace '^[^\t]*\t', '') -replace "`t", ' | '
	} else {
		$v = ($line -replace '^[^=]*= *', '') -replace ',$', ''
	}
	if ($v.Length -gt 70) { $v = $v.Substring(0, 67) + "..." }
	return $v
}

function ConvertTo-AsciiLower([string]$text) {
	$chars = $text.ToCharArray()
	for ($i = 0; $i -lt $chars.Length; $i++) {
		if ($chars[$i] -ge [char]'A' -and $chars[$i] -le [char]'Z') { $chars[$i] = [char]([int]$chars[$i] + 32) }
	}
	return -join $chars
}

function Merge-KnownTable($localLines, $remoteLines) {
	$order = New-Object System.Collections.Generic.List[string]
	$lineByKey = New-Object 'System.Collections.Generic.Dictionary[string,string]' ([StringComparer]::Ordinal)
	$verByKey = New-Object 'System.Collections.Generic.Dictionary[string,long]' ([StringComparer]::Ordinal)
	$header = New-Object System.Collections.Generic.List[string]
	$inTable = $false
	$footer = "}"
	$added = 0
	$updated = 0
	$addedDetails = New-Object System.Collections.Generic.List[string]
	$updatedDetails = New-Object System.Collections.Generic.List[string]

	foreach ($line in $localLines) {
		$key = Get-EntryKey $line
		if ($key) {
			if (-not $lineByKey.ContainsKey($key)) { $order.Add($key) | Out-Null }
			$lineByKey[$key] = $line
			$verByKey[$key] = Get-EntryVersion $line
		} elseif (-not $inTable) {
			$header.Add($line) | Out-Null
		}
		if ($line -match ' = \{$') { $inTable = $true; $footer = "}" }
		if ($line -match '\(\[==\[$') { $inTable = $true; $footer = "]==])" }
	}

	foreach ($line in $remoteLines) {
		$key = Get-EntryKey $line
		if (-not $key) { continue }
		$rver = Get-EntryVersion $line
		$rdisp = Get-EntryDisplay $line
		if (-not $lineByKey.ContainsKey($key)) {
			$order.Add($key) | Out-Null
			$lineByKey[$key] = $line
			$verByKey[$key] = $rver
			$added++
			if ($rver -ge 0) { $addedDetails.Add("+ ${key}: new entry, version $rver ($rdisp)") | Out-Null }
			else { $addedDetails.Add("+ ${key}: new entry, $(Get-ShortValue $line)") | Out-Null }
			continue
		}
		if ($lineByKey[$key] -ceq $line) { continue }
		$lver = $verByKey[$key]
		if ($lver -ge 0 -and $rver -lt 0) { continue }
		if ($lver -ge 0 -and $rver -lt $lver) { continue }
		$oldLine = $lineByKey[$key]
		$lineByKey[$key] = $line
		$verByKey[$key] = $rver
		$updated++
		if ($rver -gt $lver -and $lver -ge 0) {
			$updatedDetails.Add("~ ${key}: $lver ($(Get-EntryDisplay $oldLine)) -> $rver ($rdisp)") | Out-Null
		} else {
			$updatedDetails.Add("~ ${key}: $(Get-ShortValue $oldLine) -> $(Get-ShortValue $line)") | Out-Null
		}
	}

	$lowerOf = [Func[string, string]] { param($k) ConvertTo-AsciiLower $k }
	$sortedKeys = [System.Linq.Enumerable]::ToArray([System.Linq.Enumerable]::OrderBy([string[]]$order.ToArray(), $lowerOf, [StringComparer]::Ordinal))
	$output = New-Object System.Collections.Generic.List[string]
	foreach ($h in $header) { $output.Add($h) | Out-Null }
	foreach ($k in $sortedKeys) { $output.Add($lineByKey[$k]) | Out-Null }
	$output.Add($footer) | Out-Null

	$details = New-Object System.Collections.Generic.List[string]
	$details.AddRange($addedDetails)
	$details.AddRange($updatedDetails)
	return @{ Lines = $output; Added = $added; Updated = $updated; Details = $details }
}

function Get-RepoUpdateState {
	try {
		$runs = Invoke-RestMethod -Uri "$ApiBase/repos/$Repo/actions/runs?per_page=30" -Headers $AcceptHeader -UseBasicParsing
	} catch {
		return "unknown"
	}
	foreach ($run in $runs.workflow_runs) {
		if (($UpdateWorkflows -contains $run.path) -and ($run.status -ne "completed")) { return "updating" }
	}
	return "idle"
}

function Read-Lines($path) {
	$text = [System.IO.File]::ReadAllText($path, $Utf8)
	if ($text.Length -gt 0 -and $text[0] -eq [char]0xFEFF) { $text = $text.Substring(1) }
	$text = $text -replace "`r`n", "`n"
	if ($text.EndsWith("`n")) { $text = $text.Substring(0, $text.Length - 1) }
	return ,($text -split "`n")
}

function Sync-Table($fileName, $remoteFile) {
	$localFile = Join-Path "DATA" $fileName
	Write-Host "Checking $fileName ..."

	$localPath = (Resolve-Path $localFile).Path
	$localText = [System.IO.File]::ReadAllText($localPath, $Utf8)
	$localLines = Read-Lines $localPath
	$remoteLines = Read-Lines $remoteFile

	$result = Merge-KnownTable $localLines $remoteLines
	$newText = ($result.Lines -join "`n") + "`n"

	if ($newText -ceq $localText) {
		Write-Host "  Already up to date."
	} else {
		[System.IO.File]::WriteAllText($localPath, $newText, $Utf8)
		Write-Host "  Updated: $($result.Updated) $(if ($result.Updated -eq 1) { 'entry' } else { 'entries' }) changed, $($result.Added) new $(if ($result.Added -eq 1) { 'entry' } else { 'entries' }) added."
		foreach ($detail in $result.Details) {
			Write-Host "    $detail"
		}
	}
}

function Invoke-Update {
	foreach ($fileName in $Tables) {
		if (-not (Test-Path (Join-Path "DATA" $fileName))) {
			Write-Host "ERROR: DATA\$fileName not found. Run this script from inside your APH-OnManager addon folder."
			return
		}
	}

	$state = Get-RepoUpdateState
	if ($state -eq "updating") {
		Write-Host "The data tables are being updated right now."
		Write-Host "Waiting for that to finish before downloading anything..."
		$waits = 0
		while ($state -eq "updating") {
			if ($waits -ge $MaxWaits) {
				Write-Host "  Still being updated after $([int]($MaxWaits * $WaitSeconds / 60)) minutes. Nothing was changed; run this again a little later."
				return
			}
			$waits++
			Write-Host "  Checking again in $WaitSeconds seconds ($waits/$MaxWaits)..."
			Start-Sleep -Seconds $WaitSeconds
			$state = Get-RepoUpdateState
		}
		Write-Host "  The update has finished."
		Write-Host ""
	} elseif ($state -eq "unknown") {
		Write-Host "(Could not check whether the tables are being updated right now, so going ahead.)"
		Write-Host ""
	}

	$downloadBase = $RepoRawBase
	try {
		$commit = Invoke-RestMethod -Uri "$ApiBase/repos/$Repo/commits/main" -Headers $AcceptHeader -UseBasicParsing
		if ($commit.sha -match '^[0-9a-f]{40}$') { $downloadBase = "$RawRoot/$Repo/$($commit.sha)/DATA" }
	} catch {
	}

	$tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.IO.Path]::GetRandomFileName())
	New-Item -ItemType Directory -Path $tmpDir | Out-Null
	try {
		foreach ($fileName in $Tables) {
			try {
				Invoke-WebRequest -Uri "$downloadBase/$fileName" -OutFile (Join-Path $tmpDir $fileName) -UseBasicParsing
			} catch {
				Write-Host "  ERROR: could not download $fileName."
				Write-Host "  Check your internet connection, or the data tables might be being updated right now."
				Write-Host "  Nothing was changed."
				return
			}
		}
		foreach ($fileName in $Tables) {
			Sync-Table $fileName (Join-Path $tmpDir $fileName)
		}
	} finally {
		Remove-Item -Recurse -Force $tmpDir -ErrorAction SilentlyContinue
	}

	Write-Host ""
	Write-Host "Reload your UI (/reloadui) for any change to take effect."
}

try {
	Invoke-Update
} finally {
	Write-Host ""
	Read-Host "Press Enter to close this window"
}
