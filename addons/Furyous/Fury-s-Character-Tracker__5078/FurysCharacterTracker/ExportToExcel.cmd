@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0ExportToExcel.ps1" %*
if errorlevel 1 pause
