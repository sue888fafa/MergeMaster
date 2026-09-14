param(
    [Parameter(Position = 0)]
    [string]$ApkPath = "output\HexDominion-faction-mask-audit.apk",
    [int]$MaxMiB = 60
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $ApkPath)) {
    throw "APK not found: $ApkPath"
}

$jarCandidates = @(
    (Join-Path $env:JAVA_HOME "bin\jar.exe"),
    "jar.exe"
)
$jar = $jarCandidates | Where-Object { $_ -and (Test-Path -LiteralPath $_ -ErrorAction SilentlyContinue) } | Select-Object -First 1
if (-not $jar) {
    throw "Java jar.exe was not found. Set JAVA_HOME or add a JDK to PATH."
}

$apk = Get-Item -LiteralPath $ApkPath
$sizeMiB = [math]::Round($apk.Length / 1MB, 2)
$entries = @(& $jar tf $apk.FullName)
if ($LASTEXITCODE -ne 0) {
    throw "Could not read APK contents: $ApkPath"
}
$textureRows = @(& $jar tvf $apk.FullName | Where-Object { $_ -match 'assets/\.godot/imported/.*\.ctex$' })
if ($LASTEXITCODE -ne 0) {
    throw "Could not read APK entry sizes: $ApkPath"
}
$textureBytes = 0L
foreach ($row in $textureRows) {
    $sizeMatch = [regex]::Match($row, '^\s*(\d+)\s+')
    if ($sizeMatch.Success) {
        $textureBytes += [int64]$sizeMatch.Groups[1].Value
    }
}
$textureMiB = [math]::Round($textureBytes / 1MB, 3)

$forbiddenPatterns = @(
    "^assets/tests/",
    "^assets/assets/concepts/",
    "cartoon-shield"
)
$forbidden = foreach ($pattern in $forbiddenPatterns) {
    $entries | Where-Object { $_ -match $pattern }
}

Write-Output "APK: $($apk.FullName)"
Write-Output "Size: $sizeMiB MiB"
Write-Output "Entries: $($entries.Count)"
Write-Output "Imported texture payload: $textureMiB MiB ($($textureRows.Count) ctex files)"

if ($sizeMiB -gt $MaxMiB) {
    throw "APK exceeds the $MaxMiB MiB release review limit."
}
if ($forbidden) {
    Write-Output "Forbidden entries:"
    $forbidden | Sort-Object -Unique | ForEach-Object { Write-Output "  $_" }
    throw "APK contains excluded test, concept, or unused art resources."
}

Write-Output "PASS: APK size and excluded-resource checks passed."
