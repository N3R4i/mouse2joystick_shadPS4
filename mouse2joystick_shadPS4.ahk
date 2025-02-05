;	;	;	;	;	;	;	;	;	;	;	;	;	;	;	;
;	Modified for shadPS4 by: N3R4i (https://github.com/N3R4i/)
;	Last Modified Date: 2024-12-04
; 
;	Original Author: Helgef
;	Date: 2016-08-17
;
;	Based on CemuUser8's custom version (https://github.com/CemuUser8/mouse2joystick_custom_CEMU)
;	Date: 2020-05-19
;
;	Description:
;	A feeder script for a virtual joystick. Turns mouse and keyboard input into a virtual joystick input. Tweaked specifically for shadPS4 and Bloodborne. Requires ScpVBus to work.
;	
;	Notes:
;			-#q exit at any time.
;
;	Urls:
;			https://autohotkey.com/boards/viewtopic.php?f=19&t=21489 										- First released here / help / instruction / bug reports.
;			https://github.com/shauleiz/ScpVBus/releases/tag/v1.7.1.2										- ScpVBus driver, needed for mouse to virtual joystick.
;			https://autohotkey.com/boards/viewtopic.php?f=19&t=20703&sid=2619d57dcbb0796e16ea172f238f08a0 	- Original request by crisangelfan.
;			https://autohotkey.com/boards/viewtopic.php?t=5705												- CvJoyInterface.ahk
;
;	Acknowledgements:
;			Helgef - Original creator of mouse2joystic
;			CemuUser8 - Mouse2joystick Custom CEMU version https://github.com/CemuUser8/mouse2joystick_custom_CEMU
;			nefarius/Scarlett.Crush Productions (curse the wolves who ate her) - ScpVBus https://github.com/nefarius/ScpVBus
;			Shaul Eizikovich - vGenInterface https://github.com/shauleiz/vGen
;			evilC - CvJoyInterface.ahk
;			CemuUser8 - CvGenInterface.ahk (modified version of CvJoyInterface.ahk with vXBox device support)
;
version := "v1.4"
#NoEnv  																; Recommended for performance and compatibility with future AutoHotkey releases.
SendMode Input															; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%  											; Ensures a consistent starting directory.
;#Include CvJI/CvJoyInterface.ahk										; Credit to evilC.
#Include CvJI/CvGenInterface.ahk ; A Modifed Interface that I (CemuUser8) added the vXBox device and functions to.
#Include CvJI/MouseDelta.ahk ; Alternate way to see mouse movement
#Include CvJI/SelfDeletingTimer.ahk
; Settings
#MaxHotkeysPerInterval 210
#HotkeyInterval 1000
#InstallMouseHook
#SingleInstance Force
CoordMode,Mouse,Screen
SetMouseDelay,-1
SetBatchLines,-1

; On exit
OnExit("exitFunc")

IF (A_PtrSize < 8) {
	MsgBox,16,Now Requires 64bit, This program requires 64bit. If you are getting this error you must be running the script directly and have 32bit AutoHotkey installed.`n`nPlease change your AutoHotkey installation to the 64bit Unicode version 
	ExitApp
}

;OrigMouseSpeed := ""
;DllCall("SystemParametersInfo", UInt, 0x70, UInt, 0, UIntP, OrigMouseSpeed, UInt, 0) ; Get Original Mouse Speed.
toggle:=1													; On/off parameter for the hotkey.	Toggle 0 means controller is on. The placement of this variable is disturbing.

; If no settings file, create, When changing this, remember to make corresponding changes after the setSettingsToDefault label (error handling) ; Currently at bottom of script
IfNotExist, settings.ini
{
	defaultSettings=
(
[General]
usevXBox=1
vJoyDevice=
vXBoxDevice=1
gameExe=shadPS4.exe
autoActivateGame=1
[General>Setup]
r=80
nnp=1
k=0
freq=1
minmove=0.37
acceleration=0
[General>Hotkeys]
controllerSwitchKey=F1
exitKey=#q
[Mouse2Joystick>Axes]
invertedX=0
invertedY=0
[Mouse2Joystick>Keys]
joystickButtonKeyList=e,Escape,r,f,XButton1,LButton,RButton,MButton,Tab,g,,q,Home,End,Left,Right
joystickButtonKeyListBB=,,,,,,,
[Keyboard Movement>Keys]
upKey=w
leftKey=a
downKey=s
rightKey=d
walkToggleKey=CapsLock
increaseWalkKey=NumpadAdd
decreaseWalkKey=NumpadSub
walkSpeed=0.50
gyroToggleKey=
[Extra Settings]
BotWmouseWheel=0
lockZL=0
lockZLToggleKey=Numpad1
hideCursor=1
useAltMouseMethod=0
alt_xSen=200
alt_ySen=300
jumpMod=0
)
	FileAppend,%defaultSettings%,settings.ini
	IF (ErrorLevel) {
		Msgbox,% 6+16,Error writing to file., There was a problem creating settings.ini
		, make sure you have permission to write to file at %A_ScriptDir%. If the problem persists`, try to run as administrator or change the script directory. Press retry to try again`, continue to set all settings to default or cancel to exit application.
		IfMsgBox Retry
			reload
		Else IfMsgBox Continue
			Goto, setSettingsToDefault	; Currently at bottom of script
		Else 
			ExitApp
	}
	firstRun := True ; Moved out of ini File.
}

; Read settings.
IniRead,allSections,settings.ini
IF (!allSections || allSections="ERROR") { ; Do not think this is ever set to ERROR.
	MsgBox, % 2+16, Error reading file, There was an error reading the settings.ini file`, press retry to try again`, continue to set all settings to default or cancel to exit application.
	IfMsgBox retry
		reload
	Else IfMsgBox Ignore
		Goto, setSettingsToDefault	; Currently at bottom of script
	Else 
		ExitApp
}
Loop,Parse,allSections,`n
{
	IniRead,pairs,settings.ini,%A_LoopField%
	Loop,Parse,pairs,`n
	{
		StringSplit,keyValue,A_LoopField,=
		%keyValue1%:=keyValue2
	}
}
readSettingsSkippedDueToError:	; This comes from setSettingsToDefault If there was an error.

pi:=atan(1)*4													; Approx pi.

; Constants and such. Some values are commented out because they have been stored in the settings.ini file instead, but are kept because they have comments.
moveStickHalf := False
KeyList := []
KeyListByNum := []
KeyListByNumBB := []	;Bloodborne key list

md := new MouseDelta("MouseEvent")

ih := InputHook()
ih.KeyOpt("{All}", "ES")

dr:=0											; Bounce back when hit outer circle edge, in pixels. (This might not work any more, it is off) Can be seen as a force feedback parameter, can be extended to depend on the over extension beyond the outer ring.

; Hotkey(s).
IF (controllerSwitchKey)
	Hotkey,%controllerSwitchKey%,controllerSwitch, on
IF (exitKey)
	Hotkey,%exitKey%,exitFunc, on

mouse2joystick := True
IF (mouse2joystick) {
	Gosub, initCvJoyInterface
	Gosub, mouse2joystickHotkeys
}

; Icon
Menu,Tray,Tip, mouse2joystick customized for shadPS4
Menu,Tray,NoStandard


IF (!A_IsCompiled) { ; If it is compiled it should just use the EXE Icon
	IF (A_OSVersion < "10.0.15063") ; It appears that the Icon has changed number on the newest versions of Windows.
		useIcon := 26
	Else IF (A_OSVersion >= "10.0.16299")
		useIcon := 28
	Else
		useIcon := 27
	Try
		Menu,Tray,Icon,ddores.dll, %useIcon% 
}
;Menu,Settings,openSettings
Menu,Tray,Add,Settings,openSettings
Menu,Tray,Add,
IF (vGenInterface.IsVBusExist())
	Menu,Tray,Add,Uninstall ScpVBus, uninstallBus
Else
	Menu,Tray,Add,Install ScpVBus, installBus
Menu,Tray,Add,
Menu,Tray,Add,Reset to shadPS4, selectGameMenu
Menu,Tray,Add
Menu,Tray,Add,About,aboutMenu
Menu,Tray,Add,Help,helpMenu
Menu,Tray,Add
Menu,Tray,Add,Reload,reloadMenu
Menu,Tray,Add,Exit,exitFunc
Menu,Tray,Default, Settings

IF freq is not Integer
	freq := 1

pmX:=invertedX ? -1:1							; Sign for inverting axis
pmY:=invertedY ? -1:1
snapToFullTilt:=0.005							; This needs to be improved.
;nnp:=4	 										; Non-linearity parameter for joystick output, 1 = linear, >1 higher sensitivity closer to full tilt, <1 higher sensitivity closer to deadzone. Recommended range, [0.1,6]. 
; New parameters

; Mouse blocker
; Transparent window that covers game screen to prevent game from capture the mouse.
;Gui, Controller: New	;disabled for now
;Gui, Controller: +ToolWindow -Caption +AlwaysOnTop +HWNDstick
;Gui, Controller: Color, 000000

; Spam user with useless info, first time script runs.
IF (firstRun)
	MsgBox,64,Welcome,Settings are accessed via Tray icon -> Settings.


Return
; End autoexec.

selectGameMenu:
	TrayTip, % "Game reset to shadPS4.exe", % "If you want something different manually edit the settings, or 'settings.ini' file directly",,0x10
	gameExe := "shadPS4.exe"
	IniWrite, %gameExe%, settings.ini, General, gameExe
Return

reloadMenu:
	Reload
Return

aboutMenu:
	Msgbox,32,About, Modified for shadPS4 by N3R4i,`nbased on: CemuUser8's v0.4.1.4`n`nVersion:`n%version%
Return

helpMenu:
	Msgbox,% 4 + 32 ,, If you need help with Mouse2Joystick, seek me out on GitHub.`n`nOpen link in browser?`nhttps://github.com/N3R4i/mouse2joystick_shadPS4
	IfMsgBox Yes
		Run, https://github.com/N3R4i/mouse2joystick_shadPS4
Return

initCvJoyInterface:
	Global vXBox := usevXBox
	; Copied from joytest.ahk, from CvJoyInterface by evilC
	; Create an object from vJoy Interface Class.
	vGenInterface := new CvGenInterface()
		; Was vJoy installed and the DLL Loaded?
	IF (!vXBox and !vGenInterface.vJoyEnabled()){	;driver check start
		; Show log of what happened
		Msgbox,% 4+16,vJoy Error,% "vJoy(not supported by shadPS4) installation not found. Press no to change to ScpVBus and exit application.`nLog:`n" . vGenInterface.LoadLibraryLog "`n`nRetry?" ; Error handling changed.
		IfMsgBox Yes
		{
			reload
		}
		Else {
			vXBox := True
			IniWrite,1, settings.ini, General, usevXBox ; Turn off the setting for the next run as well.
		}
		ExitApp
	}
	IF (vXBox AND !vGenInterface.IsVBusExist()) {
		Msgbox,% 4 + 32 , Virtual xBox Bus not found, Press Yes to install ScpVBus`n`n(Script will reload after installation)
		IfMsgBox Yes
			InstallUninstallScpVBus(True)
		Else {
			;vXBox := False
			;IniWrite,0, settings.ini, General, usevXBox ; Turn off the setting for the next run as well.
			ExitApp
		}
	}
	ValidDevices := ""
	Loop 15 {
		IF (vGenInterface.Devices[A_Index].IsAvailable())
			ValidDevices .= A_Index . "|"
	}	 ;driver check end
	IF (vXBox) {
		IF (vXboxDevice != vstick.DeviceID OR !vstick.GetLedNumber()) {
			IF (isObject(vstick)) {
				vstick.Unplug()
				vstick.Relinquish()
			}
			;vGenInterface.UnPlugAll() ; Not sure how this interacts when a real controller is also plugged in. But I seem to notice that there is an issue if not ran.
			Global vstick := vGenInterface.xDevices[vXBoxDevice]
			vstick.Acquire()
			TrayTip,, % "Controller #" vstick.GetLedNumber() 
		}

	}
	Else {
		IF (isObject(vstick)) {
			vstick.Unplug()
			vstick.Relinquish()
		}
		Global vstick := vGenInterface.Devices[vJoyDevice]
	}
Return

; Hotkey labels
; This switches on/off the controller.
controllerSwitch:
	IF (toggle) { ; Starting controller
		IF (autoActivateGame) {
			WinActivate,ahk_exe %gameExe%
			WinWaitActive, ahk_exe %gameExe%,,2
			IF (ErrorLevel) {	
				MsgBox,16,Error, %gameExe% not activated.
				Return
			}
			WinGetPos,gameX,gameY,gameW,gameH,ahk_exe %gameExe%									; Get game screen position and dimensions
			WinGet, gameID, ID, ahk_exe %gameExe%
		}
		Else {
			gameX:=0
			gameY:=0
			gameW:=A_ScreenWidth
			gameH:=A_ScreenHeight
		}
		
		; Controller origin is center of game screen or screen If autoActivateGame:=0.
		OX:=Round(gameX+gameW/2)	;Needs to be rounded, because if the game window size is odd, this would result in a fraction, but mouse can only move to a whole pixel position, and the 0.5 deviation would cause stick drift
		OY:=Round(gameY+gameH/2)
		IF (!OX OR !OY) {
			OX := 500
			OY := 500
		}

		; Move mouse to controller origin
		MouseMove,OX,OY
		
		; The mouse blocker
		;Gui, Controller: Show,NA x%gameX% y%gameY% w%gameW% h%gameH%,Controller	;disabled for now, as this makes unbound mouse buttons break the script
		;WinSet,Transparent,1,ahk_id %stick%	
		
		IF (hideCursor)
			show_Mouse(False)
		;DllCall("SystemParametersInfo", UInt, 0x71, UInt, 0, UInt, 10, UInt, 0)
		
		IF (useAltMouseMethod) {
			md.Start()
			LockMouseToWindow("ahk_id " . stick)
		}
		Else
			SetTimer,mouseTojoystick,%freq%

	}
	Else {	; Shutting down controller
		setStick(0,0)															; Stick in equilibrium.
		setStick(0,0, True)
		IF (useAltMouseMethod) {
			LockMouseToWindow(False)
			md.Stop()
		}
		Else
			SetTimer,mouseTojoystick,Off
		
		IF (hideCursor)
			show_Mouse()				; No need to show cursor if not hidden.
		;DllCall("SystemParametersInfo", UInt, 0x71, UInt, 0, UInt, OrigMouseSpeed, UInt, 0)  ; Restore the original speed.
		Gui, Controller:Hide
	
	}
	toggle:=!toggle
Return

; Hotkeys mouse2joystick
#IF (!toggle && mouse2joystick)
#IF
mouse2joystickHotkeys:
	Hotkey, IF, (!toggle && mouse2joystick)
		SetStick(0,0, True)
		IF (walkToggleKey)
			HotKey,%walkToggleKey%,toggleHalf, On
		IF (decreaseWalkKey)
			HotKey,%decreaseWalkKey%,decreaseWalk, On
		IF (increaseWalkKey)
			HotKey,%increaseWalkKey%,increaseWalk, On
		IF (lockZLToggleKey AND lockZL)
			HotKey,%lockZLToggleKey%,toggleAimLock, On
		IF (BotWmouseWheel) {
			Hotkey,WheelUp, overwriteWheelUp, on
			Hotkey,WheelDown, overwriteWheelDown, on
		}
		IF (gyroToggleKey) {
			HotKey,%gyroToggleKey%, GyroControl, on
			HotKey,%gyroToggleKey% Up, GyroControlOff, on
		}
		Hotkey,%upKey%, overwriteUp, on 
		Hotkey,%upKey% Up, overwriteUpup, on
		Hotkey,%leftKey%, overwriteLeft, on 
		Hotkey,%leftKey% Up, overwriteLeftup, on
		Hotkey,%downKey%, overwriteDown, on 
		Hotkey,%downKey% Up, overwriteDownup, on
		Hotkey,%rightKey%, overwriteRight, on 
		Hotkey,%rightKey% Up, overwriteRightup, on

	KeyListByNumBB := []	;Feed joystickButtonKeyListBB keys into KeyListByNumBB[#] and turn on  hotkeys
	Loop, Parse, joystickButtonKeyListBB, `,
	{
		If !A_LoopField
			continue
		KeyListByNumBB[A_Index] := A_LoopField
		Hotkey, % (KeyListByNumBB[A_Index]), actionBB%A_Index%, on
	}
	
	KeyListByNum := []	;joystickButtonKeyList keys have to be fed into KeyListByNum[#] here
	Loop, Parse, joystickButtonKeyList, `,
	{
	keyName := A_LoopField
	If !keyName
		continue
	KeyListByNum[A_Index] := keyName
	}

	KeyList := []
	Loop, Parse, joystickButtonKeyList, `,
	{
		useButton := A_Index
		Loop, Parse, A_LoopField, |
		{	
			keyName=*%A_LoopField%	;added * so hotkeys work even when modifiers are held
			IF (!keyName)
				Continue
			KeyList[keyName] := useButton
			Hotkey,%keyName%, pressJoyButton, on
			Hotkey,%keyName% Up, releaseJoyButton, on
		}
	}
	Hotkey, IF
Return

Moving() {	;check movement key state
	Global
	If GetKeyState(upKey, "P") OR GetKeyState(downKey, "P") OR GetKeyState(leftKey, "P") OR GetKeyState(rightKey, "P")	{
		return 1
	} Else {
		return 0
	}
}

Sprinting() {	;check sprinting key state
	Global
	If GetKeyState(KeyListByNum[2], "P") OR GetKeyState(KeyListByNumBB[6], "P")	{
		return 1
	} Else {
		return 0
	}
}

actionBB1:	;#1 Dodge+Backstep+Prevent jump
	If (!jumpMod) {	;only used for vanilla
		If Moving() AND Sprinting()  {	;prevents jumping if dodge is used during sprinting
			vstick.SetBtn(0,2)
			sleep 350
		}
		If (vsprintTimerPost!=-1) {	;prevents jumping is sprint was used recently
			sleep vsprintTimerPostMax-vsprintTimerPost
		}
		vstick.SetBtn(1,2)
		sleep 30
		vstick.SetBtn(0,2)	;causes dodge on key press, rather than on key release
		sleep 30
		If Moving() AND Sprinting() {	;keep sprinting
			vstick.SetBtn(1,2)
		}
		Keywait % (KeyListByNumBB[1])
	}
return

actionBB2:	;#2 Dodge+Prevent jump
	If (!jumpMod) {	;only used for vanilla
		IF Moving() {
			If Sprinting() {	;prevents jumping if dodge is used during sprinting
				vstick.SetBtn(0,2)
				sleep 350
			}
			If (vsprintTimerPost!=-1) {	;prevents jumping is sprint was used recently
				sleep vsprintTimerPostMax-vsprintTimerPost
			}
			vstick.SetBtn(1,2)
			sleep 30
			vstick.SetBtn(0,2)	;causes dodge on key press, rather than on key release
			sleep 30
			If Sprinting() {	;keep sprinting
				vstick.SetBtn(1,2)
			}
			Keywait, % (KeyListByNumBB[2])
			Return
		}
		setStickLeft("N/A",1, True)
		sleep 30
		vstick.SetBtn(1,2)
		sleep 30
		vstick.SetBtn(0,2)
		sleep 30
		setStickLeft("N/A",0, True)
		Keywait % (KeyListByNumBB[2])
	}
return

actionBB3:	;#3 Dodge+Backstep+Allow Jump		OK
	If (vSprinting=1)	{	;if ○ is held release it
		vstick.SetBtn(0,2)
		sleep 30
	}
	vstick.SetBtn(1,2)
	sleep 30
	vstick.SetBtn(0,2)
	sleep 30
	If (vSprinting=1)	{	;keep sprinting
		vstick.SetBtn(1,2)
	}
	Keywait % (KeyListByNumBB[3])
return

actionBB4:	;#4 Dodge+Allow jump		OK
	If (vSprinting=1) {	;if ○ is held release it
		vstick.SetBtn(0,2)
		sleep 30
	}
	IF Moving() {
		vstick.SetBtn(1,2)
		sleep 30
		vstick.SetBtn(0,2)
		sleep 30
	} Else {	;if not moving, force roll forward
		setStickLeft("N/A",1, True)
		sleep 30
		vstick.SetBtn(1,2)
		sleep 30
		vstick.SetBtn(0,2)
		sleep 30
		setStickLeft("N/A",0, True)
	}
	If (vSprinting=1) {	;keep sprinting
		vstick.SetBtn(1,2)
	}
	Keywait % (KeyListByNumBB[4])
return

actionBB5:	;#5 Backstep
	If (vSprinting=1) {	;if ○ is held release it
		setStickLeft(0,0, True)	;stop moving
		vstick.SetBtn(0,2)
		sleep 30
	}
	IF Moving() {
		setStickLeft(0,0, True)	;stop moving
			sleep 30
		vstick.SetBtn(1,2)
			sleep 30
		vstick.SetBtn(0,2)
			sleep 30
		KeepStickHowItWas()	;keep moving after backstep
	} Else {
		vstick.SetBtn(1,2)
		sleep 30
		vstick.SetBtn(0,2)
		sleep 30
	}
	If (vSprinting=1) {	;keep sprinting
		vstick.SetBtn(1,2)
	}
	Keywait % (KeyListByNumBB[5])
return

actionBB6:	;#6 Sprint
	If (jumpMod) {	;if jumpmod is used we don't need extra timers
		While GetKeyState(KeyListByNumBB[4], "P") {
			IF Moving() {
				vstick.SetBtn(1,2)	;start sprinting
				vSprinting:=1	;to know O button state
				sleep 500	;don't release it too early to prevent rolling
				Keywait % (KeyListByNumBB[4])
				vstick.SetBtn(0,2)
				vSprinting:=0
				Return
			}
			sleep 100	;prevents hotkey spam
		}
		return
	} Else {
		While GetKeyState(KeyListByNumBB[6], "P") {
			IF Moving() {
				vstick.SetBtn(1,2)	;start sprinting
				vSprinting:=1	;to know O button state
				SetTimer, IsSprinting, On	;start sprint timer
				sleep 500	;don't release it too early to prevent rolling
				Keywait % (KeyListByNumBB[6])
				vstick.SetBtn(0,2)
				vSprinting:=0	;to know O button state
				vsprintTimer=0
				vsprintTimerPost=0
				SetTimer, WasSprinting, 25	;timer since sprinting stopped
				Return
			}
			sleep 100	;prevents hotkey spam
		}
	}
return

actionBB7:	;#7 Jump (causes dodge if used too early, which is difficult to fix)
	If (jumpMod) {
		vstick.SetBtn(1,9)
		sleep 30
		vstick.SetBtn(0,9)
		Keywait % KeyListByNumBB[5]
		return
	} Else {
		SetTimer, IsSprinting, Off
		IF Moving() {
			If Sprinting() {
				sleep vsprintTimerMax-vsprintTimer
				vstick.SetBtn(0,2)
				sleep 30
				vstick.SetBtn(1,2)
				sleep 30
				vstick.SetBtn(0,2)
				sleep 30
				If Sprinting() {	;keep sprinting
					vstick.SetBtn(1,2)
				}
				vsprintTimer=0
				SetTimer, IsSprinting, On
				Keywait % (KeyListByNumBB[7])
				return
			}
			If (vsprintTimerPost>-1) AND (vsprintTimerPost<=150) {	;Allow jumping max 150ms after sprinting
				vstick.SetBtn(1,2)
				sleep 30
				vstick.SetBtn(0,2)
			}
			Keywait % (KeyListByNumBB[7])
		}	
	}
return

actionBB8:	;#8 Jump attack
	IF Moving() {
		setStickLeft(0,0, True)
		sleep 30
		KeepStickHowItWas()
	} Else {
		setStickLeft("N/A",1, True)
	}
	sleep 30
	vstick.SetAxisByIndex(100,3)
	sleep 30
	vstick.SetAxisByIndex(0,3)
	sleep 30
	setStickLeft("N/A",0, True)
	KeepStickHowItWas()
	Keywait % (KeyListByNumBB[8])
return

actionBB9:
short:=30
long:=100
	vstick.SetBtn(1,8)	;start
	sleep %short%
	vstick.SetBtn(0,8)
	sleep %long%
	vstick.SetPOV(270)	;D-Left
	sleep %short%
	vstick.SetPOV(-1)
	sleep %long%
	vstick.SetBtn(1,1)	;X
	sleep %short%
	vstick.SetBtn(0,1)
	sleep %long%
	vstick.SetPOV(0)	;D-Up
	sleep %short%
	vstick.SetPOV(-1)
	sleep %long%
	vstick.SetBtn(1,1)	;X
	sleep %short%
	vstick.SetBtn(0,1)
	sleep %long%
	vstick.SetPOV(270)	;D-Left
	sleep %short%
	vstick.SetPOV(-1)
	sleep 400
	vstick.SetBtn(1,1)	;X
	sleep %short%
	vstick.SetBtn(0,1)
return

kickAttack:	;cut content, could be usefull if a modder restores it
	IF GetKeyState(upKey, "P") or GetKeyState(downKey, "P") or GetKeyState(leftKey, "P") or GetKeyState(rightKey, "P") {	;check if moving
		setStickLeft(0,0, True)	;stop moving
		sleep 30
		Halted=1	
	}
	setStickLeft("N/A",1, True)
	sleep 30
	vstick.SetBtn(1,6)
	sleep 30
	vstick.SetBtn(0,6)
	sleep 30
	setStickLeft("N/A",0, True)
	If (Halted=1) {	;keep moving
		KeepStickHowItWas()
	}
	Halted=0
return

IsSprinting:	;Sprint timer
vsprintTimer=0
vsprintTimerMax=900	;max time to wait with jumping after sprinting started
	While GetKeyState(KeyListByNum[2], "P") OR GetKeyState(KeyListByNumBB[6], "P") {
		If (vsprintTimer<vsprintTimerMax) {
			vsprintTimer+=50
			sleep 50
		}
		Else {	;cap out at vsprintTimerMax
			vsprintTimer:=vsprintTimerMax
			sleep 250	;this fixes the camera stuttering while sprinting
		}
	}
	vsprintTimer=0
	SetTimer, IsSprinting, Off
Return

WasSprinting:	;Post-sprint timer
vsprintTimerPost=0
vsprintTimerPostMax=350	;max time wait with rolling after sprinting stopped
	While (vsprintTimerPost<vsprintTimerPostMax) {
		vsprintTimerPost+=50
		sleep 50
	}
	vsprintTimerPost=-1
	SetTimer, WasSprinting, Off
Return

; Labels for pressing and releasing joystick buttons.
pressJoyButton:
	keyName:=A_ThisHotkey
	joyButtonNumber := KeyList[keyName] ; joyButtonNumber:=A_Index
	If InStr(keyName, "wheel")
		new SelfDeletingTimer(100, "ReleaseWheel", joyButtonNumber)
	IF (!vXBox){
		IF (joyButtonNumber = 7 AND lockZL) {
			IF (ZLToggle)
				vstick.SetBtn(0,joyButtonNumber)
			Else
				vstick.SetBtn(1,joyButtonNumber)
		}
		Else IF (joyButtonNumber = 8 AND BotWmotionAim) {
			GoSub, GyroControl
			vstick.SetBtn(1,joyButtonNumber)
		}
		Else IF (joyButtonNumber)
			vstick.SetBtn(1,joyButtonNumber)
	}
	Else {
		Switch joyButtonNumber
		{
		Case 2:
			vstick.SetBtn(1,joyButtonNumber)
			vSprinting:=1	;to know O button state
			If (!jumpMod) {
				SetTimer, IsSprinting, On	;Sprint timer
				SetTimer, WasSprinting, Off	;Post-sprint timer
			}
		Case 7:
			IF (lockZL AND ZLToggle)
				vstick.SetAxisByIndex(0,6)
			Else
				vstick.SetAxisByIndex(100,6)
			return
		Case 8:
			vstick.SetAxisByIndex(100,3)
			return
		Case 9:
			vstick.SetBtn(1,joyButtonNumber-1)
			return
		Case 10:
			vstick.SetBtn(1,joyButtonNumber-3)
			return
		Case 11,12:
			vstick.SetBtn(1,joyButtonNumber-2)
			return
		Case 13:
			vstick.SetPOV(0)
			return
		Case 14:
			vstick.SetPOV(180)
			return
		Case 15:
			vstick.SetPOV(270)
			return
		Case 16:
			vstick.SetPOV(90)
			return
		Default:
			vstick.SetBtn(1,joyButtonNumber)
			return
		}
	}
Return

ReleaseWheel(keyNum) { ; This is duplicated of the label below, it had to be added so I could release mouse wheel keys as they don't fire Up keystrokes.
	Global
	IF (!vXBox){
		IF (keyNum = 7 AND lockZL) {
			IF (ZLToggle)
				vstick.SetBtn(1,keyNum)
			Else
				vstick.SetBtn(0,keyNum)
		}
		Else IF (keyNum = 8 AND BotWmotionAim) {
			vstick.SetBtn(0,keyNum)
			GoSub, GyroControlOff
		}
		Else IF (keyNum)
			vstick.SetBtn(0,keyNum)
	}
	Else {
		Switch keyNum
		{
			Case 7:
				IF (lockZL AND ZLToggle)
					vstick.SetAxisByIndex(100,6)
				Else
					vstick.SetAxisByIndex(0,6)
			Case 8:
				vstick.SetAxisByIndex(0,3)
			Case 9:
				vstick.SetBtn(0,keyNum-1)
			Case 10:
				vstick.SetBtn(0,keyNum-3)
			Case 11,12:
				vstick.SetBtn(0,keyNum-2)
			Case 13,14,15,16:
				vstick.SetPOV(-1)
			Default:
				vstick.SetBtn(0,keyNum)
		}
	}
	Return
}

releaseJoyButton:
	keyName:=RegExReplace(A_ThisHotkey," Up$")
	joyButtonNumber := KeyList[keyName] ; joyButtonNumber:=A_Index
	IF (!vXBox){
		IF (joyButtonNumber = 7 AND lockZL) {
			IF (ZLToggle)
				vstick.SetBtn(1,joyButtonNumber)
			Else
				vstick.SetBtn(0,joyButtonNumber)
		}
		Else IF (joyButtonNumber = 8 AND BotWmotionAim) {
			vstick.SetBtn(0,joyButtonNumber)
			GoSub, GyroControlOff
		}
		Else IF (joyButtonNumber)
			vstick.SetBtn(0,joyButtonNumber)
	}
	Else {
		Switch joyButtonNumber
		{
			Case 2:
				vstick.SetBtn(0,joyButtonNumber)
				vSprinting:=0	;to know O button state
				vsprintTimerPost=0
				If (!jumpMod) {
					SetTimer, IsSprinting, Off	;Sprint timer
					SetTimer, WasSprinting, 25	;Post-sprint timer
				}
			Case 7:
				IF (lockZL AND ZLToggle)
					vstick.SetAxisByIndex(100,6)
				Else
					vstick.SetAxisByIndex(0,6)
			Case 8:
				vstick.SetAxisByIndex(0,3)
			Case 9:
				vstick.SetBtn(0,joyButtonNumber-1)
			Case 10:
				vstick.SetBtn(0,joyButtonNumber-3)
			Case 11,12:
				vstick.SetBtn(0,joyButtonNumber-2)
			Case 13,14,15,16:
				vstick.SetPOV(-1)
			Default:
				vstick.SetBtn(0,joyButtonNumber)
		}
	}
Return

GyroControl:
	;DllCall("SystemParametersInfo", UInt, 0x71, UInt, 0, UInt, 4, UInt, 0) ; Slow mouse movement down a little bit
	IF (BotWmouseWheel) {
		Hotkey, If, (!toggle && mouse2joystick)
		Hotkey,WheelUp, overwriteWheelUp, off
		Hotkey,WheelDown, overwriteWheelDown, off
	}
	SetStick(0,0)
	Gui, Controller:Hide
	IF (!useAltMouseMethod) {
		LockMouseToWindow("ahk_id " . gameID)
		SetTimer, mouseTojoystick, Off
	}
	Click, Right, Down
Return

GyroControlOff:
	Click, Right, Up
	IF (BotWmouseWheel) {
		Hotkey, If, (!toggle && mouse2joystick)
		Hotkey,WheelUp, overwriteWheelUp, on
		Hotkey,WheelDown, overwriteWheelDown, on
	}
	;DllCall("SystemParametersInfo", UInt, 0x71, UInt, 0, UInt, 10, UInt, 0)  ; Restore the original speed.
	Gui, Controller:Show, NA
	IF (!useAltMouseMethod){
		LockMouseToWindow()
		SetTimer, mouseTojoystick, On
	}
Return

toggleAimLock:
	IF (vXbox)
		vstick.SetAxisByIndex((ZLToggle := !ZLToggle) ? 100 : 0,6)
	Else
		vstick.SetBtn((ZLToggle := !ZLToggle),7)
Return

toggleHalf:
	moveStickHalf := !moveStickHalf
	KeepStickHowItWas()
Return

decreaseWalk:
	walkSpeed -= 0.05
	IF (walkSpeed < 0)
		walkSpeed := 0
	KeepStickHowItWas()
	IniWrite, % walkSpeed:= Round(walkSpeed, 2), settings.ini, Keyboard Movement>Keys, walkSpeed
	GUI, Main:Default
	GUIControl,,opwalkSpeedTxt, % Round(walkSpeed * 100) "%"
Return

increaseWalk:
	walkSpeed += 0.05
	IF (walkSpeed > 1)
		walkSpeed := 1
	KeepStickHowItWas()
	IniWrite, % walkSpeed := Round(walkSpeed, 2), settings.ini, Keyboard Movement>Keys, walkSpeed
	GUI, Main:Default
	GUIControl,,opwalkSpeedTxt, % Round(walkSpeed * 100) "%"
Return

KeepStickHowItWas() {
	Global moveStickHalf, walkSpeed, upKey, leftKey, downKey, rightKey
	IF (GetKeyState(downKey, "P"))
		setStickLeft("N/A",(moveStickHalf ? -1 * walkSpeed : -1), True)
	IF (GetKeyState(rightKey, "P"))
		setStickLeft((moveStickHalf ? 1 * walkSpeed : 1),"N/A", True)
	IF (GetKeyState(leftKey, "P"))
		setStickLeft((moveStickHalf ? -1 * walkSpeed : -1),"N/A", True)
	IF (GetKeyState(upKey, "P"))
		setStickLeft("N/A",(moveStickHalf ? 1 * walkSpeed : 1), True)
}

overwriteUp:
Critical, On
IF (moveStickHalf)
	setStickLeft("N/A",1 * walkSpeed, True)
Else
	setStickLeft("N/A",1, True)
Critical, Off
Return
overwriteUpup:
Critical, On
IF (GetKeyState(downKey, "P")) {
	IF (moveStickHalf)
		setStickLeft("N/A",-1 * walkSpeed, True)
	Else
		setStickLeft("N/A",-1, True)
}
Else
	setStickLeft("N/A",0, True)
Critical, Off
Return

overwriteLeft:
Critical, On
IF (moveStickHalf)
	setStickLeft(-1 * walkSpeed,"N/A", True)
Else
	setStickLeft(-1,"N/A", True)
Critical, Off
Return
overwriteLeftup:
Critical, On
IF (GetKeyState(rightKey, "P")) {
	IF (moveStickHalf)
		setStickLeft(1 * walkSpeed,"N/A", True)
	Else
		setStickLeft(1,"N/A", True)
}
Else
	setStickLeft(0,"N/A", True)
Critical, Off
Return

overwriteRight:
Critical, On
IF (moveStickHalf)
	setStickLeft(1 * walkSpeed,"N/A", True)
Else
	setStickLeft(1,"N/A", True)
Critical, Off
Return
overwriteRightup:
Critical, On
IF (GetKeyState(leftKey, "P")) {
	IF (moveStickHalf)
		setStickLeft(-1 * walkSpeed,"N/A", True)
	Else
		setStickLeft(-1,"N/A", True)
}
Else
	setStickLeft(0,"N/A", True)
Critical, Off
Return

overwriteDown:
Critical, On
IF (moveStickHalf)
	setStickLeft("N/A",-1 * walkSpeed, True)
Else
	setStickLeft("N/A",-1, True)
Critical, Off
Return
overwriteDownup:
Critical, On
IF (GetKeyState(upKey, "P")) {
	IF (moveStickHalf)
		setStickLeft("N/A",1 * walkSpeed, True)
	Else
		setStickLeft("N/A",1, True)
}
Else
	setStickLeft("N/A",0, True)
Critical, Off
Return

overwriteWheelUp:
	SetStick(0,0)
	IF (!alreadyDown){
		IF (vXbox)
			vstick.SetPOV(90)
		Else
			vstick.SetBtn(1,16)
		alreadyDown := True
		DllCall("Sleep", Uint, 250)
	}
	SetStick(-1,0)
	DllCall("Sleep", Uint, 30)
	SetStick(0,0)
	SetTimer, ReleaseDPad, -650 ; vstick.SetBtn(0,16)
Return
overwriteWheelDown:
	SetStick(0,0)
	IF (!alreadyDown){
		IF (vXbox)
			vstick.SetPOV(90)
		Else
			vstick.SetBtn(1,16)
		alreadyDown := True
		DllCall("Sleep", Uint, 250)
	}
	SetStick(1,0)
	DllCall("Sleep", Uint, 30)
	SetStick(0,0)
	SetTimer, ReleaseDPad, -650 ; vstick.SetBtn(0,16)
Return

ReleaseDPad:
	IF (vXbox)
		vstick.SetPOV(-1)
	Else
		vstick.SetBtn(0,16)
	alreadyDown := False
	SetTimer, ReleaseDPad, Off
Return

; Labels

mouseTojoystick:
	Critical, On
	mouse2joystick(r,dr,OX,OY)
	Critical, Off
Return

; Functions

mouse2joystick(r,dr,OX,OY) {
	; r is the radius of the outer circle.
	; dr is a bounce back parameter.
	; OX is the x coord of circle center.
	; OY is the y coord of circle center.
	Global k, nnp, AlreadyDown
	MouseGetPos,X,Y
	X-=OX										; Move to controller coord system.
	Y-=OY
	RR:=sqrt(X**2+Y**2)
	IF (RR>r) {								; Check If outside controller circle.
		X:=round(X*(r-dr)/RR)
		Y:=round(Y*(r-dr)/RR)
		RR:=sqrt(X**2+Y**2)
		DllCall("SetCursorPos", "int", X+OX, "int", Y+OY)	; Calculate point on controller circle, move back to screen/window coords, and move mouse. N3R4i: Changed from MouseMove to DllCall. This fixes real mouse button input being sent instead of the assigned hotkey, and also fixes the mouse not working after turning off the script
	}
	
	; Calculate angle
	phi:=getAngle(X,Y)
	DllCall("SetCursorPos", "int", OX, "int", OY)	;adding one more MouseMove here makes the cursor jump back to the center more consistently, which reduces the occasional camera stutter
	
	IF (RR>k*r AND !AlreadyDown) 								; Check If outside inner circle/deadzone.
		action(phi,((RR-k*r)/(r-k*r))**nnp)		; nnp is a non-linearity parameter.	
	Else
		setStick(0,0)							; Stick in equllibrium.

	DllCall("SetCursorPos", "int", OX, "int", OY)
}

action(phi,tilt) {	
	; This is for mouse2joystick.
	; phi ∈ [0,2*pi] defines in which direction the stick is tilted.
	; tilt ∈ (0,1] defines the amount of tilt. 0 is no tilt, 1 is full tilt.
	; When this is called it is already established that the deadzone is left, or the inner radius.
	; pmX/pmY is used for inverting axis.
	; snapToFullTilt is used to ensure full tilt is possible, this needs to be improved, should be dependent on the sensitivity.
	Global pmX,pmY,pi,snapToFullTilt

	; Adjust tilt
	tilt:=tilt>1 ? 1:tilt
	IF (snapToFullTilt!=-1)
		tilt:=1-tilt<=snapToFullTilt ? 1:tilt
	
	; Two cases with forward+right
	; Tilt is forward and slightly right.
	lb:=3*pi/2										; lb is lower bound
	ub:=7*pi/4										; ub is upper bound
	IF (phi>=lb && phi<=ub)							
	{
		x:=pmX*tilt*scale(phi,ub,lb)
		y:=pmY*tilt
		setStick(x,y)
		Return
	}
	; Tilt is slightly forward and right.
	lb:=7*pi/4										; lb is lower bound
	ub:=2*pi						; ub is upper bound
	IF (phi>=lb && phi<=ub)							
	{
		x:=pmX*tilt
		y:=pmY*tilt*scale(phi,lb,ub)
		setStick(x,y)
		Return
	}
	
	; Two cases with right+downward
	; Tilt is right and slightly downward.
	lb:=0											; lb is lower bound
	ub:=pi/4										; ub is upper bound
	IF (phi>=lb && phi<=ub)							
	{
		x:=pmX*tilt
		y:=-pmY*tilt*scale(phi,ub,lb)
		setStick(x,y)
		Return
	}
	; Tilt is downward and slightly right.
	lb:=pi/4										; lb is lower bound
	ub:=pi/2										; ub is upper bound
	IF (phi>=lb && phi<=ub)							
	{
		x:=pmX*tilt*scale(phi,lb,ub)
		y:=-pmY*tilt
		setStick(x,y)
		Return
	}
	
	; Two cases with downward+left
	; Tilt is downward and slightly left.
	lb:=pi/2										; lb is lower bound
	ub:=3*pi/4										; ub is upper bound
	IF (phi>=lb && phi<=ub)							
	{
		x:=-pmX*tilt*scale(phi,ub,lb)
		y:=-pmY*tilt
		setStick(x,y)
		Return
	}
	; Tilt is left and slightly downward.
	lb:=3*pi/4										; lb is lower bound
	ub:=pi											; ub is upper bound
	IF (phi>=lb && phi<=ub)							
	{
		x:=-pmX*tilt
		y:=-pmY*tilt*scale(phi,lb,ub)
		setStick(x,y)
		Return
	}
	
	; Two cases with forward+left
	; Tilt is left and slightly forward.
	lb:=pi											; lb is lower bound
	ub:=5*pi/4										; ub is upper bound
	IF (phi>=lb && phi<=ub)							
	{
		x:=-pmX*tilt
		y:=pmY*tilt*scale(phi,ub,lb)
		setStick(x,y)
		Return
	}
	; Tilt is forward and slightly left.
	lb:=5*pi/4										; lb is lower bound
	ub:=3*pi/2										; ub is upper bound
	IF (phi>=lb && phi<=ub)							
	{
		x:=-pmX*tilt*scale(phi,lb,ub)
		y:=pmY*tilt
		setStick(x,y)
		Return
	}
	; This should not happen:
	setStick(0,0)
	MsgBox,16,Error, Error at phi=%phi%. Please report.
	Return
}

scale(phi,lb,ub) {
	; let phi->f(phi) then, f(ub)=0 and f(lb)=1
	Return (phi-ub)/(lb-ub)
}

isNumber(var) { ;function for checking if var is a number, can be used with arguments
	If var is number
		return true
	else
		return false
}

sign(var) {	;function for reading var's sign
	return (var>0)-(var<0)
}

setStick(x,y, a := False) {
	; Set joystick x-axis to 100*x % and y-axis to 100*y %
	; Input is x,y ∈ (-1,1) where 1 would mean full tilt in one direction, and -1 in the other, while zero would mean no tilt at all. Using this interval makes it easy to invert the axis
	; (mainly this was choosen beacause the author didn't know the correct interval to use in CvJoyInterface)
	; the input is not really compatible with the CvJoyInterface. Hence this transformation:
	Global minmove	;stick offset value
	Global acceleration	;mouse acceleration amount (0,1)
	magnitude:=Sqrt(x**2+y**2)	;calculate magnitude
	IF (magnitude<>0) {			;prevent division by 0
		o:=Abs(x)/magnitude		;calculate circle correction
		p:=Abs(y)/magnitude
	}
	;IF (magnitude<>0 and magnitude<minmove) {	;alternative deadzone compensation, non-linear
	;	x:=sign(x)*minmove
	;	y:=sign(y)*minmove
	;}
	multx:=(Abs(x)+1)**acceleration	;mouse acceleration
	multy:=(Abs(y)+1)**acceleration
	x:=(sign(x)*minmove)+x*multx	;apply deadzone compensation with linear offset and mouse acceleration
	y:=(sign(y)*minmove)+y*multy
	
	x:=x+0.004	;for some reason in Bloodborne there's more deadzone to the left/up
	y:=y-0.004	
		
	IF Abs(x)>1 {	;cap x between -1,1
		x:=sign(x)
	}
	IF Abs(y)>1 {	;cap y between -1,1
		y:=sign(y)
	}
	IF (magnitude>0) { ;apply circle correction if magnitude has a value
		x:=x*o	
		y:=y*p
		}
	IF (vXBox) {
		x:=(x+1)*50									; This maps x,y (-1,1) -> (0,100)
		y:=(y+1)*50
	}
	Else {
		x:=(x+1)*16384									; This maps x,y (-1,1) -> (0,32768)
		y:=(y+1)*16384
	}
	
	; Use set by index.
	; x = 1, y = 2.
	IF ( (!a AND vXbox) OR (a AND !vXBox) ) { ; IF (GetKeyState("RButton") OR a ) {
		axisX := 4
		axisY := 5
	}
	Else {
		axisX := 1
		axisY := 2
	}
	IF x is number
		vstick.SetAxisByIndex(x,axisX)
	IF y is number
		vstick.SetAxisByIndex(y,axisY)
}

setStickLeft(x,y, a := False) {	;easier to use a separate function for left stick, as a lot of the right stick improvements could easily break it
	; Set joystick x-axis to 100*x % and y-axis to 100*y %
	; Input is x,y ∈ (-1,1) where 1 would mean full tilt in one direction, and -1 in the other, while zero would mean no tilt at all. Using this interval makes it easy to invert the axis
	; (mainly this was choosen beacause the author didn't know the correct interval to use in CvJoyInterface)
	; the input is not really compatible with the CvJoyInterface. Hence this transformation:	
	IF (vXBox) {
		x:=(x+1)*50									; This maps x,y (-1,1) -> (0,100)
		y:=(y+1)*50
	}
	Else {
		x:=(x+1)*16384									; This maps x,y (-1,1) -> (0,32768)
		y:=(y+1)*16384
	}
	
	; Use set by index.
	; x = 1, y = 2.
	IF ( (!a AND vXbox) OR (a AND !vXBox) ) { ; IF (GetKeyState("RButton") OR a ) {
		axisX := 4
		axisY := 5
	}
	Else {
		axisX := 1
		axisY := 2
	}
	IF x is number
		vstick.SetAxisByIndex(x,axisX)
	IF y is number
		vstick.SetAxisByIndex(y,axisY)
}

; Shared functions
getAngle(x,y) {
	Global pi
	IF (x=0)
		Return 3*pi/2-(y>0)*pi
	phi:=atan(y/x)
	IF (x<0 && y>0)
		Return phi+pi
	IF (x<0 && y<=0)
		Return phi+pi
	IF (x>0 && y<0)
		Return phi+2*pi
	Return phi
}

exitFunc() {
	Global
	IF (mouse2Joystick)	{
		setStick(0,0)
		SetStick(0,0, True)
		IF (vXBox)
			vstick.UnPlug()
		vstick.Relinquish()
	}
	
	md.Delete()
	md := ""
	show_Mouse() ; DllCall("User32.dll\ShowCursor", "Int", 1)
	;DllCall("SystemParametersInfo", UInt, 0x71, UInt, 0, UInt, OrigMouseSpeed, UInt, 0)  ; Restore the original speed.
	ExitApp
}

;
; End Script.
; Start settings.
;
openSettings:
If !toggle			; This is probably best.
	Return

tree := "
(
General|Setup,Hotkeys
Mouse2Joystick|Axes,Keys
Keyboard Movement|Keys
BloodBorne Bonus Buttons [B⁴]
Extra Settings
)"
GUI, Main:New, -MinimizeBox, % "Mouse2Joystick for shadPS4 Settings  -  " . version
GUI, Add, Text,, Options:
GUI, Add, TreeView, xm w180 r16 gTreeClick Section
GUI, Add, Button,xs w78 gMainOk, Ok
GUI, Add, Button,x+4 w78 gMainSave Default, Apply
GUI, Add, Tab2, +Buttons -Theme -Wrap vTabControl ys w320 h0 Section, General|General>Setup|General>Hotkeys|Mouse2Joystick|Mouse2Joystick>Axes|Mouse2Joystick>Keys|Keyboard Movement|Keyboard Movement>Keys|BloodBorne Bonus Buttons [B⁴]|Extra Settings
GUIControlGet, S, Pos, TabControl ; Store the coords of this section for future use.
;------------------------------------------------------------------------------------------------------------------------------------------
GUI, Tab, General
	GUI, Add, GroupBox, x%SX% y%SY% w350 h120 Section, Output Mode
	Gui, Font, cRed
	GUI, Add, Radio, %  "xp+10 yp+20 Group vopusevXBox Checked" . !usevXBox, Use vJoy Device (Direct Input) NOT SUPPORTED BY SHADPS4!!
	Gui, Font,
	GUI, Add, Radio, %  "xp yp+20 Checked" . usevXBox, Use vXBox Device (XInput)
	
	GUI, Add, GroupBox, xs+10 yp+20 w90 h50 Section,vJoy Device
	GUI, Add, DropDownList, xp+10 yp+20 vopvJoyDevice w70, % StrReplace(ValidDevices, vJoyDevice, vJoyDevice . "|")
	GUI, Add, GroupBox, ys w90 h50,vXBox Device
	GUI, Add, DropDownList, xp+10 yp+20 vopvXBoxDevice w70, % StrReplace("1|2|3|4|", vXBoxDevice, vXBoxDevice . "|")
	
	GUI, Add, GroupBox, x%SX% yp+45 w350 h50,Executable Name
	GUI, Add, Edit, xp+10 yp+20 vopgameExe w90, %gameExe% 
	GUI, Add, Text, x+m yp+3, The executable name (e.g. shadPS4.exe)
	
	GUI, Add, GroupBox, x%SX% yp+35 w350 h45,Auto Activate Executable
	GUI, Add, Radio, % "xp+10 yp+20 Group vopautoActivateGame Checked" !autoActivateGame, No
	GUI, Add, Radio, % "x+m Checked" autoActivateGame, Yes
	GUI, Add, Text, x+m, Switch to game when toggling controller?
;------------------------------------------------------------------------------------------------------------------------------------------
GUI, Tab, General>Setup
	GUI, Add, GroupBox, x%SX% y%SY% w320 h50 Section, Resistance
	GUI, Add, Edit, xs+10 yp+20 w50 vopr gNumberCheck, %r%
	GUI, Add, Text, x+4 yp+3, Lower values correspond to higher sensitivity 

	GUI, Add, GroupBox, xs yp+30 w320 h50, Non-Linear Sensitivity
	GUI, Add, Edit, xs+10 yp+20 w50 vopnnp gNumberCheck, %nnp%
	GUI, Add, Text, x+4 yp+3, 1 is Linear ( < 1 makes center more sensitive )
	
	GUI, Add, GroupBox, xs yp+30 w320 h50, Deadzone
	GUI, Add, Edit, xs+10 yp+20 w50 vopk gNumberCheck, %k%
	GUI, Add, Text, x+4 yp+3, Range (0 - 1) Recommended: 0
	
	GUI, Add, GroupBox, xs yp+30 w320 h50, Mouse Check Frequency
	GUI, Add, Edit, xs+10 yp+20 w50 vopfreq Number, %freq%
	GUI, Add, Text, x+4 yp+3, Recommended: 1
	
	GUI, Add, GroupBox, xs yp+30 w320 h50, Deadzone Compensation (stick offset)
	GUI, Add, Edit, xs+10 yp+20 w50 vopminmove gNumberCheck, %minmove%
	GUI, Add, Text, x+4 yp+3, Range (0 - 1)

	GUI, Add, GroupBox, xs yp+30 w320 h50, Mouse Acceleration
	GUI, Add, Edit, xs+10 yp+20 w50 vopacceleration gNumberCheck, %acceleration%
	GUI, Add, Text, x+4 yp+3, (Set to 0 to turn off)
;------------------------------------------------------------------------------------------------------------------------------------------
GUI, Tab, General>Hotkeys
	GUI, Add, GroupBox, x%SX% y%SY% w320 h50 Section, Toggle Controller On/Off
	GUI, Add, Hotkey, xs+10 yp+20 w50 Limit190 vopcontrollerSwitchKey, % StrReplace(controllerSwitchKey, "#")
	GUI, Add, CheckBox, % "x+m yp+3 vopcontrollerSwitchKeyWin Checked" InStr(controllerSwitchKey, "#"), Use Windows key?
	
	GUI, Add, GroupBox, x%SX% yp+40 w320 h50 Section, Quit Application
	GUI, Add, Hotkey, xs+10 yp+20 w50 Limit190 vopexitKey, % StrReplace(exitKey, "#")
	GUI, Add, CheckBox, % "x+m yp+3 vopexitKeyWin Checked" InStr(exitKey, "#"), Use Windows key?
;------------------------------------------------------------------------------------------------------------------------------------------
GUI, Tab, Mouse2Joystick
	GUI, Add, Text, x%SX% y%SY% Section, How are you reading this?!?
;------------------------------------------------------------------------------------------------------------------------------------------
GUI, Tab, Mouse2Joystick>Axes
	GUI, Add, GroupBox, x%SX% y%SY% w320 h40 Section,Invert X-Axis
	GUI, Add, Radio, % "xp+10 yp+20 Group vopinvertedX Checked" . !invertedX, No
	GUI, Add, Radio, % "x+m Checked" . invertedX, Yes
	
	GUI, Add, GroupBox, xs yp+30 w320 h40 Section,Invert Y-Axis
	GUI, Add, Radio, % "xp+10 yp+20 Group vopinvertedY Checked" . !invertedY, No
	GUI, Add, Radio, % "x+m Checked" . invertedY, Yes
;------------------------------------------------------------------------------------------------------------------------------------------
GUI, Tab, Mouse2Joystick>Keys
	GUI, Add, GroupBox, x%SX% y%SY% w340 h80 Section, Active KeyList
	GUI, Add, Edit, xs+10 yp+20 w320 vopjoystickButtonKeyList, %joystickButtonKeyList%
	GUI, Add, Button, xs+10 yp+30 w320 gKeyListHelper, KeyList Helper
	
	GUI, Add, GroupBox, x%SX% yp+40 w340 h50, Saved KeyList Manager
	IniRead,allSavedLists,SavedKeyLists.ini
	allSavedLists := StrReplace(allSavedLists, "`n", "|")
	GUI, Add, ComboBox, xs+10 yp+20 w110 vopSaveListName, %allSavedLists%
	GUI, Add, Button, x+m w60 gLoadSavedList, Load
	GUI, Add, Button, x+m w60 gSaveSavedList, Save
	GUI, Add, Button, x+m w60 gDeleteSavedList, Delete
;------------------------------------------------------------------------------------------------------------------------------------------
GUI, Tab, Keyboard Movement
	GUI, Add, Text, x%SX% y%SY% Section, How are you reading this?!?
;------------------------------------------------------------------------------------------------------------------------------------------
GUI, Tab, Keyboard Movement>Keys
	GUI, Add, GroupBox, x%SX% y%SY% w160 h120 Section, Keyboard Movement
	GUI, Add, Text, xs+10 yp+25 Right w80, Up:
	GUI, Add, Hotkey, x+2 yp-3 w50 Limit190 vopupKey, %upKey%
	GUI, Add, Text, xs+10 yp+25 Right w80, Left:
	GUI, Add, Hotkey, x+2 yp-3 w50 Limit190 vopleftKey, %leftKey%
	GUI, Add, Text, xs+10 yp+25 Right w80, Down:
	GUI, Add, Hotkey, x+2 yp-3 w50 Limit190 vopdownKey, %downKey%
	GUI, Add, Text, xs+10 yp+25 Right w80, Right:
	GUI, Add, Hotkey, x+2 yp-3 w50 Limit190 voprightKey, %rightKey%
	
	GUI, Add, GroupBox, xs w320 h80, Walking
	GUI, Add, Text, xs+10 yp+20 Right w80, Toggle Walk:
	GUI, Add, Hotkey, x+2 yp-3 w50 Limit190 vopwalkToggleKey, %walkToggleKey%
	GUI, Add, Text, x+2 yp+3 Right w20, + :
	GUI, Add, Hotkey, x+2 yp-3 w50 Limit190 vopincreaseWalkKey, %increaseWalkKey%
	GUI, Add, Text, x+2 yp+3 Right w20, - :
	GUI, Add, Hotkey, x+2 yp-3 w50 Limit190 vopdecreaseWalkKey, %decreaseWalkKey%
	GUI, Add, Text, xs+10 yp+35 Right w80, Walking Speed:
	GUI, Add, Slider, x+2 yp-8 w180 Range0-100 TickInterval10 Thick12 vopwalkSpeed gWalkSpeedChange AltSubmit, % walkSpeed*100
	GUI, Font, Bold 
	GUI, Add, Text, x+1 yp+8 w40 vopwalkSpeedTxt, % Round(walkSpeed*100) "%"
	GUI, Font

	GUI, Add, GroupBox, xs w320 h50, Gyro Control
	GUI, Add, Text, xs+10 yp+20 Right w80, Gyro Control:
	GUI, Add, Hotkey, x+2 yp-3 w50 Limit190 vopgyroToggleKey, %gyroToggleKey%
;------------------------------------------------------------------------------------------------------------------------------------------
GUI, Tab, BloodBorne Bonus Buttons [B⁴]
	GUI, Add, GroupBox, x%SX% y%SY% w340 h80 Section, Active KeyList
	GUI, Add, Edit, xs+10 yp+20 w320 vopjoystickButtonKeyListBB, %joystickButtonKeyListBB%
	GUI, Add, Button, xs+10 yp+30 w320 gKeyListHelperBB, Bonus Buttons
	Gui, Add, CheckBox, % "xs+10 yp+40 vopjumpMod gMainSave Checked" . jumpMod, Jump on L3 mod installed?
;------------------------------------------------------------------------------------------------------------------------------------------
GUI, Tab, Extra Settings
	GUI, Add, GroupBox, x%SX% y%SY% w320 h40 Section,BotW Mouse Wheel to Weapon Change
	GUI, Add, Radio, % "xp+10 yp+20 Group vopBotWmouseWheel Checked" . !BotWmouseWheel, No
	GUI, Add, Radio, % "x+m Checked" . BotWmouseWheel, Yes
	
	GUI, Add, GroupBox, xs yp+30 w320 h50,Use ZL Lock Toggle Key
	GUI, Add, Radio, % "xp+10 yp+20 Group voplockZL Checked" . !lockZL, No
	GUI, Add, Radio, % "x+m Checked" . lockZL, Yes
	GUI, Add, Text, x+10 Right w80, ZL Lock Key:
	GUI, Add, Hotkey, x+2 yp-3 w50 Limit190 voplockZLToggleKey, %lockZLToggleKey%
	
	GUI, Add, GroupBox, xs yp+40 w320 h40,Hide Cursor
	GUI, Add, CheckBox, % "xp+10 yp+20 vophideCursor Checked" . hideCursor, Hide cursor when controller toggled on?
	
	GUI, Font, cRed Bold
	GUI, Add, GroupBox, xs yp+30 w320 h65,EXPERIMENTAL Alternate Mouse Detection
	GUI, Font,
	GUI, Add, CheckBox, % "xp+10 yp+20 vopuseAltMouseMethod Checked" . useAltMouseMethod, Use Mouse Delta? (Experimental)
	GUI, Add, Text, xs+10 yp+20 w40 Right, X-Sen:
	GUI, Add, Edit, x+2 yp-3 vopalt_xSen w40, %alt_xSen%
	GUI, Add, Text, x+10 yp+3 w30 Right, Y-Sen:
	GUI, Add, Edit, x+2 yp-3 vopalt_ySen w40, %alt_ySen%
	GUI, Add, Text, x+3 yp+3 w130 Left, Try 260-400? No Idea...

GUI, Add, StatusBar
BuildTree("Main", tree)
Gui, Main: Show
Return	

TreeClick:
	IF (A_GUIEvent = "S") {
		useSection := selectionPath(A_EventInfo)
		IF (useSection = "Keyboard Movement") {
			useSection := "Keyboard Movement>Keys"
			TV_Modify(findByName(useSection), "Select")
		}
		Else IF (useSection = "Mouse2Joystick") {
			useSection := "Mouse2Joystick>Keys"
			TV_Modify(findByName(useSection), "Select")
		}
		SB_SetText(useSection)
		GUIControl, Choose, TabControl, %useSection%
	}
Return

WalkSpeedChange:
	GUIControlGet,tmpSpeed,,opwalkSpeed
	GUIControl,,opwalkSpeedTxt, %tmpSpeed%`%
Return

MainGUIClose:
	GUI, Main:Destroy
Return

mainOk:
	Gui, Main:Hide
mainSave:
	Gui, Main:Submit, NoHide
	Gosub, SubmitAll
	; Get old hotkeys.
	; Disable old hotkeys
	IF (controllerSwitchKey)
		Hotkey,%controllerSwitchKey%,controllerSwitch, off
	IF (exitKey)
		Hotkey,%exitKey%,exitFunc, off
		
	; Joystick buttons
	Hotkey, If, (!toggle && mouse2joystick)
	IF (walkToggleKey)
		HotKey,%walkToggleKey%,toggleHalf, Off
	IF (decreaseWalkKey)
		HotKey,%decreaseWalkKey%,decreaseWalk, Off
	IF (increaseWalkKey)
		HotKey,%increaseWalkKey%,increaseWalk, Off
	IF (lockZLToggleKey AND lockZL)
		HotKey,%lockZLToggleKey%,toggleAimLock, Off
	IF (BotWmouseWheel) {
		Hotkey,WheelUp, overwriteWheelUp, off
		Hotkey,WheelDown, overwriteWheelDown, off
	}
	IF (gyroToggleKey) {
		HotKey,%gyroToggleKey%, GyroControl, off
		HotKey,%gyroToggleKey% Up, GyroControlOff, off
	}
	Hotkey,%upKey%, overwriteUp, off
	Hotkey,%upKey% Up, overwriteUpup, off
	Hotkey,%leftKey%, overwriteLeft, off
	Hotkey,%leftKey% Up, overwriteLeftup, off
	Hotkey,%downKey%, overwriteDown, off
	Hotkey,%downKey% Up, overwriteDownup, off
	Hotkey,%rightKey%, overwriteRight, off
	Hotkey,%rightKey% Up, overwriteRightup, off

	Loop, Parse, joystickButtonKeyListBB, `,
	{
		If !A_LoopField
			continue
		Hotkey, % (KeyListByNumBB[A_Index]), actionBB%A_Index%, off
	}

	Loop, Parse, joystickButtonKeyList, `,
	{
		useButton := A_Index
		Loop, Parse, A_LoopField, |
		{		
			keyName=*%A_LoopField%
			IF (!keyName)
				Continue
			KeyList[keyName] := useButton
			Hotkey,%keyName%, pressJoyButton, off
			Hotkey,%keyName% Up, releaseJoyButton, off
		}
	}
	Hotkey, If

	; Read settings.
	
	IniRead,allSections,settings.ini
	
	Loop,Parse,allSections,`n
	{
		IniRead,pairs,settings.ini,%A_LoopField%
		Loop,Parse,pairs,`n
		{
			StringSplit,keyValue,A_LoopField,=
			%keyValue1%:=keyValue2
		}
	}

	IF (mouse2joystick) {
		GoSub, initCvJoyInterface
		GoSub, mouse2joystickHotkeys
	}
	pmX:=invertedX ? -1:1											; Sign for inverting axis
	pmY:=invertedY ? -1:1

	; Enable new hotkeys
	IF (controllerSwitchKey)
		Hotkey,%controllerSwitchKey%,controllerSwitch, on
	IF (exitKey)
		Hotkey,%exitKey%,exitFunc, on
Return

SubmitAll:
	;FileDelete, settings.ini ; Should I just delete the settings file before writing all settings to it? Guarantees a clean file, but doesn't allow for hidden options...
	; Write General
	IniWrite, % opusevXBox - 1, settings.ini, General, usevXBox
	IniWrite, % opvJoyDevice, settings.ini, General, vJoyDevice
	IniWrite, % opvXBoxDevice, settings.ini, General, vXBoxDevice
	IniWrite, % opgameExe, settings.ini, General, gameExe
	IniWrite, % opautoActivateGame - 1, settings.ini, General, autoActivateGame
	; Write General>Setup
	IniWrite, % opr, settings.ini, General>Setup, r
	IniWrite, % opnnp, settings.ini, General>Setup, nnp
	IniWrite, % opk, settings.ini, General>Setup, k
	IniWrite, % opfreq, settings.ini, General>Setup, freq
	IniWrite, % opminmove, settings.ini, General>Setup, minmove
	IniWrite, % opacceleration, settings.ini, General>Setup, acceleration	
	; Write General>Hotkeys
	IniWrite, % opcontrollerSwitchKeyWin ? "#" . opcontrollerSwitchKey : opcontrollerSwitchKey, settings.ini, General>Hotkeys, controllerSwitchKey
	IniWrite, % opexitKeyWin ? "#" . opexitKey : opexitKey, settings.ini, General>Hotkeys, exitKey
	; Write Mouse2Joystick>Axes
	IniWrite, % opinvertedX - 1, settings.ini, Mouse2Joystick>Axes, invertedX
	IniWrite, % opinvertedY - 1, settings.ini, Mouse2Joystick>Axes, invertedY
	; Write Mouse2Joystick>Keys
	IniWrite, % opjoystickButtonKeyList, settings.ini, Mouse2Joystick>Keys, joystickButtonKeyList
	IniWrite, % opjoystickButtonKeyListBB, settings.ini, Mouse2Joystick>Keys, joystickButtonKeyListBB
	; Write Keyboard Movement>Keys
	IniWrite, % opupKey, settings.ini, Keyboard Movement>Keys, upKey
	IniWrite, % opleftKey, settings.ini, Keyboard Movement>Keys, leftKey
	IniWrite, % opdownKey, settings.ini, Keyboard Movement>Keys, downKey
	IniWrite, % oprightKey, settings.ini, Keyboard Movement>Keys, rightKey
	IniWrite, % opwalkToggleKey, settings.ini, Keyboard Movement>Keys, walkToggleKey
	IniWrite, % opincreaseWalkKey, settings.ini, Keyboard Movement>Keys, increaseWalkKey
	IniWrite, % opdecreaseWalkKey, settings.ini, Keyboard Movement>Keys, decreaseWalkKey
	IniWrite, % Round(opwalkSpeed/100, 2), settings.ini, Keyboard Movement>Keys, walkSpeed
	IniWrite, % opgyroToggleKey, settings.ini, Keyboard Movement>Keys, gyroToggleKey
	; Write Extra Settings
	IF (RegexMatch(opjoystickButtonKeyList, "i)wheel(down|up)")) ; If wheeldown/up is part of the keylist you cannot use the special wheel functions for BotW
		opBotWmouseWheel := 1
	IniWrite, % opBotWmouseWheel - 1, settings.ini, Extra Settings, BotWmouseWheel
	IniWrite, % oplockZL- 1, settings.ini, Extra Settings, lockZL
	IniWrite, % oplockZLToggleKey, settings.ini, Extra Settings, lockZLToggleKey
	IniWrite, % ophideCursor, settings.ini, Extra Settings, hideCursor
	IniWrite, % opuseAltMouseMethod, settings.ini, Extra Settings, useAltMouseMethod
	IniWrite, % opalt_xSen, settings.ini, Extra Settings, alt_xSen
	IniWrite, % opalt_ySen, settings.ini, Extra Settings, alt_ySen
	IniWrite, % opjumpMod, settings.ini, Extra Settings, jumpMod
Return

selectionPath(ID) {
	TV_GetText(name,ID)
	IF (!name)
		Return 0
	parentID := ID
	Loop
	{
		parentID := TV_GetParent(parentID)
		IF (!parentID)
			Break
		parentName=
		TV_GetText(parentName, parentID)
		IF (parentName)
			name := parentName ">" name
	}
	Return name
}

findByName(Name){
	retID := False
	ItemID = 0  ; Causes the loop's first iteration to start the search at the top of the tree.
	Loop
	{
		ItemID := TV_GetNext(ItemID, "Full")  ; Replace "Full" with "Checked" to find all checkmarked items.
		IF (!ItemID)  ; No more items in tree.
			Break
		temp := selectionPath(ItemID)
		IF (temp = Name) {
			retID := ItemID
			Break
		}
	}
	Return retID
}

BuildTree(aGUI, treeString, oParent := 0) {
	Static pParent := []
	Static Call := 0
	Loop, Parse, treeString, `n, `r
	{
		startingString := A_LoopField
		temp := StrSplit(startingString, ",")
		Loop % temp.MaxIndex()
		{
			useString := Trim(temp[A_Index])
			IF (!useString)
				Continue
			Else IF (useString = "||") {
				useIndex := A_Index+1
				While (useIndex < temp.MaxIndex() + 1) {
					useRest .= "," . temp[useIndex]
					useIndex++
				}
				useRest := SubStr(useRest, 2)
				BuildTree(aGUI, useRest, pParent[--Call])
				Break
			}
			Else IF InStr(useString, "|") {
				newTemp := StrSplit(useString, "|")
				pParent[Call++] := oParent
				uParent := TV_Add(newTemp[1], oParent, (oParent = 0 ) ? "Expand" : "")
				useRest := RegExReplace(useString, newTemp[1] . "\|(.*)$", "$1")
				useIndex := A_Index+1
				While (useIndex < temp.MaxIndex() + 1) {
					useRest .= "," . temp[useIndex]
					useIndex++
				}
				BuildTree(aGUI, useRest, uParent)
				Break
			}
			Else
				TV_Add(useString, oParent)
		}
	}
}

NumberCheck(hEdit) {
    static PrevNumber := []

    ControlGet, Pos, CurrentCol,,, ahk_id %hEdit%
    GUIControlGet, NewNumber,, %hEdit%
    StrReplace(NewNumber, ".",, Count)

    If NewNumber ~= "[^\d\.-]|^.+-" Or Count > 1 { ; BAD
        GUIControl,, %hEdit%, % PrevNumber[hEdit]
        SendMessage, 0xB1, % Pos-2, % Pos-2,, ahk_id %hEdit%
    }

    Else ; GOOD
        PrevNumber[hEdit] := NewNumber
}

LoadSavedList:
	GUIControlGet, slName,, opSaveListName
	IniRead, ldKeyList, SavedKeyLists.ini, %slName%, KeyList
	IF (ldKeyList != "ERROR")
		GUIControl,, opjoystickButtonKeyList, %ldKeyList%
Return

SaveSavedList:
	GUIControlGet, slName,, opSaveListName
	IF (!slName) {
		MsgBox, Please enter anything as an identifier
		Return
	}
	GUIControlGet, slList,, opjoystickButtonKeyList
	IniWrite, %slList%, SavedKeyLists.ini, %slName%, KeyList
	IniRead,allSavedLists,SavedKeyLists.ini
	allSavedLists := StrReplace(allSavedLists, "`n", "|")
	GUIControl,, opSaveListName, % "|" . allSavedLists
	GUIControl, Text, opSaveListName, %slName%
Return

DeleteSavedList:
	GUIControlGet, slName,, opSaveListName
	IniDelete, SavedKeyLists.ini, %slName%
	IniRead,allSavedLists,SavedKeyLists.ini
	allSavedLists := StrReplace(allSavedLists, "`n", "|")
	GUIControl,, opSaveListName, % "|" . allSavedLists
Return

; Default settings in case problem reading/writing to file.
setSettingsToDefault:
	pairsDefault=
(
usevXBox=1
vJoyDevice=
vXBoxDevice=1
gameExe=shadPS4.exe
autoActivateGame=1
r=80
nnp=1
k=0
freq=1
minmove=0.37
acceleration=1
controllerSwitchKey=F1
exitKey=#q
invertedX=0
invertedY=0
joystickButtonKeyList=e,Escape,r,f,XButton1,LButton,RButton,MButton,Tab,g,,q,Home,End,Left,Right
joystickButtonKeyListBB=,,,,,,,
upKey=w
leftKey=a
downKey=s
rightKey=d
walkToggleKey=CapsLock
increaseWalkKey=NumpadAdd
decreaseWalkKey=NumpadSub
walkSpeed=0.50
gyroToggleKey=
BotWmouseWheel=0
lockZL=0
lockZLToggleKey=Numpad1
hideCursor=1
useAltMouseMethod=0
alt_xSen=200
alt_ySen=300
)
	Loop,Parse,pairsDefault,`n
	{
		StringSplit,keyValue,A_LoopField,=
		%keyValue1%:=keyValue2
	}
	Goto, readSettingsSkippedDueToError
Return
;------------------------------------------------------------------------------Keyhelper for Bloodborn bonus keys
#IF KeyHelperRunning(setToggle)
#IF
KeyListHelperBB:
Hotkey, IF, KeyHelperRunning(setToggle)
HotKey,~LButton, getControl, On
Hotkey, IF
GUI, Main:Default
GUIControlGet, getKeyList,, opjoystickButtonKeyListBB
KeyListByNumBB := []
Loop, Parse, getKeyList, `,
{
	keyName := A_LoopField
	If !keyName
		continue
	KeyListByNumBB[A_Index] := keyName
}
IF (vXBox) {
	If (jumpMod) {
		textWidth := 85
	} Else {
		textWidth := 155
	}
	numEdits := 9
}
Else {
	textWidth := 50
	numEdits := 18
}
setToggle := False
GUI, Main:+Disabled
GUI, KeyHelper:New, +HWNDKeyHelperHWND -MinimizeBox +OwnerMain
GUI, Margin, 10, 7.5
GUI, Font,, Lucida Sans Typewriter ; Courier New
GUI, Add, Text, W0 H0 vLoseFocus, Hidden
GUI, Add, Text, W%textWidth%+20 R1 Right Section, % jumpMod ? "-" : "Dodge/Backstep (prevent jump)"
GUI, Add, Edit, W80 R1 x+m yp-3 Center ReadOnly -TabStop, % KeyListByNumBB[1]
GUI, Add, Button, xp+85 yp-1 w19 gClearOne v1, X
GUI, Add, Text, W%textWidth% xs R1 Right, % jumpMod ? "-" : "Dodge (prevent jump)"
GUI, Add, Edit, W80 R1 x+m yp-3 Center ReadOnly -TabStop, % KeyListByNumBB[2]
GUI, Add, Button, xp+85 yp-1 w19 gClearOne v2, X
GUI, Add, Text, W%textWidth% xs R1 Right, % jumpMod ? "Dodge/Backstep" : "Dodge/Backstep (allow jump)"
GUI, Add, Edit, W80 R1 x+m yp-3 Center ReadOnly -TabStop, % KeyListByNumBB[3]
GUI, Add, Button, xp+85 yp-1 w19 gClearOne v3, X
GUI, Add, Text, W%textWidth% xs R1 Right, % jumpMod ? "Dodge" : "Dodge (allow jump)"
GUI, Add, Edit, W80 R1 x+m yp-3 Center ReadOnly -TabStop, % KeyListByNumBB[4]
GUI, Add, Button, xp+85 yp-1 w19 gClearOne v4, X
GUI, Add, Text, W+80 ys R1 Right Section, Backstep
GUI, Add, Edit, W80 R1 x+m yp-3 Center ReadOnly -TabStop, % KeyListByNumBB[5]
GUI, Add, Button, xp+85 yp-1 w19 gClearOne v5, X
GUI, Add, Text, W+80 xs R1 Right, Sprint
GUI, Add, Edit, W80 R1 x+m yp-3 Center ReadOnly -TabStop, % KeyListByNumBB[6]
GUI, Add, Button, xp+85 yp-1 w19 gClearOne v6, X
GUI, Add, Text, W+80 xs R1 Right, Jump
GUI, Add, Edit, W80 R1 x+m yp-3 Center ReadOnly -TabStop, % KeyListByNumBB[7]
GUI, Add, Button, xp+85 yp-1 w19 gClearOne v7, X
GUI, Add, Text, W+80 xs R1 Right, Jump Attack
GUI, Add, Edit, W80 R1 x+m yp-3 Center ReadOnly -TabStop, % KeyListByNumBB[8]
GUI, Add, Button, xp+85 yp-1 w19 gClearOne v8, X
GUI, Add, Text, W+80 xs R1 Right, Save&&Quit
GUI, Add, Edit, W80 R1 x+m yp-3 Center ReadOnly -TabStop, % KeyListByNumBB[9]
GUI, Add, Button, xp+85 yp-1 w19 gClearOne v9, X
GUI, Add, Text, w0 xs R1 Right, Dummy

GUI, Add, Button, xp-150 yp-20 w170 gClearButton Section, Clear All
GUI, Add, Button, xs w80 gSaveButtonBB, Save
GUI, Add, Button, x+m w80 gCancelButton, Cancel
GUI, Add, Text, w0 yp+15 R1 Right, Dummy

;GUI, Add, Button, xp-150 yp-20 w80 gSaveButtonBB Section, Save
;GUI, Add, Button, x+m w80 gCancelButton, Cancel
;GUI, Add, Button, xs w170 gClearButton, Clear All
;GUI, Add, Text, w0 yp+15 R1 Right, Dummy

GUI, Show,, KeyList Helper
GuiControl, Focus, LoseFocus
Return
;------------------------------------------------------------------------------
#IF KeyHelperRunning(setToggle)
#IF
KeyListHelper:
Hotkey, IF, KeyHelperRunning(setToggle)
HotKey,~LButton, getControl, On
Hotkey, IF
GUI, Main:Default
GUIControlGet, getKeyList,, opjoystickButtonKeyList
KeyListByNum := []
Loop, Parse, getKeyList, `,
{
	keyName := A_LoopField
	If !keyName
		continue
	KeyListByNum[A_Index] := keyName
}
IF (vXBox) {
	textWidth := 100
	numEdits := 16
}
Else {
	textWidth := 50
	numEdits := 18
}
setToggle := False
GUI, Main:+Disabled
GUI, KeyHelper:New, +HWNDKeyHelperHWND -MinimizeBox +OwnerMain
GUI, Margin, 10, 7.5
GUI, Font,, Lucida Sans Typewriter ; Courier New
GUI, Add, Text, W0 H0 vLoseFocus, Hidden
GUI, Add, Text, W%textWidth% R1 Right Section, % vXBox ? Format("{1:-9.9s}{2:4.4s}","( A - ✕ )","A") : "A"
GUI, Add, Edit, W80 R1 x+m yp-3 Center ReadOnly -TabStop, % KeyListByNum[1]
GUI, Add, Button, xp+85 yp-1 w19 gClearOne v1, X
GUI, Add, Text, W%textWidth% xs R1 Right, % vXBox ? Format("{1:-9.9s}{2:4.4s}","( B - ○ )","B") : "B"
GUI, Add, Edit, W80 R1 x+m yp-3 Center ReadOnly -TabStop, % KeyListByNum[2]
GUI, Add, Button, xp+85 yp-1 w19 gClearOne v2, X
GUI, Add, Text, W%textWidth% xs R1 Right, % vXBox ? Format("{1:-9.9s}{2:4.4s}","( X - □ )","X") : "X"
GUI, Add, Edit, W80 R1 x+m yp-3 Center ReadOnly -TabStop, % KeyListByNum[3]
GUI, Add, Button, xp+85 yp-1 w19 gClearOne v3, X
GUI, Add, Text, W%textWidth% xs R1 Right, % vXBox ? Format("{1:-9.9s}{2:4.4s}","( Y - △ )","Y") : "Y"
GUI, Add, Edit, W80 R1 x+m yp-3 Center ReadOnly -TabStop, % KeyListByNum[4]
GUI, Add, Button, xp+85 yp-1 w19 gClearOne v4, X
GUI, Add, Text, W%textWidth% xs R1 Right, % vXBox ? Format("{1:-9.9s}{2:4.4s}","(LB - L1)","L") : "L"
GUI, Add, Edit, W80 R1 x+m yp-3 Center ReadOnly -TabStop, % KeyListByNum[5]
GUI, Add, Button, xp+85 yp-1 w19 gClearOne v5, X
GUI, Add, Text, W%textWidth% xs R1 Right, % vXBox ? Format("{1:-9.9s}{2:4.4s}","(RB - R1)","R") : "R"
GUI, Add, Edit, W80 R1 x+m yp-3 Center ReadOnly -TabStop, % KeyListByNum[6]
GUI, Add, Button, xp+85 yp-1 w19 gClearOne v6, X
GUI, Add, Text, W%textWidth% xs R1 Right, % vXBox ? Format("{1:-9.9s}{2:4.4s}","(LT - L2)","ZL") : "ZL"
GUI, Add, Edit, W80 R1 x+m yp-3 Center ReadOnly -TabStop, % KeyListByNum[7]
GUI, Add, Button, xp+85 yp-1 w19 gClearOne v7, X
GUI, Add, Text, W%textWidth% xs R1 Right, % vXBox ? Format("{1:-9.9s}{2:4.4s}","(RT - R2)","ZR") : "ZR"
GUI, Add, Edit, W80 R1 x+m yp-3 Center ReadOnly -TabStop, % KeyListByNum[8]
GUI, Add, Button, xp+85 yp-1 w19 gClearOne v8, X
GUI, Add, Text, W%textWidth% xs R1 Right, % vXBox ? Format("{1:-9.9s}{2:4.4s}","( Start )","+") : "+"
GUI, Add, Edit, W80 R1 x+m yp-3 Center ReadOnly -TabStop, % KeyListByNum[9]
GUI, Add, Button, xp+85 yp-1 w19 gClearOne v9, X
GUI, Add, Text, W%textWidth% xs R1 Right, % vXBox ? Format("{1:-9.9s}{2:4.4s}","( Back  )","-") : "-"
GUI, Add, Edit, W80 R1 x+m yp-3 Center ReadOnly -TabStop, % KeyListByNum[10]
GUI, Add, Button, xp+85 yp-1 w19 gClearOne v10, X
GUI, Add, Text, w45 xp+20 ys R1 Right Section, L-Click
GUI, Add, Edit, W80 R1 x+m yp-3 Center ReadOnly -TabStop, % KeyListByNum[11]
GUI, Add, Button, xp+85 yp-1 w19 gClearOne v11, X
GUI, Add, Text, w45 xp+20 ys R1 Right Section, R-Click
GUI, Add, Edit, W80 R1 x+m yp-3 Center ReadOnly -TabStop, % KeyListByNum[12]
GUI, Add, Button, xp+85 yp-1 w19 gClearOne v12, X
GUI, Add, Text, w45 xp+20 ys R1 Right Section, D-Up
GUI, Add, Edit, W80 R1 x+m yp-3 Center ReadOnly -TabStop, % KeyListByNum[13]
GUI, Add, Button, xp+85 yp-1 w19 gClearOne v13, X
GUI, Add, Text, w80 xs-35 R1 Right, D-Down
GUI, Add, Edit, W80 R1 x+m yp-3 Center ReadOnly -TabStop, % KeyListByNum[14]
GUI, Add, Button, xp+85 yp-1 w19 gClearOne v14, X
GUI, Add, Text, w80 xs-35 R1 Right, D-Left
GUI, Add, Edit, W80 R1 x+m yp-3 Center ReadOnly -TabStop, % KeyListByNum[15]
GUI, Add, Button, xp+85 yp-1 w19 gClearOne v15, X
GUI, Add, Text, w80 xs-35 R1 Right, D-Right
GUI, Add, Edit, W80 R1 x+m yp-3 Center ReadOnly -TabStop, % KeyListByNum[16]
GUI, Add, Button, xp+85 yp-1 w19 gClearOne v16, X
GUI, Add, Text, w0 xs-35 R1 Right, Dummy
IF(!vXBox) {
	GUI, Add, Text, w80 xs R1 Right, Blow-Mic
	GUI, Add, Edit, W80 R1 x+m yp-3 Center ReadOnly -TabStop, % KeyListByNum[17]
	GUI, Add, Text, w80 xs R1 Right, Show-Screen
	GUI, Add, Edit, W80 R1 x+m yp-3 Center ReadOnly -TabStop, % KeyListByNum[18]
}
GUI, Add, Text, w0 xm+230 R1 Right, Dummy
GUI, Add, Button, xp yp-30 w80 gSaveButton Section, Save
GUI, Add, Button, x+m w80 gCancelButton, Cancel
GUI, Add, Button, xs yp-30 w170 gAutoLoop, Auto Cycle
GUI, Add, Button, xs yp-30 w170 gClearButton, Clear All

GUI, Show,, KeyList Helper
GuiControl, Focus, LoseFocus
Return

ClearButton:
	GUI, KeyHelper:Default
	Loop %numEdits%
		GUIControl,,Edit%A_Index%,
Return

ClearOne:
	GUI, KeyHelper:Default
	GUIControl,,Edit%A_GuiControl%,
Return

CancelButton:
KeyHelperGUIClose:
	IF (setToggle)
		Return
	Hotkey, IF, KeyHelperRunning(setToggle)
	HotKey,~LButton, getControl, Off
	Hotkey, IF
	GUI, Main:-Disabled
	GUI, KeyHelper:Destroy
Return

SaveButton:
	tempList := ""
	Loop %numEdits%
	{
	GUIControlGet, tempKey,,Edit%A_Index%
		tempList .= tempKey . ","
	}
	tempList := SubStr(tempList,1, StrLen(tempList)-1)
GUI, Main:Default
GUIControl,, opjoystickButtonKeyList, %tempList%
GoSub, KeyHelperGUIClose
Return

SaveButtonBB:	;Save button for Bloodborne key list
	tempList := ""
	Loop %numEdits%
	{
	GUIControlGet, tempKey,,Edit%A_Index%
		tempList .= tempKey . ","
	}
	tempList := SubStr(tempList,1, StrLen(tempList)-1)
GUI, Main:Default
GUIControl,, opjoystickButtonKeyListBB, %tempList%
GoSub, KeyHelperGUIClose
Return

getControl:
	GUI, KeyHelper:Default
	KeyWait, LButton

	setToggle := True
	MouseGetPos,,, mouseWin, useControl, 1
	IF (InStr(useControl, "Edit") AND mouseWin = KeyHelperHWND)
		GetKey()
	setToggle := False

	clearFocus:
	GuiControl, Focus, LoseFocus
Return

AutoLoop:
	GUI, KeyHelper:Default
	Loop 4
		GUIControl, +Disabled, Button%A_Index%
	setToggle := True
	Loop %numEdits% {
		useControl := "Edit" . A_Index
		GetKey()
	}
	setToggle := False
	Loop 4
		GUIControl, -Disabled, Button%A_Index%
	GoSub, clearFocus
	MsgBox, Done
Return

KeyHelperRunning(setTog){
	Return (WinActive("KeyList Helper") AND !setTog)
}

GetKey() {
	Global
	GoSub, TurnOn
	MousePressed := False
	GUIControl, -E0x200, %useControl%
	GuiControl,Text, %useControl%, Waiting
	ih.Start()
	ErrorLevel := ih.Wait()
	singleKey := ih.EndKey
	GoSub, TurnOff
	
	IF (MousePressed)
		singleKey := MousePressed
	Else IF (singleKey = "," OR singleKey = "=") ; Comma and equal sign Don't work
		singleKey := ""
	
	singleKey := RegexReplace(singleKey, "Control", "Ctrl")
		
	GuiControl, Text, %useControl%, %singleKey%
	GUIControl, +E0x200, %useControl%
	Loop %numEdits%
	{
		GUIControlGet, tempKey,,Edit%A_Index%
		IF (tempKey = singleKey AND useControl != "Edit" . A_Index)
			GuiControl, Text, Edit%A_Index%,
	}
Return singleKey
}

WM_LBUTTONDOWN() {
	Global useControl, MousePressed
	Send, {Esc}
	MousePressed := "LButton"
	Return 0
}

WM_RBUTTONDOWN() {
	Global useControl, MousePressed
	Send, {Esc}
	MousePressed := "RButton"
	Return 0
}

WM_MBUTTONDOWN() {
	Global useControl, MousePressed
	Send, {Esc}
	MousePressed := "MButton"
	Return 0
}

WM_XBUTTONDOWN(w) {
	Global useControl, MousePressed
	Send, {Esc}
	SetFormat, IntegerFast, Hex
	IF ((w & 0xFF) = 0x20)
		MousePressed := "XButton1"
	Else IF((w & 0xFF) = 0x40)
		MousePressed := "XButton2"
	Return 0
}

WM_MOUSEHWHEEL(w) {
	Global useControl, MousePressed
	Send, {Esc}
	SetFormat, IntegerFast, Hex
	IF ((w & 0xFF0000) = 0x780000)
		MousePressed := "WheelRight"
	Else IF((w & 0xFF0000) = 0x880000)
		MousePressed := "WheelLeft"
	Return 0
}

WM_MOUSEWHEEL(w) {
	Global useControl, MousePressed
	Send, {Esc}
	SetFormat, IntegerFast, Hex
	MousePressed := "" . w + 0x0
	IF ((w & 0xFF0000) = 0x780000)
		MousePressed := "WheelUp"
	Else IF((w & 0xFF0000) = 0x880000)
		MousePressed := "WheelDown"
	Return 0
}

TurnOn:
OnMessage(0x0201, "WM_LBUTTONDOWN")
OnMessage(0x0204, "WM_RBUTTONDOWN")
OnMessage(0x0207, "WM_MBUTTONDOWN")
OnMessage(0x020B, "WM_XBUTTONDOWN")
OnMessage(0x020E, "WM_MOUSEHWHEEL")
GUIControlGet, TempBotWmouseWheel,Main:,opBotWmouseWheel
IF (TempBotWmouseWheel) ; If this control is a 1, then BotW mousewheel is off and mouse wheel can be used as a key.
	OnMessage(0x020A, "WM_MOUSEWHEEL")
Return

TurnOff:
OnMessage(0x0201, "")
OnMessage(0x0204, "")
OnMessage(0x0207, "")
OnMessage(0x020B, "")
OnMessage(0x020E, "")
OnMessage(0x020A, "")
Return

;-------------------------------------------------------------------------------
show_Mouse(bShow := True) { ; show/hide the mouse cursor
;-------------------------------------------------------------------------------
	; https://autohotkey.com/boards/viewtopic.php?p=173707#p173707
    ; WINAPI: SystemParametersInfo, CreateCursor, CopyImage, SetSystemCursor
    ; https://msdn.microsoft.com/en-us/library/windows/desktop/ms724947.aspx
    ; https://msdn.microsoft.com/en-us/library/windows/desktop/ms648385.aspx
    ; https://msdn.microsoft.com/en-us/library/windows/desktop/ms648031.aspx
    ; https://msdn.microsoft.com/en-us/library/windows/desktop/ms648395.aspx
    ;---------------------------------------------------------------------------
    static BlankCursor
    static CursorList := "32512, 32513, 32514, 32515, 32516, 32640, 32641"
        . ",32642, 32643, 32644, 32645, 32646, 32648, 32649, 32650, 32651"
    local ANDmask, XORmask, CursorHandle

    IF (bShow) ; shortcut for showing the mouse cursor
        Return, DllCall("SystemParametersInfo"
            , "UInt", 0x57              ; UINT  uiAction    (SPI_SETCURSORS)
            , "UInt", 0                 ; UINT  uiParam
            , "Ptr",  0                 ; PVOID pvParam
            , "UInt", 0)                ; UINT  fWinIni

    IF (!BlankCursor) { ; create BlankCursor only once
        VarSetCapacity(ANDmask, 32 * 4, 0xFF)
        VarSetCapacity(XORmask, 32 * 4, 0x00)
        BlankCursor := DllCall("CreateCursor"
            , "Ptr", 0                  ; HINSTANCE  hInst
            , "Int", 0                  ; int        xHotSpot
            , "Int", 0                  ; int        yHotSpot
            , "Int", 32                 ; int        nWidth
            , "Int", 32                 ; int        nHeight
            , "Ptr", &ANDmask           ; const VOID *pvANDPlane
            , "Ptr", &XORmask)          ; const VOID *pvXORPlane
    }

    ; set all system cursors to blank, each needs a new copy
    Loop, Parse, CursorList, `,, %A_Space%
    {
        CursorHandle := DllCall("CopyImage"
            , "Ptr", BlankCursor        ; HANDLE hImage
            , "UInt", 2                 ; UINT   uType      (IMAGE_CURSOR)
            , "Int",  0                 ; int    cxDesired
            , "Int",  0                 ; int    cyDesired
            , "UInt", 0)                ; UINT   fuFlags
        DllCall("SetSystemCursor"
            , "Ptr", CursorHandle       ; HCURSOR hcur
            , "UInt",  A_Loopfield)     ; DWORD   id
    }
}

LockMouseToWindow(llwindowname="") {
  IF (!llwindowname) {
	DllCall("ClipCursor", "UInt", 0)
	Return False
  }
  WinGetPos, llX, llY, llWidth, llHeight, %llwindowname%
  VarSetCapacity(llrectA, 16)
  IF (llWidth AND llHeight) {
	NumPut(llX+10,&llrectA+0),NumPut(llY+54,&llrectA+4),NumPut(llWidth-10 + llX,&llrectA+8),NumPut(llHeight-10 + llY,&llrectA+12)
	DllCall("ClipCursor", "UInt", &llrectA)
	Return True
  }
}

installBus:
	InstallUninstallScpVBus(True)
Return
uninstallBus:
	InstallUninstallScpVBus(False)
Return

InstallUninstallScpVBus(state:="ERROR") {
	IF (state == "ERROR")
		Return
	IF (state){
		RunWait, *Runas devcon.exe install ScpVBus.inf root\ScpVBus, % A_ScriptDir "\ScpVBus", UseErrorLevel Hide
		MsgBox,, Done Installing, reloading the script., 1
	} Else {
		RunWait, *Runas devcon.exe remove root\ScpVBus, % A_ScriptDir "\ScpVBus", UseErrorLevel Hide
		;IniWrite,0, settings.ini, General, usevXBox ; Turn off the setting for future runs as well.
		MsgBox,, Done Un-Installing, reloading the script., 1
	}
	IF (ErrorLevel == "ERROR")
		return 0
	Reload
}

; Gets called when mouse moves
; x and y are DELTA moves (Amount moved since last message), NOT coordinates.
MouseEvent(MouseID, x := 0, y := 0){
	Global alt_xSen, alt_ySen
	Static useX, useY, xZero, yZero
	intv := 1
	
	IF (MouseID == "RESET") {
		useX := useY := 0
		SetStick(0,0)
		Return
	}
	
	IF ((x < 0 AND useX > 0) OR (x > 0 AND useX < 0))
		useX := 0
	IF ((y < 0 AND useY > 0) OR (y > 0 AND useY < 0))
		useY := 0
	IF (x AND y)
		intv := 4

	IF (!x)
		xZero++
	IF (xZero > 2) {
		useX := 0
		xZero := 0
	}
	IF (x > 0)
		useX += intv 
	Else
		useX -= intv 

	IF (!y)
		yZero++
	IF (yZero > 2) {
		useY := 0
		yZero := 0
	}
	IF (y > 0)
		useY += intv 
	Else
		useY -= intv 
		
	IF (abs(useX)>alt_xSen)
		useX := useX/abs(useX) * alt_xSen
	Else IF (abs(x) AND abs(useX) < alt_xSen/6)
		useX := useX/abs(useX) * alt_xSen/6

	IF (abs(useY)>alt_ySen)
		useY := useY/abs(useY) * alt_ySen
	Else IF (abs(y) AND abs(useY) < alt_ySen/6)
		useY := useY/abs(useY) * alt_ySen/6
	SetStick(useX/alt_xSen,-useY/alt_ySen)
	Return
}

MouseEvent_OFF(MouseID, x := 0, y := 0){
	Global alt_xSen, alt_ySen
	Static useX, useY
	IF (MouseID == "RESET") {
		useX := useY := 0
		SetStick(0,0)
		Return
	}
	
	IF ((x < 0 AND useX > 0) OR (x > 0 AND useX < 0))
		useX := 0
	IF ((y < 0 AND useY > 0) OR (y > 0 AND useY < 0))
		useY := 0

	IF (!x)
		useX /= 2
	Else
		useX += x
	
	IF (abs(useX)>alt_xSen)
		useX := x/abs(x) * alt_xSen

	IF (!y)
		useY /= 2
	Else 
		useY += y

	IF (abs(useY)>alt_ySen)
		useY := y/abs(y) * alt_ySen
		
	SetStick(useX/alt_xSen,-useY/alt_ySen)
	Return
}
