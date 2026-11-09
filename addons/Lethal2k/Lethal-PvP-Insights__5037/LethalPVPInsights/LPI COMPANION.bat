@echo off
rem ============================================================================
rem  LPI COMPANION - Lethal PVP Insights Companion (one launcher for every PC)
rem  Imports gear and skill bars from Encounter.log and answers the in-game
rem  Upload button. Uses Python 3 when it's installed, otherwise the
rem  PowerShell edition that is built into Windows 10/11. Runs without a
rem  console window - only the Companion window appears.
rem  "--background" (used by Start with Windows) starts it minimised.
rem ============================================================================
setlocal
set "HERE=%~dp0"
set "PYARG="
set "PSARG="
if /i "%~1"=="--background" (
    set "PYARG=--background"
    set "PSARG=-Background"
)

where py >nul 2>nul
if errorlevel 1 goto trypython
py -3 -c "import tkinter" >nul 2>nul
if errorlevel 1 goto trypython
start "" pyw -3 "%HERE%LPI_Companion.pyw" %PYARG%
exit /b

:trypython
where pythonw >nul 2>nul
if errorlevel 1 goto powershell
python -c "import sys, tkinter; sys.exit(0 if sys.version_info[0] == 3 else 1)" >nul 2>nul
if errorlevel 1 goto powershell
start "" pythonw "%HERE%LPI_Companion.pyw" %PYARG%
exit /b

:powershell
rem No usable Python 3: the PowerShell edition. LPI_Launch.vbs starts it with no console window at all
rem (Windows Terminal would otherwise show one even with -WindowStyle Hidden). It replaces
rem "conhost --headless", which crashed on some PCs ("Exception Processing Message c0000005").
if not exist "%SystemRoot%\System32\wscript.exe" goto plainps
if not exist "%HERE%LPI_Launch.vbs" goto plainps
start "" "%SystemRoot%\System32\wscript.exe" //B //Nologo "%HERE%LPI_Launch.vbs" %PSARG%
exit /b

:plainps
start "" powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%HERE%LPI_Companion.ps1" %PSARG%
exit /b
