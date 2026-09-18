$sourceFiles = @{
    'codex-clipboard-0536995c-fb49-4a87-a438-391c27d1e6be.png' = 'divination_background.png'
    'codex-clipboard-64973583-745e-4b7f-8226-f988478c5666.png' = 'divination_bubble.png'
    'codex-clipboard-c8020d29-1707-4293-8335-62890bed2547.png' = 'divination_close.png'
}
$outputDir = Join-Path (Get-Location) 'assets\generated\ui\divination'
New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
foreach ($name in $sourceFiles.Keys) {
    $source = Join-Path 'C:\Users\wangmeisu\AppData\Local\Temp' $name
    Copy-Item -LiteralPath $source -Destination (Join-Path $outputDir $sourceFiles[$name]) -Force
}
