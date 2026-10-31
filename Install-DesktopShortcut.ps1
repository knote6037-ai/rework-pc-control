[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$appDirectory = Join-Path $PSScriptRoot 'app'
$executable = Join-Path $appDirectory 'ReworkPCControl.exe'
if (!(Test-Path -LiteralPath $executable)) { throw 'Сначала запустите Build.ps1 или распакуйте готовую папку app.' }
$desktopDirectory = [Environment]::GetFolderPath('Desktop')
if ([string]::IsNullOrWhiteSpace($desktopDirectory) -or !(Test-Path -LiteralPath $desktopDirectory)) {
    throw 'Не удалось найти рабочий стол Windows.'
}
$localShortcutPath = Join-Path $PSScriptRoot 'Rework PC Control.lnk'
$desktopShortcutPath = Join-Path $desktopDirectory 'Rework PC Control.lnk'
$shell = New-Object -ComObject WScript.Shell
# Saving locally first avoids WScript.Save issues with redirected Cyrillic desktop paths.
$shortcut = $shell.CreateShortcut($localShortcutPath)
$shortcut.TargetPath = $executable
$shortcut.WorkingDirectory = $appDirectory
$shortcut.IconLocation = $executable + ',0'
$shortcut.Description = 'Rework PC Control — C++ / Qt Quick'
$shortcut.Save()
Copy-Item -LiteralPath $localShortcutPath -Destination $desktopShortcutPath -Force
Write-Host "Ярлык Rework PC Control обновлён: $desktopShortcutPath"
