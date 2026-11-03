' Use wscript.exe so launching PowerShell does not activate Windows Terminal.
Option Explicit
Dim shell, script, video, result, command, status
Set shell = CreateObject("WScript.Shell")
If WScript.Arguments.Count < 3 Or WScript.Arguments.Count > 4 Then WScript.Quit 2
script = WScript.Arguments(0)
video = WScript.Arguments(1)
result = WScript.Arguments(2)
command = "powershell.exe -NoProfile -NonInteractive -File """ & script & """ -VideoPath """ & video & """ -FocusOnly -ResultPath """ & result & """"
If WScript.Arguments.Count = 4 Then command = command & " -RestartVideo"
status = shell.Run(command, 0, True)
WScript.Quit status
