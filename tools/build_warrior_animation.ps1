Add-Type -AssemblyName System.Drawing

$sourceBasePath = Join-Path $PSScriptRoot '..\assets\units\runtime\warrior_base.png'
$sourceMaskPath = Join-Path $PSScriptRoot '..\assets\units\runtime\warrior_mask.png'
$destinationBasePath = Join-Path $PSScriptRoot '..\assets\units\runtime\warrior_anim_base.png'
$destinationMaskPath = Join-Path $PSScriptRoot '..\assets\units\runtime\warrior_anim_mask.png'

$directions = @(0, 2, 5, 1) # down, left, right, up from the existing six-view strip
$animationCounts = @{
    idle = 4
    move = 6
    attack = 6
    hit = 2
    death = 6
}
$animationNames = @('idle', 'move', 'attack', 'hit', 'death')
$moveOffsets = @(@(-2, 0), @(0, -1), @(2, 0), @(1, 1), @(-1, 1), @(0, 0))

function New-AnimationAtlas([string]$sourcePath, [string]$destinationPath) {
    $source = [System.Drawing.Bitmap]::FromFile((Resolve-Path $sourcePath))
    $atlas = New-Object System.Drawing.Bitmap(1024, 1024, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [System.Drawing.Graphics]::FromImage($atlas)
    $graphics.Clear([System.Drawing.Color]::Transparent)
    $graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
    $frameIndex = 0
    foreach ($directionCell in $directions) {
        foreach ($animationName in $animationNames) {
            for ($localIndex = 0; $localIndex -lt $animationCounts[$animationName]; $localIndex++) {
                $sourceRect = [System.Drawing.Rectangle]::new([int]$directionCell * 96, 0, 96, 96)
                $offsetX = 0
                $offsetY = 0
                if ($animationName -eq 'move') {
                    $offsetX = $moveOffsets[$localIndex][0]
                    $offsetY = $moveOffsets[$localIndex][1]
                }
                $destinationX = [int](($frameIndex % 10) * 96 + $offsetX)
                $destinationY = [int]([Math]::Floor($frameIndex / 10) * 96 + $offsetY)
                $destinationRect = [System.Drawing.Rectangle]::new($destinationX, $destinationY, 96, 96)
                $graphics.DrawImage($source, $destinationRect, $sourceRect.X, $sourceRect.Y, $sourceRect.Width, $sourceRect.Height, [System.Drawing.GraphicsUnit]::Pixel)
                $frameIndex++
            }
        }
    }
    $atlas.Save((Resolve-Path (Split-Path $destinationPath -Parent)).Path + '\' + (Split-Path $destinationPath -Leaf), [System.Drawing.Imaging.ImageFormat]::Png)
    $graphics.Dispose()
    $atlas.Dispose()
    $source.Dispose()
}

New-AnimationAtlas $sourceBasePath $destinationBasePath
New-AnimationAtlas $sourceMaskPath $destinationMaskPath
