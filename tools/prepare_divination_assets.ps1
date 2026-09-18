Add-Type -AssemblyName System.Drawing

$sourcePath = 'C:\Users\wangmeisu\AppData\Local\Temp\codex-clipboard-338470d4-3740-47ad-9036-a69a830f6986.png'
$outputDir = Join-Path (Get-Location) 'assets\generated\ui\divination'
New-Item -ItemType Directory -Force -Path $outputDir | Out-Null

function Test-CheckerPixel([System.Drawing.Color] $color) {
    return $color.R -gt 185 -and $color.G -gt 185 -and $color.B -gt 185 -and
        ([Math]::Max($color.R, [Math]::Max($color.G, $color.B)) - [Math]::Min($color.R, [Math]::Min($color.G, $color.B))) -lt 38
}

function Remove-EdgeCheckerboard([System.Drawing.Bitmap] $bitmap) {
    $width = $bitmap.Width
    $height = $bitmap.Height
    $visited = New-Object 'bool[,]' $width, $height
    $queue = New-Object System.Collections.Queue
    for ($x = 0; $x -lt $width; $x++) {
        $queue.Enqueue([Drawing.Point]::new($x, 0)); $queue.Enqueue([Drawing.Point]::new($x, $height - 1))
    }
    for ($y = 1; $y -lt ($height - 1); $y++) {
        $queue.Enqueue([Drawing.Point]::new(0, $y)); $queue.Enqueue([Drawing.Point]::new($width - 1, $y))
    }
    while ($queue.Count -gt 0) {
        $point = $queue.Dequeue()
        if ($point.X -lt 0 -or $point.X -ge $width -or $point.Y -lt 0 -or $point.Y -ge $height -or $visited[$point.X, $point.Y]) { continue }
        $visited[$point.X, $point.Y] = $true
        $color = $bitmap.GetPixel($point.X, $point.Y)
        if (-not (Test-CheckerPixel $color)) { continue }
        $bitmap.SetPixel($point.X, $point.Y, [Drawing.Color]::Transparent)
        $queue.Enqueue([Drawing.Point]::new($point.X + 1, $point.Y)); $queue.Enqueue([Drawing.Point]::new($point.X - 1, $point.Y))
        $queue.Enqueue([Drawing.Point]::new($point.X, $point.Y + 1)); $queue.Enqueue([Drawing.Point]::new($point.X, $point.Y - 1))
    }
}

$source = [Drawing.Bitmap]::new($sourcePath)
$background = [Drawing.Bitmap]::new($source)
Remove-EdgeCheckerboard $background
$graphics = [Drawing.Graphics]::FromImage($background)
$graphics.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias
$bubbleBrush = [Drawing.SolidBrush]::new([Drawing.Color]::FromArgb(255, 255, 247, 224))
$bubblePath = [Drawing.Drawing2D.GraphicsPath]::new()
$bubblePath.AddArc(282, 201, 472, 178, 180, 180)
$bubblePath.AddArc(282, 201, 472, 178, 0, 180)
$bubblePath.CloseFigure()
$graphics.FillPath($bubbleBrush, $bubblePath)
$graphics.FillPolygon($bubbleBrush, [Drawing.Point[]]@([Drawing.Point]::new(360, 348), [Drawing.Point]::new(395, 348), [Drawing.Point]::new(375, 382)))
$graphics.Dispose(); $bubbleBrush.Dispose(); $bubblePath.Dispose()
$background.Save((Join-Path $outputDir 'divination_house_background.png'), [Drawing.Imaging.ImageFormat]::Png)
$background.Dispose()

function Save-ObjectCrop([string] $name, [int] $x, [int] $y, [int] $width, [int] $height) {
    $crop = [Drawing.Bitmap]::new($width, $height, [Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [Drawing.Graphics]::FromImage($crop)
    $g.DrawImage($source, [Drawing.Rectangle]::new(0, 0, $width, $height), [Drawing.Rectangle]::new($x, $y, $width, $height), [Drawing.GraphicsUnit]::Pixel)
    $g.Dispose()
    for ($px = 0; $px -lt $width; $px++) {
        for ($py = 0; $py -lt $height; $py++) {
            $c = $crop.GetPixel($px, $py)
            if ($c.R -lt 110 -and $c.B -gt $c.R * 1.15 -and $c.B -gt $c.G * 0.95) {
                $crop.SetPixel($px, $py, [Drawing.Color]::FromArgb(0, $c.R, $c.G, $c.B))
            }
        }
    }
    $crop.Save((Join-Path $outputDir ($name + '.png')), [Drawing.Imaging.ImageFormat]::Png)
    $crop.Dispose()
}

Save-ObjectCrop 'event_card' 250 710 105 105
Save-ObjectCrop 'event_gain_barracks' 375 710 115 110
Save-ObjectCrop 'event_lose_barracks' 515 710 120 110
Save-ObjectCrop 'event_gold' 635 700 130 105
Save-ObjectCrop 'event_upgrade_barracks' 375 785 120 125
Save-ObjectCrop 'event_downgrade_barracks' 515 785 125 125
$source.Dispose()
