param([string]$AppPath = (Join-Path (Split-Path -Parent $PSScriptRoot) 'build/windows/x64/runner/Release'))
$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $AppPath -PathType Container)) { throw 'App directory does not exist.' }
$destination = Join-Path $AppPath 'avif'
New-Item -ItemType Directory -Force -Path $destination | Out-Null
Copy-Item -Path (Join-Path (Split-Path -Parent $PSScriptRoot) 'native/avif/bin/*') -Destination $destination -Force
# 子プロセスの DLL 検索は親フォルダへ戻らないため、ランタイムを隣へ置く。
foreach ($runtime in @('msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll')) {
    Copy-Item -LiteralPath (Join-Path $AppPath $runtime) -Destination $destination -Force
}
