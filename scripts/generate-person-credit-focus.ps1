param([string]$Root = "")

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing
if ([string]::IsNullOrWhiteSpace($Root)) { $Root = Split-Path -Parent $PSScriptRoot }
$Root = [System.IO.Path]::GetFullPath($Root)

# Preserve the existing RowList-compensated outlines exactly. Only the transparent
# item canvas grows to accommodate the third text line; artwork never scales.
foreach ($profile in @("fhd", "hd")) {
    foreach ($spec in @(
        @{ Source = "home-page-poster-focus.png"; Target = "person-credit-poster-focus.png"; Height = 501 },
        @{ Source = "person-episode-focus.png"; Target = "person-credit-episode-focus.png"; Height = 384 }
    )) {
        $directory = Join-Path $Root "images/homepage/$profile"
        $source = [System.Drawing.Bitmap]::FromFile((Join-Path $directory $spec.Source))
        try {
            $canvas = New-Object System.Drawing.Bitmap $source.Width, $spec.Height, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
            try {
                $graphics = [System.Drawing.Graphics]::FromImage($canvas)
                try {
                    $graphics.Clear([System.Drawing.Color]::Transparent)
                    $graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
                    # Explicit pixel rectangles avoid DrawImageUnscaled's physical-DPI scaling.
                    $pixels = New-Object System.Drawing.Rectangle 0, 0, $source.Width, $source.Height
                    $graphics.DrawImage($source, $pixels, 0, 0, $source.Width, $source.Height, [System.Drawing.GraphicsUnit]::Pixel)
                } finally { $graphics.Dispose() }
                $canvas.Save((Join-Path $directory $spec.Target), [System.Drawing.Imaging.ImageFormat]::Png)
            } finally { $canvas.Dispose() }
        } finally { $source.Dispose() }
    }
}
