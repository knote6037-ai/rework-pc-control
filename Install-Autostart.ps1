[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$appDirectory = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'app'))
$executable = Join-Path $appDirectory 'ReworkPCControl.exe'
if (!(Test-Path -LiteralPath $executable -PathType Leaf)) {
    throw 'Не найдено приложение app\ReworkPCControl.exe. Распакуйте готовую папку app целиком.'
}
$startupDirectory = [Environment]::GetFolderPath('Startup')
if ([string]::IsNullOrWhiteSpace($startupDirectory) -or !(Test-Path -LiteralPath $startupDirectory -PathType Container)) {
    throw 'Не найдена папка автозагрузки текущего пользователя Windows.'
}
$localShortcutPath = Join-Path $PSScriptRoot 'Rework PC Control.autostart.lnk'
$startupShortcutPath = Join-Path $startupDirectory 'Rework PC Control.lnk'
$shell = New-Object -ComObject WScript.Shell
# Save locally before copying, including on systems with a redirected Unicode Startup path.
$shortcut = $shell.CreateShortcut($localShortcutPath)
$shortcut.TargetPath = $executable
$shortcut.WorkingDirectory = $appDirectory
$shortcut.Arguments = ''
$shortcut.WindowStyle = 1
$shortcut.IconLocation = $executable + ',0'
$shortcut.Description = 'Rework PC Control — запуск после входа в Windows'
$shortcut.Save()
Copy-Item -LiteralPath $localShortcutPath -Destination $startupShortcutPath -Force
$installed = $shell.CreateShortcut($startupShortcutPath)
if (![string]::Equals($installed.TargetPath, $executable, [StringComparison]::OrdinalIgnoreCase) -or $installed.Arguments -ne '') {
    throw 'Не удалось проверить ярлык автозапуска.'
}
Write-Host "Автозапуск Rework включён: $startupShortcutPath"
