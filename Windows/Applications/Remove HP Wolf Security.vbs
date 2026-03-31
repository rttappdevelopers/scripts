'**********************************************************************************************
'**********************************************************************************************
' Description   : Sure Click Advanced Uninstall script
'**********************************************************************************************
 Dim objFSO
 Dim objFile,oShell
 Set objFSO = CreateObject("Scripting.FileSystemObject")
 Set oShell = WScript.CreateObject("WScript.Shell")

On Error Resume Next
'
'Declare required constants for logging
Const FORAPPENDING = 8
Const FORWRITING = 2
Const INFORMATIONAL = 1
Const ERRORS = 2
Const DEBUGGING = 3
Const HKEY_LOCAL_MACHINE = &H80000002
Const LOGEXTENSION = ".log"

sysdrive = oShell.ExpandEnvironmentStrings("%SYSTEMDRIVE%")
HPNGLOGDIR = sysdrive & "\windows\Logs"

Dim lFile
Const Version = "4.1.5.1297"
Const AppName = "HPSureClickAdvanced"
PACKAGENAME = "HP_SURECLICK_4.1.5.1297-R0_EN"

' Name of the script being run

Dim SP
SP = GetScriptPath()

strComputer = "."
Set objReg = GetObject("winmgmts:\\" & _
    strComputer & "\root\default:StdRegProv") 
	
StartLogging
WriteLog "Uninstall of " & AppName & Version & " Started."

'1. Get GUID by DisplayName
Dim strName, strNameSCA
strNameSC = "HP Sure Click"
strNameSCA = "HP Sure Click Advanced"

Dim sGUID, sGUIDSC, sGUIDSCA
sGUIDSC = ""
sGUIDSCA = ""
sGUIDSC = GetGUIDByDisplayName(strNameSC)
sGUIDSCA = GetGUIDByDisplayName(strNameSCA)

If Len(sGUIDSC) > 0 Then
	Uninstall (sGUIDSC)
End If

If Len(sGUIDSCA) > 0 Then
	Uninstall (sGUIDSCA)
End If

'2. Run msiexec /x <GUID> /qn
Function Uninstall (sGUID)
WriteLog "sGUID=" & sGUID
If Len(sGUID) > 0 Then 'check if empty
	WriteLog "Proceed to uninstall it.."
	ShellRun("msiexec /x " & sGUID & " /qn")
	'WriteLog "msiexec /x " & sGUID & " /qn"
Else
	WriteLog strName & " not found!"
End If
End Function

WriteLog "END"
'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall

Function GetGUIDByDisplayName(strDisplayName)
	On error resume Next
	strGUID = ""
	Set WshShell = CreateObject("WScript.Shell")
	Set oReg=GetObject("winmgmts:{impersonationLevel=impersonate}!\\" & strComputer & "\root\default:StdRegProv")
	strKeyPath = "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
	oReg.EnumKey HKEY_LOCAL_MACHINE, strKeyPath, arrSubKeys
	For Each subkey In arrSubKeys
	 keyname = ""
		keyname = wshshell.RegRead("HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\" & subkey & "\DisplayName")
	 If keyname = strDisplayName then
		strGUID = subkey
	 End If
	Next
	
	GetGUIDByDisplayName = strGUID
End Function

FUNCTION ShellRun(sCmd)
	Dim RC, oEnv

	WriteLog "ShellRun: " & sCmd

	RC = oShell.Run(sCmd,0,True)

	If Err.Number <> 0 Then
		WriteErrorCode Err.Number, Err.Description
		ShellRun = False
	Else
		If RC <> 0 and RC <> 3010 Then
			WriteErrorCode RC, "ShellRun Failed"
			ShellRun = False
		Else
			If RC = 3010 Then
				WriteLog "Success, oShell.Run returned 3010 Reboot required"
			Else
				WriteLog "Success, oShell.Run returned 0"
			End If
			ShellRun = True
		End If
	End If
	
END FUNCTION

FUNCTION IsProductInstalled(sProductCode)
	Dim objReg,strKeyPath,strValueName,strValue
	Set objReg=GetObject("winmgmts:{impersonationLevel=impersonate}!\\" & "." & "\root\default:StdRegProv")
	strKeyPath = "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\" & sProductCode
	strValueName = "DisplayName"
	objReg.GetStringValue HKEY_LOCAL_MACHINE,strKeyPath,strValueName,strValue
	If IsNull(strValue) Then
		IsProductInstalled = False
		WriteLog sProductCode & " is not present in 64 bit hive."
		strKeyPath = "SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\" & sProductCode
		objReg.GetStringValue HKEY_LOCAL_MACHINE,strKeyPath,strValueName,strValue
		If IsNull(strValue) Then
			IsProductInstalled = False
			WriteLog sProductCode & " is not present in 32bit hive."
			exit function
		Else 
			IsProductInstalled = True
			WriteLog sProductCode & " is installed."
		End if
	Else 
		IsProductInstalled = True
		WriteLog sProductCode & " is installed."
	End If	
END FUNCTION

'////////////////////////////////////////////////////////////////////
'/  Name:            	WaitForProcessCompletion(sProcessName)
'/  Main Function:   	Waits for the process to finish
'/ Parameters:		sProcessName (string), process name to wait for e.g. SETUP.EXE
'////////////////////////////////////////////////////////////////////
Function WaitForProcessCompletion(sProcessName)
	Dim oWMIService, oProcess, colProcess, sComputer, bProcessFinished, iErr
		
	sComputer = "."	'this computer


	Set oWMIService = GetObject("winmgmts:{impersonationLevel=impersonate}!\\" &  sComputer & "\root\cimv2") 
	If Err.Number <> 0 Then
		WriteLog "Error occurred connecting to WMI"
		Exit Function
	End If
	
	WriteLog "Started waiting for " & sProcessName
	
	While Not bProcessFinished
	
		bProcessFinished = True
		
		Err.clear
		Set colProcess = oWMIService.ExecQuery ("Select * from Win32_Process Where Name = '" & sProcessName & "'" )
		If Err.Number <> 0 Then
			WriteLog "Error occurred getting process list"
			Exit Function
		End If
		
		For Each oProcess in colProcess
			bProcessFinished = False
		Next
		
		WScript.Sleep(3000)
	Wend
	
	
	set oWMIService = nothing
	Set colProcess = Nothing
	WriteLog "Finished waiting for " & sProcessName
End Function


'--------------------------------------------------------------------
' KillProcesses(sProcessExe)
' Returns		: true if ok, false otherwise
' Parameter(s)	: sProccessExe as string
' Description	: kills the proccess having the exename passes as parameter
'--------------------------------------------------------------------

Function KillProcesses(sProcessExe)
	WriteLog "KillProcesses: " & sProcessExe
	Dim sComputer, oWMIService, colProcessList, oProcess, sMsg
	On Error Resume Next
	sComputer = "."
	Set oWMIService = GetObject("winmgmts:" _
	    & "{impersonationLevel=impersonate}!\\" & sComputer & "\root\cimv2")
	Set colProcessList = oWMIService.ExecQuery _
	    ("Select * from Win32_Process Where Name = '" & sProcessExe & "'")

	For Each oProcess in colProcessList
		oProcess.Terminate()
		KillProcesses = True
		sMsg="'" & oProcess.ExecutablePath & "' process has been killed."
		
		WriteLog sMsg
	Next

	Set oWMIService = Nothing
	Set colProcessList = Nothing
	On Error Goto 0
End Function

'--------------------------------------------------------------------
' StartLogging
'   Creates unicode log and timestamps
'--------------------------------------------------------------------
Sub StartLogging
	Dim sLogFile : sLogFile = GetLogPath & "\" & PACKAGENAME & ".LOG"

	If FileExists( sLogFile ) Then
		Set lFile = objFSO.OpenTextFile(sLogFile, 8, False, -1) 
		WriteBlank
		WriteLogBreak
		WriteLog "Log Appending."
	Else
		Set lFile = objFSO.OpenTextFile(sLogFile, 2, True, -1) 
		WriteLogBreak
		WriteLog "Log Created."
	End If
	WriteLog "Log File : " & sLogFile
	WriteLogBreak
End Sub
'--------------------------------------------------------------------
' CloseLog
'   Finalises log
'--------------------------------------------------------------------
Function CloseLog()
	WriteLog 1, "Logging Finished."
	'lFile.Close
End Function

Sub WriteBlank
	lFile.WriteLine("")
End Sub

'************************************************************************
'** Name          : Function GetLogPath()
'** Returns       : Return a string containing an available directory path for log files
'** Parameter(s)  : Nothing
'************************************************************************
Function GetLogPath()
  
  Dim strLogPath : strLogPath = HPNGLOGDIR
 
  If NOT (objFSO.FolderExists(strLogPath)) Then
    strLogPath = TEMPDIR
    If NOT (objFSO.FolderExists( strLogPath )) Then 
    	CreateDirectory( strLogPath )
    End If 
  End If
  GetLogPath = strLogPath
  
End Function


Sub WriteLog(sText)
	lFile.WriteLine(Now() & " : " & sText)
End Sub
'--------------------------------------------------------------------
' WriteBlank
'   Writes a blank line
'--------------------------------------------------------------------
Sub WriteBlank
	lFile.WriteLine("")
End Sub


'--------------------------------------------------------------------
' WriteOK()
'   Writes standardised success message
'--------------------------------------------------------------------
Sub WriteOK()
	WriteLog "OK."
End Sub

'--------------------------------------------------------------------
' WriteErrorCode(iErrorNumber,sErrorDescription)
'   Writes standardised error text.
'--------------------------------------------------------------------
Sub WriteErrorCode(iErrorNumber,sErrorDescription)
	WriteLog "Error Code: " & iErrorNumber & " (" & sErrorDescription & ")"
End Sub

'--------------------------------------------------------------------
' WriteWarning WarningDescription
'   Writes standardised warning text.
'--------------------------------------------------------------------
Sub WriteWarning(sWarningDescription)
	WriteLog "Warning:" & " (" & sWarningDescription & ")"
End Sub
'--------------------------------------------------------------------
' WriteLogBreak
'   Writes a string of 80 -'s to the log
'--------------------------------------------------------------------
Sub WriteLogBreak
	WriteLog String(80,"-")
End Sub

Function GetScriptPath()
  GetScriptPath = Left(WScript.ScriptFullName, Len(WScript.ScriptFullName) - (Len(WScript.ScriptName) + 1))
End Function

Function FileExists(sFile)
	FileExists = objFSO.FileExists( sFile )
End Function

Function Quote(sStringToQuote)
	Quote=Chr(34) & sStringToQuote & Chr(34)
End Function
