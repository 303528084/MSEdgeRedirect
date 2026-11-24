#include-once

; 简体中文本地化增强（MSEdgeRedirect zh-CN 分支）
; 本文件为本分支新增，上游不存在，rebase 时不会产生冲突。
; 设计原则：所有译文集中在 Assets\Langs\0804.lang，上游 .au3 只保留英文原文与 _L() 钩子。

#include <FileConstants.au3>
#include <WinAPISysWin.au3>
; AutoIt 3.3.18 起 _WinAPI_AddFontMemResourceEx 等已移入 WinAPIGdi.au3，
; 上游 ResourcesEx.au3 依赖这些函数；为保持 UDF 原样，在本分支文件中补充 include。
#include <WinAPIGdi.au3>

Global $g_aZhKey[1]
Global $g_aZhVal[1]
Global $g_iZhCount = 0
Global $g_bZhLoaded = False

Global $g_aZhCacheKey[1]
Global $g_aZhCacheVal[1]
Global $g_iZhCache = 0

Global $g_sZhCode = ""

; 当前 MUI 语言代码（四位十六进制，如 0804）
Func _LangCode()
	If $g_sZhCode <> "" Then Return $g_sZhCode
	Local $vMUI = $aMUI[1]
	If IsNumber($vMUI) Then
		$g_sZhCode = Hex($vMUI, 4)
	Else
		Local $sCode = StringLower(StringStripWS(String($vMUI), 3))
		If StringLeft($sCode, 2) = "0x" Then $sCode = StringTrimLeft($sCode, 2)
		While StringLen($sCode) < 4
			$sCode = "0" & $sCode
		WEnd
		$g_sZhCode = $sCode
	EndIf
	Return $g_sZhCode
EndFunc   ;==>_LangCode

Func _IsZhCN()
	Return _LangCode() = "0804"
EndFunc   ;==>_IsZhCN

; 译一句：命中返回中文，未命中返回原文（英文）
Func _L($sText)
	If Not _IsZhCN() Then Return $sText
	If Not $g_bZhLoaded Then _LoadLang()
	If $g_iZhCount = 0 Then Return $sText

	Local $sKey = StringReplace(String($sText), @CRLF, "\n")
	Local $iLoop

	For $iLoop = 0 To $g_iZhCache - 1
		If $g_aZhCacheKey[$iLoop] = $sKey Then Return $g_aZhCacheVal[$iLoop]
	Next

	Local $sReturn = $sText
	For $iLoop = 0 To $g_iZhCount - 1
		If $g_aZhKey[$iLoop] = $sKey Then
			$sReturn = StringReplace($g_aZhVal[$iLoop], "\n", @CRLF)
			ExitLoop
		EndIf
	Next

	If $g_iZhCache >= UBound($g_aZhCacheKey) Then
		ReDim $g_aZhCacheKey[$g_iZhCache * 2]
		ReDim $g_aZhCacheVal[$g_iZhCache * 2]
	EndIf
	$g_aZhCacheKey[$g_iZhCache] = $sKey
	$g_aZhCacheVal[$g_iZhCache] = $sReturn
	$g_iZhCache += 1

	Return $sReturn
EndFunc   ;==>_L

; 标题与正文一并翻译的消息框（源码里保留英文原文，减少 rebase 冲突面）
Func _MsgBox($iFlag, $sTitle, $sText, $iTimeout = 0)
	Return MsgBox($iFlag, _L($sTitle), _L($sText), $iTimeout)
EndFunc   ;==>_MsgBox

; 一次性读入 0804.lang 的 [Strings] 段
Func _LoadLang()
	If $g_bZhLoaded Then Return
	$g_bZhLoaded = True

	Local $sFile = _LangFile()
	If $sFile = "" Then Return

	; 编码自适应：按文件自身 BOM 读取，检测失败时退回 UTF-16
	Local $iEnc = FileGetEncoding($sFile)
	If $iEnc <= 0 Then $iEnc = $FO_UNICODE

	Local $hFile = FileOpen($sFile, $FO_READ + $iEnc)
	If $hFile = -1 Then Return

	Local $aKey[64]
	Local $aVal[64]
	Local $iCount = 0
	Local $bStrings = False
	Local $sLine
	Local $iPos

	While True
		$sLine = FileReadLine($hFile)
		If @error Then ExitLoop
		If StringLeft($sLine, 1) = ChrW(0xFEFF) Then $sLine = StringMid($sLine, 2)
		$sLine = StringStripWS($sLine, 1 + 2)
		If $sLine = "" Then ContinueLoop
		If StringLeft($sLine, 1) = ";" Then ContinueLoop
		If StringLeft($sLine, 1) = "[" And StringInStr($sLine, "=") = 0 Then
			$bStrings = (StringLower(StringStripWS($sLine, 3)) = "[strings]")
			ContinueLoop
		EndIf
		If Not $bStrings Then ContinueLoop
		$iPos = StringInStr($sLine, "=")
		If $iPos < 2 Then ContinueLoop
		If $iCount >= UBound($aKey) Then
			ReDim $aKey[UBound($aKey) * 2]
			ReDim $aVal[UBound($aVal) * 2]
		EndIf
		$aKey[$iCount] = StringStripWS(StringLeft($sLine, $iPos - 1), 2)
		$aVal[$iCount] = StringStripWS(StringMid($sLine, $iPos + 1), 2)
		$iCount += 1
	WEnd

	FileClose($hFile)
	If $iCount = 0 Then Return

	ReDim $aKey[$iCount]
	ReDim $aVal[$iCount]
	$g_aZhKey = $aKey
	$g_aZhVal = $aVal
	$g_iZhCount = $iCount
EndFunc   ;==>_LoadLang

Func _LangFile()
	Local $sCode = _LangCode()
	Local $aDir[4] = [ _
		@LocalAppDataDir & "\MSEdgeRedirect\Langs", _
		@ScriptDir & "\Langs", _
		@ScriptDir & "\MSEdgeRedirect\Langs", _
		@ScriptDir & "\Assets\Langs"]
	For $iLoop = 0 To UBound($aDir) - 1
		Local $sPath = $aDir[$iLoop] & "\" & $sCode & ".lang"
		If FileExists($sPath) Then Return $sPath
	Next
	Return ""
EndFunc   ;==>_LangFile

; 运行时扫描窗口内所有控件，把英文文本替换为中文
Func _LocalizeGUI($hGUI)
	If Not _IsZhCN() Then Return
	_LoadLang()

	Local $sTitle = WinGetTitle($hGUI)
	If $sTitle <> "" Then
		Local $sNewTitle = _L($sTitle)
		If $sNewTitle = $sTitle Then
			; 形如 "<名称> <版本> Setup/Settings/Update/Troubleshooter" 的窗口标题，后缀单独翻译
			Local $aTitleSuffix[4] = ["Setup", "Settings", "Update", "Troubleshooter"]
			Local $aTitleLocal[4]
			$aTitleLocal[0] = _L("Setup")
			$aTitleLocal[1] = _L("Settings")
			$aTitleLocal[2] = _L("Update")
			$aTitleLocal[3] = _L("Troubleshooter")
			For $iLoop = 0 To UBound($aTitleSuffix) - 1
				Local $sSuffix = " " & $aTitleSuffix[$iLoop]
				If StringRight($sTitle, StringLen($sSuffix)) = $sSuffix Then
					$sNewTitle = StringLeft($sTitle, StringLen($sTitle) - StringLen($sSuffix)) & " " & $aTitleLocal[$iLoop]
					ExitLoop
				EndIf
			Next
		EndIf
		If $sNewTitle <> $sTitle Then WinSetTitle($hGUI, "", $sNewTitle)
	EndIf

	Local $aCtrl = _WinAPI_EnumChildWindows($hGUI, False)
	If Not IsArray($aCtrl) Then Return

	For $iLoop = 1 To $aCtrl[0][0]
		Local $hCtrl = $aCtrl[$iLoop][0]
		Local $sClass = $aCtrl[$iLoop][1]
		Local $aSub = _WinAPI_EnumChildWindows($hCtrl, False)
		Local $bHasChild = IsArray($aSub) And $aSub[0][0] > 0
		If $bHasChild Then
			; 安装向导的子页面，递归处理页面内控件
			_ZhLocalizeChild($hCtrl)
		ElseIf $sClass <> "Edit" And $sClass <> "ComboBox" And $sClass <> "ComboBoxEx32" Then
			; 下拉框、编辑框的文本是数据（值/许可协议原文），保持原样
			Local $sText = _ZhGetWindowText($hCtrl)
			If $sText <> "" Then
				Local $sLocal = _LText($sText)
				If $sLocal <> $sText Then DllCall("user32.dll", "bool", "SetWindowTextW", "hwnd", $hCtrl, "wstr", $sLocal)
			EndIf
		EndIf
	Next
EndFunc   ;==>_LocalizeGUI

; 安装向导的子页面是 MDI 子窗口，主窗口枚举不到其控件，需要按页面句柄单独处理
Func _LocalizePage($hPage)
	If Not _IsZhCN() Then Return
	If Not $g_bZhLoaded Then _LoadLang()
	_ZhLocalizeChild($hPage)
EndFunc   ;==>_LocalizePage

; 递归处理容器窗口（子页面）内的控件
Func _ZhLocalizeChild($hParent)
	Local $aCtrl = _WinAPI_EnumChildWindows($hParent, False)
	If Not IsArray($aCtrl) Then Return
	For $iLoop = 1 To $aCtrl[0][0]
		Local $hCtrl = $aCtrl[$iLoop][0]
		Local $sClass = $aCtrl[$iLoop][1]
		Local $aSub = _WinAPI_EnumChildWindows($hCtrl, False)
		If IsArray($aSub) And $aSub[0][0] > 0 Then
			_ZhLocalizeChild($hCtrl)
		ElseIf $sClass <> "Edit" And $sClass <> "ComboBox" And $sClass <> "ComboBoxEx32" Then
			Local $sText = _ZhGetWindowText($hCtrl)
			If $sText <> "" Then
				Local $sLocal = _LText($sText)
				If $sLocal <> $sText Then DllCall("user32.dll", "bool", "SetWindowTextW", "hwnd", $hCtrl, "wstr", $sLocal)
			EndIf
		EndIf
	Next
EndFunc   ;==>_ZhLocalizeChild

; 带动态内容的文本用固定部分拼接翻译，避免因版本号变化导致 key 失配
Func _LText($sText)
	Local $sReturn = _L($sText)
	If $sReturn <> $sText Then Return $sReturn

	If StringRegExp($sText, "^(Install MSEdgeRedirect) [\d\.x]+$") Then
		Return _L("Install") & " MSEdgeRedirect " & StringRegExpReplace($sText, "^Install MSEdgeRedirect ", "")
	EndIf
	If StringRegExp($sText, "^MSEdgeRedirect [\d\.x]+ Update$") Then
		Return "MSEdgeRedirect " & StringRegExpReplace($sText, "^MSEdgeRedirect ([\d\.x]+) Update$", "$1") & " " & _L("Update")
	EndIf

	Return $sText
EndFunc   ;==>_LText

Func _ZhGetWindowText($hCtrl)
	Local $tText = DllStructCreate("wchar[512]")
	DllCall("user32.dll", "int", "GetWindowTextW", "hwnd", $hCtrl, "struct*", $tText, "int", 512)
	Return DllStructGetData($tText, 1)
EndFunc   ;==>_ZhGetWindowText
