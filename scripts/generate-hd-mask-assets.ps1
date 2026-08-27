param(
    [string]$SourceRoot = "",
    [string]$OutputRoot = ""
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

if ([string]::IsNullOrWhiteSpace($SourceRoot)) {
    $SourceRoot = Split-Path -Parent $PSScriptRoot
}
if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
    $OutputRoot = $SourceRoot
}

$SourceRoot = [System.IO.Path]::GetFullPath($SourceRoot)
$OutputRoot = [System.IO.Path]::GetFullPath($OutputRoot)
$fhdDirectory = Join-Path $OutputRoot "images\masks\fhd"
$hdDirectory = Join-Path $OutputRoot "images\masks\hd"
New-Item -ItemType Directory -Force -Path $fhdDirectory, $hdDirectory | Out-Null

$assets = @(
    @{ Source = "images\header\account-badge-user-mask-96x96.png"; Name = "account-badge-user-mask.png"; Width = 96; Height = 96 },
    @{ Source = "images\header\account-menu-user-mask-144x144.png"; Name = "account-menu-user-mask.png"; Width = 144; Height = 144 },
    @{ Source = "images\cast\cast-mask-195x195.png"; Name = "cast-mask.png"; Width = 195; Height = 195 },
    @{ Source = "images\cast\person-mask-399x600.png"; Name = "person-mask.png"; Width = 399; Height = 600 },
    @{ Source = "images\cast\filmography-movie-mask-342x513.png"; Name = "filmography-movie-mask.png"; Width = 342; Height = 513 },
    @{ Source = "images\media-card\poster-mask-252x378.png"; Name = "media-card-poster-mask.png"; Width = 252; Height = 378 },
    @{ Source = "images\media-card\thumbnail-mask-441x249.png"; Name = "media-card-thumbnail-mask.png"; Width = 441; Height = 249 },
    @{ Source = "images\media-card\jumbo-mask-882x496.png"; Name = "media-card-jumbo-mask.png"; Width = 882; Height = 496 },
    @{ Source = "images\media-card\detailed-poster-mask-288x432.png"; Name = "detailed-poster-mask.png"; Width = 288; Height = 432 },
    @{ Source = "images\media-card\detailed-card-mask-882x496.png"; Name = "detailed-card-mask.png"; Width = 882; Height = 496 },
    @{ Source = "images\music\album-mask-300x300.png"; Name = "album-mask-300.png"; Width = 300; Height = 300 },
    @{ Source = "images\music\album-mask-342x342.png"; Name = "album-mask-342.png"; Width = 342; Height = 342 },
    @{ Source = "images\music\audio-player-album-mask-651x651.png"; Name = "audio-player-album-mask.png"; Width = 651; Height = 651 },
    @{ Source = "images\overlays\media-shell-backdrop-mask.png"; Name = "media-shell-backdrop-mask.png"; Width = 1152; Height = 648 },
    @{ Source = "images\trickplay\preview-center-mask.png"; Name = "trickplay-center-mask.png"; Width = 384; Height = 216 },
    @{ Source = "images\trickplay\preview-side-mask.png"; Name = "trickplay-side-mask.png"; Width = 225; Height = 126 },
    @{ Source = "images\tv-season\episode-thumbnail-mask-531x300.png"; Name = "episode-thumbnail-mask.png"; Width = 531; Height = 300 },
    @{ Source = "images\tv-show\season-poster-mask-207x312.png"; Name = "season-poster-mask.png"; Width = 207; Height = 312 }
)

foreach ($asset in $assets) {
    $sourcePath = Join-Path $SourceRoot $asset.Source
    $fhdPath = Join-Path $fhdDirectory $asset.Name
    $hdPath = Join-Path $hdDirectory $asset.Name
    Copy-Item -LiteralPath $sourcePath -Destination $fhdPath -Force

    $source = [System.Drawing.Bitmap]::FromFile($sourcePath)
    try {
        if ($source.Width -ne $asset.Width -or $source.Height -ne $asset.Height) {
            throw "$($asset.Source) must be $($asset.Width)x$($asset.Height)"
        }

        $hdWidth = [int]($asset.Width * 2 / 3)
        $hdHeight = [int]($asset.Height * 2 / 3)
        $hd = New-Object System.Drawing.Bitmap $hdWidth, $hdHeight, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        try {
            $graphics = [System.Drawing.Graphics]::FromImage($hd)
            try {
                $graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
                $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
                $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
                $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
                $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
                $graphics.DrawImage($source, 0, 0, $hdWidth, $hdHeight)
            } finally {
                $graphics.Dispose()
            }
            $hd.Save($hdPath, [System.Drawing.Imaging.ImageFormat]::Png)
        } finally {
            $hd.Dispose()
        }
    } finally {
        $source.Dispose()
    }
}

Write-Output "Generated $($assets.Count) FHD/HD mask pairs."
