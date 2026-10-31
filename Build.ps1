[CmdletBinding()]
param(
    [string]$QtKit = 'C:\Qt\6.12.0\mingw_64',
    [string]$CompilerDirectory = '',
    [string]$BuildDirectory = ''
)

$ErrorActionPreference = 'Stop'
$projectRoot = $PSScriptRoot
$qtBin = Join-Path $QtKit 'bin'
$qtInstallRoot = Split-Path -Parent (Split-Path -Parent $QtKit)
$toolsRoot = Join-Path $qtInstallRoot 'Tools'
$cmake = Join-Path $toolsRoot 'CMake_64\bin\cmake.exe'
$ctest = Join-Path $toolsRoot 'CMake_64\bin\ctest.exe'
$ninja = Join-Path $toolsRoot 'Ninja\ninja.exe'
$deploy = Join-Path $qtBin 'windeployqt.exe'

if ([string]::IsNullOrWhiteSpace($CompilerDirectory)) {
    $compilerCandidates = @(Get-ChildItem -LiteralPath $toolsRoot -Directory -Filter 'mingw*_64' -ErrorAction SilentlyContinue |
        Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'bin\g++.exe') } |
        Sort-Object Name -Descending)
    if ($compilerCandidates.Count -eq 0) { throw 'Не найден MinGW 64-bit. Добавьте компилятор для Desktop Qt в Qt Maintenance Tool.' }
    $CompilerDirectory = Join-Path $compilerCandidates[0].FullName 'bin'
}

$cCompiler = Join-Path $CompilerDirectory 'gcc.exe'
$cppCompiler = Join-Path $CompilerDirectory 'g++.exe'
foreach ($requiredPath in @($cmake, $ctest, $ninja, $deploy, $cCompiler, $cppCompiler, (Join-Path $qtBin 'qmake.exe'))) {
    if (!(Test-Path -LiteralPath $requiredPath)) { throw "Не найден инструмент: $requiredPath" }
}
if (!(Test-Path -LiteralPath (Join-Path $QtKit 'lib\cmake\Qt6ShaderTools\Qt6ShaderToolsConfig.cmake'))) {
    throw 'В выбранном Qt отсутствует Qt Shader Tools. Добавьте этот компонент через Qt Maintenance Tool.'
}
if (!(Test-Path -LiteralPath (Join-Path $projectRoot 'CMakeLists.txt'))) { throw 'Не найден CMakeLists.txt. Распакуйте исходники целиком.' }

if ([string]::IsNullOrWhiteSpace($BuildDirectory)) {
    $projectParent = Split-Path -Parent $projectRoot
    if ((Split-Path -Leaf $projectParent) -eq 'outputs') {
        $workspace = Split-Path -Parent $projectParent
        $BuildDirectory = Join-Path $workspace 'work\qt-build'
    }
    else {
        $BuildDirectory = Join-Path $projectParent 'work\ReworkPCControl-Qt-build'
    }
}
$BuildDirectory = [IO.Path]::GetFullPath($BuildDirectory)
$projectAbsolute = [IO.Path]::GetFullPath($projectRoot).TrimEnd('\')
if ($BuildDirectory.Equals($projectAbsolute, [StringComparison]::OrdinalIgnoreCase) -or
    $BuildDirectory.StartsWith($projectAbsolute + '\', [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Папка промежуточной сборки должна находиться вне папки проекта и готового приложения.'
}

$appDirectory = Join-Path $projectRoot 'app'
$appExecutable = Join-Path $appDirectory 'ReworkPCControl.exe'
$originalPath = $env:PATH
try {
    # Only this build process sees the selected MinGW/Qt tools; Windows PATH is not changed.
    $env:PATH = $qtBin + ';' + $CompilerDirectory + ';' + (Split-Path -Parent $cmake) + ';' + (Split-Path -Parent $ninja) + ';' + $originalPath
    New-Item -ItemType Directory -Force -Path $BuildDirectory, $appDirectory | Out-Null
    if (Test-Path -LiteralPath (Join-Path $projectRoot 'CreateIcon.ps1')) { & (Join-Path $projectRoot 'CreateIcon.ps1') }
    if (Test-Path -LiteralPath (Join-Path $projectRoot 'sensors\BuildSensorHost.ps1')) { & (Join-Path $projectRoot 'sensors\BuildSensorHost.ps1') }
    if (Test-Path -LiteralPath (Join-Path $projectRoot 'limits\BuildBridge.ps1')) { & (Join-Path $projectRoot 'limits\BuildBridge.ps1') }
    Write-Host "Кит: Desktop Qt $(& (Join-Path $qtBin 'qmake.exe') -query QT_VERSION) MinGW 64-bit"
    Write-Host "Компилятор: $cppCompiler"
    $configureArguments = @('-S', $projectRoot, '-B', $BuildDirectory, '-G', 'Ninja',
        '-DCMAKE_BUILD_TYPE=Release', "-DCMAKE_PREFIX_PATH=$QtKit", "-DCMAKE_MAKE_PROGRAM=$ninja",
        "-DCMAKE_C_COMPILER=$cCompiler", "-DCMAKE_CXX_COMPILER=$cppCompiler", '-DBUILD_TESTING=ON')
    & $cmake @configureArguments
    if ($LASTEXITCODE -ne 0) { throw 'CMake не смог настроить проект для выбранного MinGW-кита.' }
    & $cmake --build $BuildDirectory --parallel 4
    if ($LASTEXITCODE -ne 0) { throw 'Ошибка сборки C++/QML.' }
    & $ctest --test-dir $BuildDirectory --output-on-failure -C Release
    if ($LASTEXITCODE -ne 0) { throw 'Проверки логики не прошли. Готовое приложение не обновлено.' }

    $builtExecutable = Join-Path $BuildDirectory 'ReworkPCControl.exe'
    if (!(Test-Path -LiteralPath $builtExecutable)) { throw "Не найден результат сборки: $builtExecutable" }
    Copy-Item -LiteralPath $builtExecutable -Destination $appExecutable -Force
    $limitSources = Join-Path $projectRoot 'limits'
    $limitDestination = Join-Path $appDirectory 'limits'
    New-Item -ItemType Directory -Force -Path $limitDestination | Out-Null
    Get-ChildItem -LiteralPath $limitSources | ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $limitDestination -Force }
    if (Test-Path -LiteralPath (Join-Path $projectRoot 'rework.ico')) {
        Copy-Item -LiteralPath (Join-Path $projectRoot 'rework.ico') -Destination $appDirectory -Force
    }
    $sensorSources = Join-Path $projectRoot 'sensors'
    if (Test-Path -LiteralPath $sensorSources) {
        $sensorDestination = Join-Path $appDirectory 'sensors'
        New-Item -ItemType Directory -Force -Path $sensorDestination | Out-Null
        Get-ChildItem -LiteralPath $sensorSources | ForEach-Object {
            Copy-Item -LiteralPath $_.FullName -Destination $sensorDestination -Recurse -Force
        }
    }
    # windeployqt пишет предупреждения в stderr. При $ErrorActionPreference = 'Stop'
    # PowerShell 5.1 превращает такую строку в исключение, и скрипт «падает» уже
    # после успешного деплоя. На время вызова режим ослабляется, код возврата
    # по-прежнему проверяется вручную.
    $deployPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        & $deploy --release --qmldir (Join-Path $projectRoot 'qml') --compiler-runtime --no-translations --skip-plugin-types qmltooling $appExecutable
    } finally {
        $ErrorActionPreference = $deployPreference
    }
    if ($LASTEXITCODE -ne 0) { throw 'Не удалось собрать зависимости Qt рядом с приложением.' }

    # Qt's own runtime takes priority if the installed compiler package is older than Qt.
    foreach ($runtimeName in @('libstdc++-6.dll', 'libgcc_s_seh-1.dll', 'libwinpthread-1.dll')) {
        $runtimePath = Join-Path $qtBin $runtimeName
        if (Test-Path -LiteralPath $runtimePath) {
            Copy-Item -LiteralPath $runtimePath -Destination (Join-Path $appDirectory $runtimeName) -Force
        }
    }
    Write-Host "Готово: $appExecutable"
    Write-Host 'Для ярлыка запустите Install-DesktopShortcut.ps1.'
}
finally {
    $env:PATH = $originalPath
}
