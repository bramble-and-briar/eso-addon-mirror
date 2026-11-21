@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0AutoExport.ps1" -On
pause
