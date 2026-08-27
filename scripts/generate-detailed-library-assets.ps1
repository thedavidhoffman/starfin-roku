param(
    [string]$Root = ""
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

if ([string]::IsNullOrWhiteSpace($Root)) {
    $Root = Split-Path -Parent $PSScriptRoot
}
$Root = [System.IO.Path]::GetFullPath($Root)

function New-RoundedPath([System.Drawing.RectangleF]$rectangle, [float]$radius) {
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $diameter = $radius * 2
    $path.AddArc($rectangle.X, $rectangle.Y, $diameter, $diameter, 180, 90)
    $path.AddArc($rectangle.Right - $diameter, $rectangle.Y, $diameter, $diameter, 270, 90)
    $path.AddArc($rectangle.Right - $diameter, $rectangle.Bottom - $diameter, $diameter, $diameter, 0, 90)
    $path.AddArc($rectangle.X, $rectangle.Bottom - $diameter, $diameter, $diameter, 90, 90)
    $path.CloseFigure()
    return $path
}

function New-RoundedMask([string]$path, [int]$width, [int]$height, [float]$radius) {
    $bitmap = New-Object System.Drawing.Bitmap $width, $height, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    try {
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        try {
            $graphics.Clear([System.Drawing.Color]::Transparent)
            $graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
            $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
            $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
            $rectangle = New-Object System.Drawing.RectangleF 0, 0, ($width - 1), ($height - 1)
            $roundedPath = New-RoundedPath $rectangle $radius
            try {
                $brush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::White)
                try {
                    $graphics.FillPath($brush, $roundedPath)
                } finally {
                    $brush.Dispose()
                }
            } finally {
                $roundedPath.Dispose()
            }
        } finally {
            $graphics.Dispose()
        }
        $bitmap.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    } finally {
        $bitmap.Dispose()
    }
}

function New-ScaledMask([string]$sourcePath, [string]$outputPath, [int]$width, [int]$height) {
    $source = [System.Drawing.Bitmap]::FromFile($sourcePath)
    try {
        $bitmap = New-Object System.Drawing.Bitmap $width, $height, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        try {
            $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
            try {
                $graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
                $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
                $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
                $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
                $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
                $graphics.DrawImage($source, 0, 0, $width, $height)
            } finally {
                $graphics.Dispose()
            }
            $bitmap.Save($outputPath, [System.Drawing.Imaging.ImageFormat]::Png)
        } finally {
            $bitmap.Dispose()
        }
    } finally {
        $source.Dispose()
    }
}

function New-CardPanel([string]$path) {
    $bitmap = New-Object System.Drawing.Bitmap 882, 496, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    try {
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        try {
            $graphics.Clear([System.Drawing.Color]::FromArgb(255, 16, 28, 42))
        } finally {
            $graphics.Dispose()
        }
        $bitmap.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    } finally {
        $bitmap.Dispose()
    }
}

$assets = @(
    @{ SourceName = "detailed-poster-mask-288x432.png"; RuntimeName = "detailed-poster-mask.png"; Width = 288; Height = 432; HdWidth = 192; HdHeight = 288; Radius = 14 },
    @{ SourceName = "detailed-card-mask-882x496.png"; RuntimeName = "detailed-card-mask.png"; Width = 882; Height = 496; HdWidth = 588; HdHeight = 331; Radius = 18 }
)

foreach ($asset in $assets) {
    $sourcePath = Join-Path $Root ("images\media-card\" + $asset.SourceName)
    $fhdPath = Join-Path $Root ("images\masks\fhd\" + $asset.RuntimeName)
    $hdPath = Join-Path $Root ("images\masks\hd\" + $asset.RuntimeName)

    New-RoundedMask $sourcePath $asset.Width $asset.Height $asset.Radius
    Copy-Item -LiteralPath $sourcePath -Destination $fhdPath -Force
    New-ScaledMask $sourcePath $hdPath $asset.HdWidth $asset.HdHeight
}

New-CardPanel (Join-Path $Root "images\media-card\detailed-card-panel-882x496.png")

Write-Output "Generated $($assets.Count) detailed library mask pairs."
