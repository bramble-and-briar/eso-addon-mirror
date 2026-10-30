@echo off
setlocal EnableExtensions
title Dungeon Scores Companion Controls
set "DS_DOTNET="
where dotnet >nul 2>nul
if not errorlevel 1 set "DS_DOTNET=dotnet"
if not defined DS_DOTNET if exist "%ProgramFiles%\dotnet\dotnet.exe" set "DS_DOTNET=%ProgramFiles%\dotnet\dotnet.exe"
if not defined DS_DOTNET (
  echo The free .NET 8 runtime is required. Install it, then try again:
  echo https://dotnet.microsoft.com/download/dotnet/8.0/runtime
  pause
  exit /b 1
)
set "DS_INSTALLED_DLL="
for /f "usebackq delims=" %%P in (`""%DS_DOTNET%" "%~dp0DungeonScoresCompanion.dll" --prepare-control"`) do set "DS_INSTALLED_DLL=%%P"
if not defined DS_INSTALLED_DLL (
  echo The companion controls could not be prepared. Check the installation and try again.
  pause
  exit /b 1
)
for %%P in ("%DS_INSTALLED_DLL%") do set "DS_CONFIG=%%~dpPwatcher-config.json"
"%DS_DOTNET%" "%DS_INSTALLED_DLL%" --control --config "%DS_CONFIG%"
set "DS_EXIT=%ERRORLEVEL%"
if not "%DS_EXIT%"=="0" pause
exit /b %DS_EXIT%
