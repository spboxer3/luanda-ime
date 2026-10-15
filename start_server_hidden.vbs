' ASCII only - VBScript breaks on UTF-8 Chinese comments
Set WshShell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
strPath = fso.GetParentFolderName(WScript.ScriptFullName)
WshShell.CurrentDirectory = strPath

If ServerRunning Then
  WScript.Quit
End If

WshShell.Run "python rime_ai_server.py", 0, False
WScript.Quit

Function ServerRunning
  On Error Resume Next
  Dim wmi, procs, p, cmd
  ServerRunning = False
  Set wmi = GetObject("winmgmts:\\.\root\cimv2")
  If Err.Number <> 0 Then Exit Function
  Set procs = wmi.ExecQuery("Select CommandLine from Win32_Process Where Name='python.exe'")
  For Each p In procs
    cmd = "" & p.CommandLine
    If InStr(1, cmd, "rime_ai_server", 1) > 0 Then
      ServerRunning = True
      Exit Function
    End If
  Next
End Function
