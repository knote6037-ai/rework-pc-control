$ErrorActionPreference = 'Stop'
$compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
& $compiler /nologo /target:exe /platform:x64 /optimize+ /reference:System.dll /reference:System.Core.dll /reference:System.Web.Extensions.dll ('/out:' + (Join-Path $PSScriptRoot 'AstraLimitsBridge.exe')) (Join-Path $PSScriptRoot 'AstraLimitsBridge.cs')
if ($LASTEXITCODE -ne 0) { throw 'Astra Limits C# build failed' }
