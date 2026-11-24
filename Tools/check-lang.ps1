# 语言包一致性检查（MSEdgeRedirect zh-CN 分支）
# 用法：powershell -ExecutionPolicy Bypass -File Tools\check-lang.ps1
# 输出：缺失翻译（源码有、语言包没有）与失效翻译（语言包有、源码已改或已删）

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$langPath = Join-Path $root 'Assets\Langs\0804.lang'

if (-not (Test-Path -LiteralPath $langPath)) {
	Write-Host "找不到语言包：$langPath" -ForegroundColor Red
	exit 1
}

# ---------- 读取语言包 key ----------
$langKeys = New-Object System.Collections.Generic.List[string]
$inStrings = $false
foreach ($line in (Get-Content -LiteralPath $langPath -Encoding Unicode)) {
	$s = $line.Trim()
	if ($s -eq '' -or $s.StartsWith(';')) { continue }
	if ($s.StartsWith('[') -and -not $s.Contains('=')) {
		$inStrings = ($s.ToLower() -eq '[strings]')
		continue
	}
	if (-not $inStrings) { continue }
	$i = $s.IndexOf('=')
	if ($i -lt 1) { continue }
	$langKeys.Add($s.Substring(0, $i).TrimEnd())
}
$langSet = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::Ordinal)
foreach ($k in $langKeys) { [void]$langSet.Add($k) }

# ---------- 解析 AutoIt 调用 ----------
function Split-Args {
	param([string]$Inner)
	$list = New-Object System.Collections.Generic.List[string]
	$depth = 0
	$inStr = $false
	$cur = ''
	for ($i = 0; $i -lt $Inner.Length; $i++) {
		$ch = $Inner[$i]
		if ($inStr) {
			$cur += $ch
			if ($ch -eq '"') {
				if ($i + 1 -lt $Inner.Length -and $Inner[$i + 1] -eq '"') { $cur += '"'; $i++ }
				else { $inStr = $false }
			}
			continue
		}
		switch ($ch) {
			'"' { $inStr = $true; $cur += $ch }
			'(' { $depth++; $cur += $ch }
			')' { $depth--; $cur += $ch }
			',' { if ($depth -eq 0) { $list.Add($cur.Trim()); $cur = '' } else { $cur += $ch } }
			default { $cur += $ch }
		}
	}
	$list.Add($cur.Trim())
	return ,$list.ToArray()
}

function Get-CallArgs {
	param([string]$Text, [string]$Name)
	$out = New-Object System.Collections.Generic.List[object]
	$rx = [regex]::new([regex]::Escape($Name) + '\s*\(', 'IgnoreCase')
	foreach ($m in $rx.Matches($Text)) {
		$startIdx = $m.Index + $m.Length
		$depth = 1
		$inStr = $false
		$i = $startIdx
		while ($i -lt $Text.Length -and $depth -gt 0) {
			$ch = $Text[$i]
			if ($inStr) {
				if ($ch -eq '"') {
					if ($i + 1 -lt $Text.Length -and $Text[$i + 1] -eq '"') { $i += 2; continue }
					$inStr = $false
				}
			} elseif ($ch -eq '"') { $inStr = $true }
			elseif ($ch -eq '(') { $depth++ }
			elseif ($ch -eq ')') { $depth-- }
			$i++
		}
		if ($depth -eq 0) {
			$out.Add((Split-Args $Text.Substring($startIdx, $i - $startIdx - 1)))
		}
	}
	return ,$out
}

function Convert-ArgToKey {
	param([string]$Expr)
	if ($null -eq $Expr) { return $null }
	$e = $Expr.Trim()
	if ($e -eq '') { return $null }
	$tokens = [regex]::Matches($e, '@CRLF|@TAB|"(?:[^"]|"")*"')
	if ($tokens.Count -eq 0) { return $null }
	$rest = [regex]::Replace($e, '@CRLF|@TAB|"(?:[^"]|"")*"', '')
	$rest = ($rest -replace '&', '') -replace '\s', ''
	if ($rest -ne '') { return $null }
	$sb = New-Object System.Text.StringBuilder
	foreach ($t in $tokens) {
		$v = $t.Value
		if ($v -eq '@CRLF') { [void]$sb.Append('\n') }
		elseif ($v -eq '@TAB') { return $null }
		else { [void]$sb.Append($v.Substring(1, $v.Length - 2).Replace('""', '"')) }
	}
	$key = $sb.ToString()
	if ($key -eq '') { return $null }
	if ($key.EndsWith(' ')) { return $null }
	return $key
}

# 函数名 -> 需要检查的实参下标
$targets = @(
	@{ Name = 'GUICtrlCreateLabel';    Args = @(0) },
	@{ Name = 'GUICtrlCreateButton';   Args = @(0) },
	@{ Name = 'GUICtrlCreateGroup';    Args = @(0) },
	@{ Name = 'GUICtrlCreateCheckbox'; Args = @(0) },
	@{ Name = 'GUICtrlCreateRadio';    Args = @(0) },
	@{ Name = 'GUICtrlCreateTab';      Args = @(0) },
	@{ Name = 'TrayCreateItem';        Args = @(0) },
	@{ Name = 'MsgBox';                Args = @(1, 2) },
	@{ Name = '_MsgBox';               Args = @(1, 2) },
	@{ Name = 'InputBox';              Args = @(0, 1) },
	@{ Name = 'FileOpenDialog';        Args = @(0) },
	@{ Name = '_L';                    Args = @(0) },
	@{ Name = '_Translate';            Args = @(1) }
)

$seen = New-Object System.Collections.Hashtable ([System.StringComparer]::Ordinal)

foreach ($file in (Get-ChildItem -LiteralPath $root -Recurse -Filter *.au3 -File | Where-Object { $_.Name -ne 'TaskScheduler.au3' })) {
	$text = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8
	# 去掉 #cs ... #ce 注释块，保留行数
	$text = [regex]::Replace($text, '(?s)#cs\b.*?#ce\b', {
		param($m)
		return ("`n" * ([regex]::Matches($m.Value, "`n")).Count)
	})
	$lines = $text -split "`r?`n"

	$buf = ''
	$startLine = 0
	for ($i = 0; $i -lt $lines.Count; $i++) {
		$line = $lines[$i]
		if ($buf -eq '') { $startLine = $i + 1 }
		$trimmed = $line.TrimEnd()
		if ($line.TrimStart().StartsWith(';')) {
			$buf = ''
			continue
		}
		if ($trimmed -match '_\s*$') {
			$buf += $trimmed.Substring(0, $trimmed.Length - 1) + ' '
			continue
		}
		$buf += $line

		foreach ($t in $targets) {
			foreach ($args in (Get-CallArgs -Text $buf -Name $t.Name)) {
				foreach ($idx in $t.Args) {
					if ($idx -ge $args.Count) { continue }
					$key = Convert-ArgToKey $args[$idx]
					if ($null -eq $key) { continue }
					$loc = "$($file.Name):$startLine"
					if ($seen.ContainsKey($key)) {
						if (-not $seen[$key].Contains($loc)) { [void]$seen[$key].Add($loc) }
					} else {
						$lst = New-Object System.Collections.Generic.List[string]
						$lst.Add($loc)
						$seen[$key] = $lst
					}
				}
			}
		}
		$buf = ''
	}
}

# ---------- 对比 ----------
$missing = @($seen.Keys | Where-Object { -not $langSet.Contains($_) } | Sort-Object)
$unused = @($langKeys | Where-Object { -not $seen.ContainsKey($_) } | Sort-Object -Unique)

Write-Host ""
Write-Host "语言包：$langPath" -ForegroundColor Cyan
Write-Host ("源码文案：{0} 条，语言包 key：{1} 条" -f $seen.Count, $langKeys.Count)
Write-Host ""

Write-Host ("缺失翻译（会显示英文）：{0} 条" -f $missing.Count) -ForegroundColor Yellow
foreach ($k in $missing) {
	$loc = ($seen[$k] | Select-Object -First 3) -join ', '
	Write-Host ("  {0}    [{1}]" -f $k, $loc) -ForegroundColor Yellow
}

Write-Host ""
Write-Host ("失效翻译（源码已改或删除）：{0} 条" -f $unused.Count) -ForegroundColor DarkYellow
foreach ($k in $unused) {
	Write-Host ("  {0}" -f $k) -ForegroundColor DarkYellow
}

Write-Host ""
if ($missing.Count -eq 0) {
	Write-Host "检查通过：源码文案均有对应翻译。" -ForegroundColor Green
} else {
	Write-Host "请在 Assets\Langs\0804.lang 中补充上述 key。" -ForegroundColor Yellow
}
