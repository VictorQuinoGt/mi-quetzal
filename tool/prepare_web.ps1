$ErrorActionPreference = 'Stop'
Push-Location (Join-Path $PSScriptRoot '..')
try {
    dart run sqflite_common_ffi_web:setup
    if ($LASTEXITCODE -ne 0) { throw 'No se pudieron generar los recursos de SQLite web.' }
    New-Item -ItemType Directory -Path 'test/web_assets' -Force | Out-Null
    Copy-Item -LiteralPath 'web/sqlite3.wasm' -Destination 'test/web_assets/sqlite3.wasm'
    Copy-Item -LiteralPath 'web/sqflite_sw.js' -Destination 'test/web_assets/sqflite_sw.js'
    # Flutter 3.47 en Windows puede responder 404 al servir CanvasKit en tests.
    # El servidor también expone test/, por lo que estas copias evitan modificar el SDK.
    $flutterBin = Split-Path -Parent (Get-Command flutter -ErrorAction Stop).Source
    $canvasKitSource = Join-Path $flutterBin 'cache/flutter_web_sdk/canvaskit'
    foreach ($variant in @('', 'chromium')) {
        $testCanvasKit = Join-Path 'test/canvaskit' $variant
        New-Item -ItemType Directory -Path $testCanvasKit -Force | Out-Null
        foreach ($asset in @('canvaskit.js', 'canvaskit.wasm')) {
            $sourceAsset = Join-Path (Join-Path $canvasKitSource $variant) $asset
            Copy-Item -LiteralPath $sourceAsset -Destination (Join-Path $testCanvasKit $asset)
        }
    }
} finally {
    Pop-Location
}
