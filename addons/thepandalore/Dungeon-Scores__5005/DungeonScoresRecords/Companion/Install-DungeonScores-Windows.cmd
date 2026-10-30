@echo off
setlocal EnableExtensions EnableDelayedExpansion
title Install Dungeon Scores Companion
echo Dungeon Scores Companion - one-time installation
echo.
set "DS_DOTNET="
set "DS_RUNTIME_OK="
where dotnet >nul 2>nul
if not errorlevel 1 set "DS_DOTNET=dotnet"
if not defined DS_DOTNET if exist "%ProgramFiles%\dotnet\dotnet.exe" set "DS_DOTNET=%ProgramFiles%\dotnet\dotnet.exe"
if defined DS_DOTNET (
  "!DS_DOTNET!" --list-runtimes 2>nul | findstr /B /C:"Microsoft.NETCore.App 8." >nul
  if not errorlevel 1 set "DS_RUNTIME_OK=1"
)
if not defined DS_RUNTIME_OK (
  echo The free .NET 8 runtime must be installed first.
  echo The official Microsoft download page will open now.
  start "" "https://dotnet.microsoft.com/download/dotnet/8.0/runtime"
  echo.
  echo Install the .NET 8 runtime, then return here and press any key.
  pause >nul
  set "DS_DOTNET="
  set "DS_RUNTIME_OK="
  where dotnet >nul 2>nul
  if not errorlevel 1 set "DS_DOTNET=dotnet"
  if not defined DS_DOTNET if exist "%ProgramFiles%\dotnet\dotnet.exe" set "DS_DOTNET=%ProgramFiles%\dotnet\dotnet.exe"
  if defined DS_DOTNET (
    "!DS_DOTNET!" --list-runtimes 2>nul | findstr /B /C:"Microsoft.NETCore.App 8." >nul
    if not errorlevel 1 set "DS_RUNTIME_OK=1"
  )
  if not defined DS_RUNTIME_OK (
    echo.
    echo .NET 8 is not available yet. Finish installing it, then run this file again.
    pause
    exit /b 1
  )
)
echo Installing and starting automatic Dungeon Scores synchronization...
"!DS_DOTNET!" "%~dp0DungeonScoresCompanion.dll" --install-startup
set "DS_EXIT=!ERRORLEVEL!"
echo.
if not "!DS_EXIT!"=="0" (
  echo Installation did not complete. See the message above.
  pause
  exit /b !DS_EXIT!
)
echo Installation complete. You do not need to run this file again.
echo.
echo From now on, press Send selected score in ESO. That is the normal workflow.
echo The score sends after ESO next saves. Use /reloadui only for an immediate send.
echo.
echo Opening the companion controls in your browser...
call "%~dp0Open-Controls-Windows.cmd"
exit /b !ERRORLEVEL!
