[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$sensorRoot = $PSScriptRoot
$compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (!(Test-Path -LiteralPath $compiler)) { throw 'Для сборки модуля датчиков нужна .NET Framework 4.8.' }
$library = Join-Path $sensorRoot 'LibreHardwareMonitorLib.dll'
if (!(Test-Path -LiteralPath $library)) {
    throw 'Не найдены библиотеки LibreHardwareMonitor 0.9.6. Распакуйте поставку модуля датчиков целиком.'
}
$arguments = @('/nologo','/target:winexe','/platform:x64','/optimize+','/utf8output',
    ('/out:' + (Join-Path $sensorRoot 'ReworkSensorHost.exe')),
    '/reference:System.dll','/reference:System.Core.dll','/reference:System.Web.Extensions.dll',
    ('/reference:' + $library), (Join-Path $sensorRoot 'SensorHost.cs'))
& $compiler @arguments
if ($LASTEXITCODE -ne 0) { throw 'Не удалось собрать модуль датчиков CPU.' }
Write-Host 'Модуль датчиков CPU собран.'
