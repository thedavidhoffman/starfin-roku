param(
    [string]$Root = (Get-Location).Path
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

foreach ($resolution in @("fhd", "hd")) {
    $maskPath = Join-Path $Root "images\masks\$resolution\account-badge-user-mask.png"
    $mattePath = Join-Path $Root "images\header\$resolution\account-badge-matte.png"
    $ringPath = Join-Path $Root "images\header\$resolution\account-badge-ring.png"
    $glassPath = Join-Path $Root "images\header\$resolution\account-badge-glass.png"
    $ringOverlayPath = Join-Path $Root "images\header\$resolution\account-badge-ring-overlay.png"
    $glassOverlayPath = Join-Path $Root "images\header\$resolution\account-badge-glass-overlay.png"
    $mask = [System.Drawing.Bitmap]::FromFile($maskPath)
    $matte = New-Object System.Drawing.Bitmap $mask.Width, $mask.Height, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)

    for ($y = 0; $y -lt $mask.Height; $y++) {
        for ($x = 0; $x -lt $mask.Width; $x++) {
            $maskAlpha = $mask.GetPixel($x, $y).A
            $matte.SetPixel($x, $y, [System.Drawing.Color]::FromArgb((255 - $maskAlpha), 255, 255, 255))
        }
    }

    $matte.Save($mattePath, [System.Drawing.Imaging.ImageFormat]::Png)
    $matte.Dispose()

    $frameOffset = [int]($mask.Width / 32)
    foreach ($frameSpec in @(@($ringPath, $ringOverlayPath), @($glassPath, $glassOverlayPath))) {
        $frame = [System.Drawing.Bitmap]::FromFile($frameSpec[0])
        $overlay = New-Object System.Drawing.Bitmap $frame.Width, $frame.Height, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        for ($y = 0; $y -lt $frame.Height; $y++) {
            for ($x = 0; $x -lt $frame.Width; $x++) {
                $maskX = $x - $frameOffset
                $maskY = $y - $frameOffset
                $maskAlpha = 0
                if ($maskX -ge 0 -and $maskX -lt $mask.Width -and $maskY -ge 0 -and $maskY -lt $mask.Height) {
                    $maskAlpha = $mask.GetPixel($maskX, $maskY).A
                }
                $frameAlpha = $frame.GetPixel($x, $y).A
                $overlayAlpha = [int][Math]::Round($frameAlpha * (255 - $maskAlpha) / 255)
                $overlay.SetPixel($x, $y, [System.Drawing.Color]::FromArgb($overlayAlpha, 255, 255, 255))
            }
        }
        $overlay.Save($frameSpec[1], [System.Drawing.Imaging.ImageFormat]::Png)
        $overlay.Dispose()
        $frame.Dispose()
        Write-Output "Generated $($frameSpec[1])"
    }

    $mask.Dispose()
    Write-Output "Generated $mattePath"
}
