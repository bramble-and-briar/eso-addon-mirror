@echo off
setlocal enabledelayedexpansion

echo ========================================
echo Complete TamrielTradeCentre Ukrainian Setup
echo ========================================
echo.

:: Get the script's directory and navigate to TamrielTradeCentre
set "SCRIPT_DIR=%~dp0"
cd /d "%SCRIPT_DIR%"
cd ..\..\..\TamrielTradeCentre

:: Check if TamrielTradeCentre exists
if not exist "." (
    echo ERROR: TamrielTradeCentre addon not found.
    echo Please make sure TamrielTradeCentre is installed in the same AddOns directory as DovahMova.
    pause
    exit /b 1
)

:: Get absolute paths for display
for %%i in (.) do set "TTC_PATH=%%~fi"
cd /d "%SCRIPT_DIR%"
cd ..\..\..
for %%i in (.) do set "DOVAHMOVA_PATH=%%~fi\DovahMova"

echo Detected paths:
echo TamrielTradeCentre: %TTC_PATH%
echo DovahMova: %DOVAHMOVA_PATH%
echo.

echo Paths verified successfully!
echo.

:: Navigate back to TamrielTradeCentre for operations
cd /d "%TTC_PATH%"

:: Create backup directory
set "BACKUP_DIR=backup_%date:~-4,4%%date:~-10,2%%date:~-7,2%_%time:~0,2%%time:~3,2%%time:~6,2%"
set "BACKUP_DIR=%BACKUP_DIR: =0%"
echo Creating backup at: %BACKUP_DIR%
mkdir "%BACKUP_DIR%"

:: Backup original files
echo Creating backups...
if exist "TamrielTradeCentre.lua" (
    copy "TamrielTradeCentre.lua" "%BACKUP_DIR%\TamrielTradeCentre.lua.backup" >nul
    echo ✓ TamrielTradeCentre.lua backed up
)
if exist "TamrielTradeCentreInit.lua" (
    copy "TamrielTradeCentreInit.lua" "%BACKUP_DIR%\TamrielTradeCentreInit.lua.backup" >nul
    echo ✓ TamrielTradeCentreInit.lua backed up
)
if exist "TamrielTradeCentre.txt" (
    copy "TamrielTradeCentre.txt" "%BACKUP_DIR%\TamrielTradeCentre.txt.backup" >nul
    echo ✓ TamrielTradeCentre.txt backed up
)
echo Backup completed.
echo.

:: Step 1: Create Ukrainian language file
echo Step 1: Creating Ukrainian language file...
if not exist "lang" mkdir "lang"
if exist "%DOVAHMOVA_PATH%\integration\TamrielTradeCentreUA\ttc_lang_ua.lua" (
    copy "%DOVAHMOVA_PATH%\integration\TamrielTradeCentreUA\ttc_lang_ua.lua" "lang\ua.lua" >nul
    echo ✓ Ukrainian language file created: lang\ua.lua
) else (
    echo ✗ ERROR: ttc_lang_ua.lua not found in DovahMova
)
echo.

:: Step 2: Create Ukrainian ItemLookUpTable
echo Step 2: Creating Ukrainian ItemLookUpTable...
if exist "ItemLookUpTable_EN.lua" (
    copy "ItemLookUpTable_EN.lua" "ItemLookUpTable_UA.lua" >nul
    echo ✓ Ukrainian ItemLookUpTable created from English version
) else (
    echo ✗ ERROR: English ItemLookUpTable not found
    echo Cannot create Ukrainian version without English base file.
)
echo.

:: Step 3: Remove the generator installed by older DovahMova versions
:: (since DovahMova 1.5.0 the price table is built by DovahMova itself)
echo Step 3: Removing old DovahMova generator from TamrielTradeCentre...
if exist "generate_ua_itemlookup.lua" (
    del "generate_ua_itemlookup.lua"
    echo ✓ generate_ua_itemlookup.lua removed
)
if exist "TamrielTradeCentre.txt" (
    findstr /C:"generate_ua_itemlookup.lua" "TamrielTradeCentre.txt" >nul
    if not errorlevel 1 (
        powershell -Command "(Get-Content 'TamrielTradeCentre.txt') | Where-Object { $_ -ne 'generate_ua_itemlookup.lua' } | Set-Content 'TamrielTradeCentre.txt'"
        echo ✓ TamrielTradeCentre.txt cleaned
    )
)
echo.

:: Step 6: Patch TamrielTradeCentre.lua for Ukrainian language support
echo Step 6: Patching TamrielTradeCentre.lua for Ukrainian support...
if exist "TamrielTradeCentre.lua" (
    echo Checking current language check line...
    findstr /C:"clientCulture" "TamrielTradeCentre.lua"
    echo.
    echo Attempting to patch language support...
    
    :: Try multiple patterns to handle different versions
    powershell -Command "$content = Get-Content 'TamrielTradeCentre.lua' -Raw; $patched = $false; if ($content -match 'if \(clientCulture~= \"en\" and clientCulture ~= \"de\" and clientCulture ~= \"fr\" and clientCulture ~= \"zh\" and clientCulture ~= \"ru\" and clientCulture ~= \"es\" and clientCulture ~= \"jp\"\) then') { $content = $content -replace 'if \(clientCulture~= \"en\" and clientCulture ~= \"de\" and clientCulture ~= \"fr\" and clientCulture ~= \"zh\" and clientCulture ~= \"ru\" and clientCulture ~= \"es\" and clientCulture ~= \"jp\"\) then', 'if (clientCulture~= \"en\" and clientCulture ~= \"de\" and clientCulture ~= \"fr\" and clientCulture ~= \"zh\" and clientCulture ~= \"ru\" and clientCulture ~= \"es\" and clientCulture ~= \"jp\" and clientCulture ~= \"ua\") then'; $patched = $true; Write-Host 'Pattern 1 applied successfully' } elseif ($content -match 'if \(clientCulture ~= \"en\" and clientCulture ~= \"de\" and clientCulture ~= \"fr\" and clientCulture ~= \"zh\" and clientCulture ~= \"ru\" and clientCulture ~= \"es\" and clientCulture ~= \"jp\"\) then') { $content = $content -replace 'if \(clientCulture ~= \"en\" and clientCulture ~= \"de\" and clientCulture ~= \"fr\" and clientCulture ~= \"zh\" and clientCulture ~= \"ru\" and clientCulture ~= \"es\" and clientCulture ~= \"jp\"\) then', 'if (clientCulture ~= \"en\" and clientCulture ~= \"de\" and clientCulture ~= \"fr\" and clientCulture ~= \"zh\" and clientCulture ~= \"ru\" and clientCulture ~= \"es\" and clientCulture ~= \"jp\" and clientCulture ~= \"ua\") then'; $patched = $true; Write-Host 'Pattern 2 applied successfully' } elseif ($content -match 'if \(clientCulture~= \"en\" and clientCulture ~= \"de\" and clientCulture ~= \"fr\" and clientCulture ~= \"zh\" and clientCulture ~= \"ru\" and clientCulture ~= \"es\" and clientCulture ~= \"jp\" and clientCulture ~= \"ua\"\) then') { Write-Host 'Ukrainian language already supported!' } else { Write-Host 'No matching pattern found - manual patch required' }; if ($patched) { Set-Content 'TamrielTradeCentre.lua' $content }"
    
    echo.
    echo Checking if patch was successful...
    findstr /C:"clientCulture.*ua" "TamrielTradeCentre.lua"
    
    if errorlevel 1 (
        echo.
        echo ✗ WARNING: Automatic patch may have failed
        echo MANUAL PATCH REQUIRED - see instructions below
    ) else (
        echo ✓ TamrielTradeCentre.lua patched successfully
    )
) else (
    echo ✗ ERROR: TamrielTradeCentre.lua not found
)
echo.

:: Step 7: Patch TamrielTradeCentreInit.lua to ensure Ukrainian language enum is properly defined
echo Step 7: Verifying Ukrainian language enum in TamrielTradeCentreInit.lua...
if exist "TamrielTradeCentreInit.lua" (
    findstr /C:"UA = 8" "TamrielTradeCentreInit.lua" >nul
    if errorlevel 1 (
        echo ✗ WARNING: Ukrainian language enum may not be properly defined
        echo This might cause issues with language detection
    ) else (
        echo ✓ Ukrainian language enum found in TamrielTradeCentreInit.lua
    )
) else (
    echo ✗ ERROR: TamrielTradeCentreInit.lua not found
)
echo.

:: Step 8: Final verification
echo Step 8: Final verification...
echo.
echo ========================================
echo Setup Summary
echo ========================================
echo.
echo ✓ Backup created at: %BACKUP_DIR%
echo ✓ Ukrainian language file: lang\ua.lua
echo ✓ Ukrainian ItemLookUpTable: ItemLookUpTable_UA.lua
echo ✓ Old DovahMova generator removed from TamrielTradeCentre
echo ✓ TamrielTradeCentre.lua patched for Ukrainian support
echo.
echo ========================================
echo Next Steps
echo ========================================
echo.
echo 1. If the automatic patch failed, manually edit TamrielTradeCentre.lua:
echo    - Find the line with clientCulture language check
echo    - Add " and clientCulture ~= \"ua\"" before the closing parenthesis
echo.
echo 2. Restart ESO completely
echo 3. Make sure your ESO client is set to Ukrainian language
echo 4. Load into the game
echo 5. Check if TamrielTradeCentre loads without the "unsupported language" error
echo 6. Open DovahMova settings and press "Згенерувати TTC"
echo.
echo ========================================
echo Troubleshooting
echo ========================================
echo.
echo If you still get "unsupported language" error:
echo 1. Check that your ESO client language is set to Ukrainian
echo 2. Verify the language check line in TamrielTradeCentre.lua includes "ua"
echo 3. Make sure lang\ua.lua exists and contains Ukrainian strings
echo 4. Check the backup folder for original files if needed
echo.
echo To restore original files, copy from: %BACKUP_DIR%
echo.

pause
