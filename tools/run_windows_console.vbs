Option Explicit
Dim shell, command
Set shell = CreateObject("WScript.Shell")
If WScript.Arguments.Count <> 2 Then WScript.Quit 2
command = "powershell.exe -NoProfile -NonInteractive -File """ & WScript.Arguments(0) & """ -JobFile """ & WScript.Arguments(1) & """"
WScript.Quit shell.Run(command, 0, True)
