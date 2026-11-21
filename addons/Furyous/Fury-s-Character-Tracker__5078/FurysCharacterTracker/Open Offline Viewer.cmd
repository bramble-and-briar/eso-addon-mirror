@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0OfflineViewer.ps1" %*
if errorlevel 1 pause
