param([string]$Root = "")

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing
if ([string]::IsNullOrWhiteSpace($Root)) { $Root = Split-Path -Parent $PSScriptRoot }
$Root = [System.IO.Path]::GetFullPath($Root)

function New-RoundedPath([float]$x, [float]$y, [float]$width, [float]$height, [float]$radius) {
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $diameter = $radius * 2
    $path.AddArc($x, $y, $diameter, $diameter, 180, 90)
    $path.AddArc($x + $width - $diameter, $y, $diameter, $diameter, 270, 90)
    $path.AddArc($x + $width - $diameter, $y + $height - $diameter, $diameter, $diameter, 0, 90)
    $path.AddArc($x, $y + $height - $diameter, $diameter, $diameter, 90, 90)
    $path.CloseFigure()
    return $path
}

function Save-DownsampledBitmap([int]$width, [int]$height, [scriptblock]$draw, [string]$path) {
    $scale = 4
    $large = New-Object System.Drawing.Bitmap ($width * $scale), ($height * $scale), ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    try {
        $graphics = [System.Drawing.Graphics]::FromImage($large)
        try {
            $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
            $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
            $graphics.Clear([System.Drawing.Color]::Transparent)
            & $draw $graphics $scale
        } finally {
            $graphics.Dispose()
        }

        $result = New-Object System.Drawing.Bitmap $width, $height, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        try {
            $output = [System.Drawing.Graphics]::FromImage($result)
            try {
                $output.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
                $output.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
                $output.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
                $output.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
                $output.DrawImage($large, 0, 0, $width, $height)
            } finally {
                $output.Dispose()
            }
            $result.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
        } finally {
            $result.Dispose()
        }
    } finally {
        $large.Dispose()
    }
}


# Match the library thumbnail mask radius at each native rendering resolution.
foreach ($profile in @("fhd", "hd")) {
    $width = if ($profile -eq "hd") { 213 } else { 320 }
    $height = if ($profile -eq "hd") { 120 } else { 180 }
    $radius = if ($profile -eq "hd") { 8 } else { 12 }
    $directory = Join-Path $Root "images/masks/$profile"
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
    Save-DownsampledBitmap $width $height {
        param($graphics, $scale)
        $shape = New-RoundedPath 0 0 ($width * $scale) ($height * $scale) ($radius * $scale)
        try { $graphics.FillPath([System.Drawing.Brushes]::White, $shape) } finally { $shape.Dispose() }
    } (Join-Path $directory "movie-extra-mask.png")
}

# The supplied FHD screenshot shows the native RowList outline 24 px left of its
# intended image-relative position. Keep the 356 px stride, add trailing canvas,
# and compensate the outline inside that canvas; never translate the image.
$directory = Join-Path $Root "images/movie"
New-Item -ItemType Directory -Force -Path $directory | Out-Null
Save-DownsampledBitmap 360 264 {
    param($graphics, $scale)
    $shape = New-RoundedPath (25 * $scale) (1 * $scale) (330 * $scale) (190 * $scale) (15 * $scale)
    try {
        $pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::White), (6 * $scale)
        try {
            $pen.Alignment = [System.Drawing.Drawing2D.PenAlignment]::Inset
            $graphics.DrawPath($pen, $shape)
        } finally { $pen.Dispose() }
    } finally { $shape.Dispose() }
} (Join-Path $directory "extras-focus-360x264.png")
