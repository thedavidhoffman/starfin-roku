param(
    [string]$SourceFile = 'D:/Jellyfin Media Library/movies/20,000 Leagues Under the Sea/20,000 Leagues Under the Sea.mp4',
    [string]$OutputRoot = $PSScriptRoot
)
$ErrorActionPreference = 'Stop'
$ffmpeg = 'C:/Program Files/Jellyfin/Server/ffmpeg.exe'
$ffprobe = 'C:/Program Files/Jellyfin/Server/ffprobe.exe'
$plans = Get-Content -Raw (Join-Path $PSScriptRoot 'direct-restart-plans.json') | ConvertFrom-Json
$results = [System.Collections.Generic.List[object]]::new()
foreach ($container in @('mpegts', 'fmp4')) {
    foreach ($requested in @(991, 992, 1009, 1011)) {
        $plan = $plans[$requested].Plan
        $dir = Join-Path $OutputRoot "verify-$container-$requested"
        New-Item -ItemType Directory -Path $dir -ErrorAction Stop | Out-Null
        $ext = if ($container -eq 'mpegts') { 'ts' } else { 'mp4' }
        $seek = ([double]$plan.SeekTimeTicks / 10000000).ToString('0.000', [Globalization.CultureInfo]::InvariantCulture)
        $formatArgs = if ($container -eq 'fmp4') { @('-hls_fmp4_init_filename', 'init.mp4', '-hls_segment_options', 'movflags=+frag_discont+skip_sidx') } else { @('-bsf:v', 'h264_mp4toannexb') }
        & $ffmpeg -hide_banner -loglevel error -nostdin -ss $seek -fflags +genpts -i $SourceFile -map 0:0 -map 0:1 -c:v copy -start_at_zero -c:a libmp3lame -ac 2 -ab 256000 -af volume=2 -copyts -avoid_negative_ts disabled -max_muxing_queue_size 2048 -f hls -max_delay 5000000 -hls_time (($plan.SegmentLengthTicks / 10000000).ToString('0.000000', [Globalization.CultureInfo]::InvariantCulture)) -hls_segment_type $container @formatArgs -start_number $plan.SegmentIndex -hls_segment_filename "$dir/%d.$ext" -hls_playlist_type vod -hls_list_size 0 "$dir/out.m3u8" 2> "$dir/ffmpeg.log"
        if ($LASTEXITCODE -ne 0) { throw "FFmpeg failed: $dir" }
        $lines = Get-Content "$dir/out.m3u8"
        $durations = @($lines | Where-Object { $_.StartsWith('#EXTINF:') } | ForEach-Object { [double]::Parse($_.Substring(8).TrimEnd(','), [Globalization.CultureInfo]::InvariantCulture) })
        if ($durations.Count -ne ($plans.Count - $plan.SegmentIndex)) { throw "Wrong segment count: $dir" }
        $videoPackets = 0
        $previousPts = -1.0
        for ($i = 0; $i -lt $durations.Count; $i++) {
            $index = $plan.SegmentIndex + $i
            $expected = $plans[$index]
            if ([Math]::Abs($durations[$i] - $expected.Duration) -gt 0.001) { throw "Wrong duration at $dir segment $index" }
            $inputFile = if ($container -eq 'fmp4') { "concat:$dir/init.mp4|$dir/$index.mp4" } else { "$dir/$index.ts" }
            $raw = & $ffprobe -v error -select_streams v:0 -show_entries packet=pts_time,data_hash -show_data_hash sha256 -of json $inputFile
            if ($LASTEXITCODE -ne 0) { throw "FFprobe failed: $inputFile" }
            $raw | Set-Content "$dir/packets-$index.json"
            $packets = ($raw | ConvertFrom-Json).packets
            $firstPts = [double]::Parse($packets[0].pts_time, [Globalization.CultureInfo]::InvariantCulture)
            $offset = if ($container -eq 'mpegts') { 10 } else { 0 }
            if ([Math]::Abs($firstPts - $offset - ($expected.RequestedTicks / 10000000)) -gt 0.001) { throw "Wrong first video PTS at $dir segment $index : $firstPts" }
            if ($firstPts -le $previousPts) { throw "Repeated segment timeline: $dir" }
            $previousPts = $firstPts
            $videoPackets += $packets.Count
        }
        $results.Add([pscustomobject]@{ Container = $container; Requested = $requested; Started = $plan.SegmentIndex; Segments = $durations.Count; VideoPackets = $videoPackets; LastSegment = $plans.Count - 1; AllBoundariesMatch = $true })
    }
}
$results | ConvertTo-Json | Set-Content (Join-Path $OutputRoot 'verification-results.json')
$results | ConvertTo-Json

