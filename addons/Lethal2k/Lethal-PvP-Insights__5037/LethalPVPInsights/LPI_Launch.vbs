' LPI Companion launcher (PowerShell edition) - used by LPI COMPANION.bat when Python 3 isn't installed.
' Starts LPI_Companion.ps1 with no console window (window style 0) and returns right away.
Option Explicit
Dim sh, fso, here, ps, args, i
Set sh = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
here = fso.GetParentFolderName(WScript.ScriptFullName)
ps = sh.ExpandEnvironmentStrings("%SystemRoot%") & "\System32\WindowsPowerShell\v1.0\powershell.exe"
If Not fso.FileExists(ps) Then ps = "powershell.exe"
args = ""
For i = 0 To WScript.Arguments.Count - 1
    args = args & " " & WScript.Arguments(i)
Next
sh.Run """" & ps & """ -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & here & "\LPI_Companion.ps1""" & args, 0, False
