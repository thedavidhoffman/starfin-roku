param([string]$Root = "")

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

if ([string]::IsNullOrWhiteSpace($Root)) {
    $Root = Split-Path -Parent $PSScriptRoot
}
$Root = [System.IO.Path]::GetFullPath($Root)

$posterSpecs = @(
    @{ Columns = 6; ArtworkWidth = 252; ArtworkHeight = 378; CellWidth = 297; CellHeight = 465 },
    @{ Columns = 5; ArtworkWidth = 309; ArtworkHeight = 464; CellWidth = 354; CellHeight = 551 },
    @{ Columns = 4; ArtworkWidth = 393; ArtworkHeight = 590; CellWidth = 438; CellHeight = 677 },
    @{ Columns = 3; ArtworkWidth = 537; ArtworkHeight = 806; CellWidth = 582; CellHeight = 893 }
)
$thumbnailSpecs = @(
    @{ Columns = 4; ArtworkWidth = 441; ArtworkHeight = 249; CellWidth = 465; CellHeight = 348 },
    @{ Columns = 3; ArtworkWidth = 596; ArtworkHeight = 335; CellWidth = 620; CellHeight = 434 },
    @{ Columns = 2; ArtworkWidth = 906; ArtworkHeight = 510; CellWidth = 930; CellHeight = 609 }
)

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

function Write-Mask([string]$name, [int]$width, [int]$height, [string]$profile) {
    $directory = Join-Path $Root "images\masks\$profile"
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
    $radius = if ($profile -eq "hd") { 8 } else { 12 }
    Save-DownsampledBitmap $width $height {
        param($graphics, $scale)
        $path = New-RoundedPath 0 0 ($width * $scale) ($height * $scale) ($radius * $scale)
        try {
            $brush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::White)
            try { $graphics.FillPath($brush, $path) } finally { $brush.Dispose() }
        } finally { $path.Dispose() }
    } (Join-Path $directory $name)
}

function Write-Focus([hashtable]$spec, [string]$prefix, [string]$profile) {
    $directory = Join-Path $Root "images\library\$profile"
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
    $name = "$prefix-$($spec.Columns)-col-focus.png"
    $stroke = if ($profile -eq "hd") { 11 } else { 9 }
    $radius = if ($profile -eq "hd") { 16 } else { 15 }
    Save-DownsampledBitmap $spec.CellWidth $spec.CellHeight {
        param($graphics, $scale)
        $insetX = 16 * $scale
        $focusWidth = ($spec.ArtworkWidth + 11) * $scale
        if ($prefix -eq "thumbnail") {
            # Thumbnail cells leave less trailing canvas than Poster cells. End
            # the path at the canvas edge so its inset stroke remains complete.
            $focusWidth = ($spec.CellWidth - 17) * $scale
        }
        $focusHeight = ($spec.ArtworkHeight + 4) * $scale
        $path = New-RoundedPath $insetX 0 $focusWidth $focusHeight ($radius * $scale)
        try {
            $pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::White), ($stroke * $scale)
            try {
                $pen.Alignment = [System.Drawing.Drawing2D.PenAlignment]::Inset
                $graphics.DrawPath($pen, $path)
            } finally { $pen.Dispose() }
        } finally { $path.Dispose() }
    } (Join-Path $directory $name)
}

foreach ($profile in @("fhd", "hd")) {
    foreach ($spec in $posterSpecs) {
        $width = if ($profile -eq "hd") { [int]($spec.ArtworkWidth * 2 / 3) } else { $spec.ArtworkWidth }
        $height = if ($profile -eq "hd") { [int]($spec.ArtworkHeight * 2 / 3) } else { $spec.ArtworkHeight }
        Write-Mask "poster-$($spec.Columns)-col-mask.png" $width $height $profile
        Write-Focus $spec "poster" $profile
    }
    foreach ($spec in $thumbnailSpecs) {
        $width = if ($profile -eq "hd") { [int]($spec.ArtworkWidth * 2 / 3) } else { $spec.ArtworkWidth }
        $height = if ($profile -eq "hd") { [int]($spec.ArtworkHeight * 2 / 3) } else { $spec.ArtworkHeight }
        Write-Mask "thumbnail-$($spec.Columns)-col-mask.png" $width $height $profile
        Write-Focus $spec "thumbnail" $profile
    }
}

Write-Output "Generated Poster and Thumbnail mask/focus assets for FHD and HD."
