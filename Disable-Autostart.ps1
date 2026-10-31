[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$startupDirectory = [Environment]::GetFolderPath('Startup')
if ([string]::IsNullOrWhiteSpace($startupDirectory)) { throw 'Не найдена папка автозагрузки Windows.' }
$shortcutPath = Join-Path $startupDirectory 'Rework PC Control.lnk'
if (!(Test-Path -LiteralPath $shortcutPath -PathType Leaf)) {
    Write-Host 'Автозапуск Rework уже выключен.'
    return
}
$expectedExecutable = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'app\ReworkPCControl.exe'))
$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($shortcutPath)
if (![string]::Equals($shortcut.TargetPath, $expectedExecutable, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Ярлык указывает на другое приложение или другую папку. Он оставлен без изменений.'
}
# Remove exactly this application's single Startup shortcut, never a directory.
Remove-Item -LiteralPath $shortcutPath
Write-Host 'Автозапуск Rework выключен.'
