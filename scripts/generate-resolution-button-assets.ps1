param(
    [string]$SourceRoot = "",
    [string]$OutputRoot = "",
    [switch]$ValidateOnly
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

if ([string]::IsNullOrWhiteSpace($SourceRoot)) { $SourceRoot = Split-Path -Parent $PSScriptRoot }
if ([string]::IsNullOrWhiteSpace($OutputRoot)) { $OutputRoot = $SourceRoot }

$SourceRoot = [System.IO.Path]::GetFullPath($SourceRoot)
$OutputRoot = [System.IO.Path]::GetFullPath($OutputRoot)
$fhdDirectory = Join-Path $OutputRoot "images\buttons\fhd"
$hdDirectory = Join-Path $OutputRoot "images\buttons\hd"
$assets = @(
    @{ Source = "header-glass-background.9.png"; Name = "header-glass-background.9.png" },
    @{ Source = "header-glass-background-fill.9.png"; Name = "header-glass-background-fill.9.png" },
    @{ Source = "header-button-focused.9.png"; Name = "header-button-focused.9.png" },
    @{ Source = "primary_focused.9.png"; Name = "primary-focused.9.png" },
    @{ Source = "primary_unfocused.9.png"; Name = "primary-unfocused.9.png" }
)

function Test-IsMarkerPixel([System.Drawing.Color]$Pixel) {
    return $Pixel.A -eq 255 -and $Pixel.R -eq 0 -and $Pixel.G -eq 0 -and $Pixel.B -eq 0
}

function Get-ScaledMarkerCoordinate([int]$Coordinate, [int]$SourceLength, [int]$TargetLength) {
    if ($SourceLength -le 1 -or $TargetLength -le 1) { return 1 }
    return 1 + [int][Math]::Round((($Coordinate - 1) * ($TargetLength - 1)) / ($SourceLength - 1))
}

function Copy-ScaledMarkers([System.Drawing.Bitmap]$Source, [System.Drawing.Bitmap]$Target) {
    $black = [System.Drawing.Color]::FromArgb(255, 0, 0, 0)
    $sourceWidth = $Source.Width - 2
    $sourceHeight = $Source.Height - 2
    $targetWidth = $Target.Width - 2
    $targetHeight = $Target.Height - 2

    for ($x = 1; $x -le $sourceWidth; $x++) {
        $targetX = Get-ScaledMarkerCoordinate $x $sourceWidth $targetWidth
        if (Test-IsMarkerPixel $Source.GetPixel($x, 0)) { $Target.SetPixel($targetX, 0, $black) }
        if (Test-IsMarkerPixel $Source.GetPixel($x, $Source.Height - 1)) { $Target.SetPixel($targetX, $Target.Height - 1, $black) }
    }
    for ($y = 1; $y -le $sourceHeight; $y++) {
        $targetY = Get-ScaledMarkerCoordinate $y $sourceHeight $targetHeight
        if (Test-IsMarkerPixel $Source.GetPixel(0, $y)) { $Target.SetPixel(0, $targetY, $black) }
        if (Test-IsMarkerPixel $Source.GetPixel($Source.Width - 1, $y)) { $Target.SetPixel($Target.Width - 1, $targetY, $black) }
    }
}

function New-HdNinePatch([string]$SourcePath, [string]$TargetPath) {
    $source = [System.Drawing.Bitmap]::FromFile($SourcePath)
    try {
        $sourceWidth = $source.Width - 2
        $sourceHeight = $source.Height - 2
        $targetWidth = [Math]::Max(1, [int][Math]::Round($sourceWidth * 2 / 3))
        $targetHeight = [Math]::Max(1, [int][Math]::Round($sourceHeight * 2 / 3))
        $target = New-Object System.Drawing.Bitmap ($targetWidth + 2), ($targetHeight + 2), ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        try {
            $graphics = [System.Drawing.Graphics]::FromImage($target)
            try {
                $graphics.Clear([System.Drawing.Color]::Transparent)
                $graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
                $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
                $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
                $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
                $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
                $destination = New-Object System.Drawing.Rectangle 1, 1, $targetWidth, $targetHeight
                $sourceRectangle = New-Object System.Drawing.Rectangle 1, 1, $sourceWidth, $sourceHeight
                $graphics.DrawImage($source, $destination, $sourceRectangle, [System.Drawing.GraphicsUnit]::Pixel)
            } finally {
                $graphics.Dispose()
            }
            Copy-ScaledMarkers $source $target
            $target.Save($TargetPath, [System.Drawing.Imaging.ImageFormat]::Png)
        } finally {
            $target.Dispose()
        }
    } finally {
        $source.Dispose()
    }
}

function Get-MarkerCount([System.Drawing.Bitmap]$Bitmap, [string]$Edge) {
    $count = 0
    if ($Edge -eq "top" -or $Edge -eq "bottom") {
        $y = 0
        if ($Edge -eq "bottom") { $y = $Bitmap.Height - 1 }
        for ($x = 1; $x -lt $Bitmap.Width - 1; $x++) { if (Test-IsMarkerPixel $Bitmap.GetPixel($x, $y)) { $count++ } }
    } else {
        $x = 0
        if ($Edge -eq "right") { $x = $Bitmap.Width - 1 }
        for ($y = 1; $y -lt $Bitmap.Height - 1; $y++) { if (Test-IsMarkerPixel $Bitmap.GetPixel($x, $y)) { $count++ } }
    }
    return $count
}

function Assert-NinePatch([string]$Path, [int]$Width, [int]$Height) {
    if (-not (Test-Path -LiteralPath $Path)) { throw "Missing generated button asset: $Path" }
    $bitmap = [System.Drawing.Bitmap]::FromFile($Path)
    try {
        if ($bitmap.Width -ne $Width -or $bitmap.Height -ne $Height) {
            throw "$Path must be ${Width}x${Height}; found $($bitmap.Width)x$($bitmap.Height)"
        }
        foreach ($edge in @("top", "bottom", "left", "right")) {
            if ((Get-MarkerCount $bitmap $edge) -eq 0) { throw "$Path is missing its $edge nine-patch markers" }
        }
        $alphaValues = New-Object 'System.Collections.Generic.HashSet[int]'
        for ($y = 1; $y -lt $bitmap.Height - 1; $y++) {
            for ($x = 1; $x -lt $bitmap.Width - 1; $x++) { $null = $alphaValues.Add($bitmap.GetPixel($x, $y).A) }
        }
        if ($alphaValues.Count -lt 4) { throw "$Path does not contain a sufficiently antialiased edge" }
    } finally {
        $bitmap.Dispose()
    }
}

if (-not $ValidateOnly) {
    New-Item -ItemType Directory -Force -Path $fhdDirectory, $hdDirectory | Out-Null
    foreach ($asset in $assets) {
        $sourcePath = Join-Path $SourceRoot ("images\buttons\" + $asset.Source)
        Copy-Item -LiteralPath $sourcePath -Destination (Join-Path $fhdDirectory $asset.Name) -Force
        New-HdNinePatch $sourcePath (Join-Path $hdDirectory $asset.Name)
    }
}

foreach ($asset in $assets) {
    $sourcePath = Join-Path $SourceRoot ("images\buttons\" + $asset.Source)
    $source = [System.Drawing.Bitmap]::FromFile($sourcePath)
    try {
        $fhdWidth = $source.Width
        $fhdHeight = $source.Height
        $hdWidth = [int][Math]::Round(($source.Width - 2) * 2 / 3) + 2
        $hdHeight = [int][Math]::Round(($source.Height - 2) * 2 / 3) + 2
    } finally {
        $source.Dispose()
    }
    Assert-NinePatch (Join-Path $fhdDirectory $asset.Name) $fhdWidth $fhdHeight
    Assert-NinePatch (Join-Path $hdDirectory $asset.Name) $hdWidth $hdHeight
}

Write-Output "Validated $($assets.Count) FHD/HD button nine-patch pairs."
