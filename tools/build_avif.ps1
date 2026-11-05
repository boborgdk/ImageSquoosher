$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$buildDirectory = Join-Path $projectRoot 'build/avif'
cmake -S (Join-Path $projectRoot 'native/avif') -B $buildDirectory -A x64
if ($LASTEXITCODE -ne 0) { throw 'AVIF configuration failed.' }
cmake --build $buildDirectory --config Release --target squoosher_avif --parallel
if ($LASTEXITCODE -ne 0) { throw 'AVIF build failed.' }
$outputDirectory = Join-Path $projectRoot 'native/avif/bin'
New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null
Copy-Item -LiteralPath (Join-Path $buildDirectory 'Release/squoosher_avif.exe') -Destination $outputDirectory -Force
# 同梱した依存物のライセンスも配布する。
Copy-Item -LiteralPath (Join-Path $buildDirectory '_deps/libavif-src/LICENSE') -Destination (Join-Path $outputDirectory 'libavif-LICENSE') -Force
Get-ChildItem -LiteralPath (Join-Path $buildDirectory '_deps') -Recurse -File -Include LICENSE,PATENTS,COPYING | ForEach-Object {
    $licenseName = $_.FullName.Substring($buildDirectory.Length + 1).Replace('\', '_')
    Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $outputDirectory $licenseName) -Force
}
