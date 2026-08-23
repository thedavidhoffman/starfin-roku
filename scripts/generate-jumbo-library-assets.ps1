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

function New-JumboMask([string]$path, [int]$width, [int]$height, [float]$radius) {
    $bitmap = New-Object System.Drawing.Bitmap $width, $height, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    try {
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        try {
            $graphics.Clear([System.Drawing.Color]::Transparent)
            $graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
            $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
            $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
            $rectangle = New-Object System.Drawing.RectangleF 0, 0, $width, $height
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

function New-HdJumboMask([string]$sourcePath, [string]$outputPath) {
    $source = [System.Drawing.Bitmap]::FromFile($sourcePath)
    try {
        $bitmap = New-Object System.Drawing.Bitmap 588, 331, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        try {
            $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
            try {
                $graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
                $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
                $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
                $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
                $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
                $graphics.DrawImage($source, 0, 0, 588, 331)
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

function New-JumboFocus([string]$outputPath) {
    $bitmap = New-Object System.Drawing.Bitmap 936, 591, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    try {
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        try {
            $graphics.Clear([System.Drawing.Color]::Transparent)
            $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
            $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

            # The image occupies x=27..908 and y=0..495 in the MarkupGrid item canvas.
            # Insetting the 12px pen center by 6px keeps the visible ring on those bounds.
            $rectangle = New-Object System.Drawing.RectangleF 33, 6, 870, 484
            $roundedPath = New-RoundedPath $rectangle 12
            try {
                $pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::White), 12
                try {
                    $pen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
                    $graphics.DrawPath($pen, $roundedPath)
                } finally {
                    $pen.Dispose()
                }
            } finally {
                $roundedPath.Dispose()
            }
        } finally {
            $graphics.Dispose()
        }
        $bitmap.Save($outputPath, [System.Drawing.Imaging.ImageFormat]::Png)
    } finally {
        $bitmap.Dispose()
    }
}

$fhdMaskPath = Join-Path $Root "images\masks\fhd\media-card-jumbo-mask.png"
$hdMaskPath = Join-Path $Root "images\masks\hd\media-card-jumbo-mask.png"
$sourceMaskPath = Join-Path $Root "images\media-card\jumbo-mask-882x496.png"
$focusPath = Join-Path $Root "images\library\jumbo-focus-936x591.png"

New-JumboMask $sourceMaskPath 882 496 18
Copy-Item -LiteralPath $sourceMaskPath -Destination $fhdMaskPath -Force
New-HdJumboMask $sourceMaskPath $hdMaskPath
New-JumboFocus $focusPath

Write-Output "Generated jumbo library mask and focus assets."
