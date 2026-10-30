@echo off
set "DS_DOTNET="
where dotnet >nul 2>nul
if not errorlevel 1 set "DS_DOTNET=dotnet"
if not defined DS_DOTNET if exist "%ProgramFiles%\dotnet\dotnet.exe" set "DS_DOTNET=%ProgramFiles%\dotnet\dotnet.exe"
if not defined DS_DOTNET (
  echo Dungeon Scores Companion requires the free .NET 8 runtime.
  echo https://dotnet.microsoft.com/download/dotnet/8.0/runtime
  echo.
  pause
  exit /b 1
)
"%DS_DOTNET%" "%~dp0..\DungeonScoresCompanion.dll" --sync
set "DS_EXIT=%ERRORLEVEL%"
echo.
pause
exit /b %DS_EXIT%
