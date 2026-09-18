$sourceFiles = @{
    'codex-clipboard-7dfbf7ed-64b2-4138-8258-0760b42f99b9.png' = 'merchant_shop_background.png'
}
$outputDir = Join-Path (Get-Location) 'assets\generated\ui\merchant'
New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
foreach ($name in $sourceFiles.Keys) {
    Copy-Item -LiteralPath (Join-Path 'C:\Users\wangmeisu\AppData\Local\Temp' $name) -Destination (Join-Path $outputDir $sourceFiles[$name]) -Force
}
