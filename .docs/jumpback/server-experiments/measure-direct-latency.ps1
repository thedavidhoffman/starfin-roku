$ErrorActionPreference = 'Stop'
$plans = Get-Content -Raw "$PSScriptRoot/direct-restart-plans.json" | ConvertFrom-Json
$movie = 'D:/Jellyfin Media Library/movies/20,000 Leagues Under the Sea/20,000 Leagues Under the Sea.mp4'
$rows = foreach ($container in @('mpegts', 'fmp4')) {
    foreach ($target in @(726, 991, 1011)) {
        $plan = $plans[$target].Plan
        $dir = "$PSScriptRoot/direct-latency-$container-$target"
        New-Item -ItemType Directory -Path $dir | Out-Null
        $ext = if ($container -eq 'mpegts') { 'ts' } else { 'mp4' }
        $seek = ($plan.SeekTimeTicks / 10000000).ToString('0.000', [Globalization.CultureInfo]::InvariantCulture)
        $duration = ($plan.SegmentLengthTicks / 10000000).ToString('0.000000', [Globalization.CultureInfo]::InvariantCulture)
        $formatArgs = if ($container -eq 'fmp4') { @('-hls_fmp4_init_filename', 'init.mp4', '-hls_segment_options', 'movflags=+frag_discont+skip_sidx') } else { @('-bsf:v', 'h264_mp4toannexb') }
        $ffargs = @('-hide_banner', '-loglevel', 'error', '-nostdin', '-ss', $seek, '-t', '30', '-fflags', '+genpts', '-i', ('"' + $movie + '"'), '-map', '0:0', '-map', '0:1', '-c:v', 'copy', '-start_at_zero', '-c:a', 'libmp3lame', '-ac', '2', '-ab', '256000', '-af', 'volume=2', '-copyts', '-avoid_negative_ts', 'disabled', '-f', 'hls', '-max_delay', '5000000', '-hls_time', $duration, '-hls_segment_type', $container) + $formatArgs + @('-start_number', $target, '-hls_segment_filename', ('"' + "$dir/%d.$ext" + '"'), '-hls_playlist_type', 'vod', '-hls_list_size', '0', ('"' + "$dir/out.m3u8" + '"'))
        $info = [Diagnostics.ProcessStartInfo]::new()
        $info.FileName = 'C:/Program Files/Jellyfin/Server/ffmpeg.exe'
        $info.Arguments = $ffargs -join ' '
        $info.UseShellExecute = $false
        $info.CreateNoWindow = $true
        $info.RedirectStandardError = $true
        $process = [Diagnostics.Process]::new()
        $process.StartInfo = $info
        $watch = [Diagnostics.Stopwatch]::StartNew()
        $null = $process.Start()
        $errorTask = $process.StandardError.ReadToEndAsync()
        # Opening the following segment means HLS has flushed/closed the requested one.
        $nextFile = "$dir/$($target + 1).$ext"
        while (-not $process.HasExited -and -not (Test-Path -LiteralPath $nextFile)) {
            if ($watch.Elapsed.TotalSeconds -gt 30) { $process.Kill(); throw 'Timed out waiting for requested segment' }
            Start-Sleep -Milliseconds 20
        }
        $readySeconds = $watch.Elapsed.TotalSeconds
        $process.WaitForExit()
        $errorTask.Result | Set-Content "$dir/ffmpeg.log"
        if ($process.ExitCode -ne 0 -or -not (Test-Path "$dir/$target.$ext")) { throw "FFmpeg failed at $target" }
        $process.Dispose()
        [pscustomobject]@{ Container = $container; Target = $target; StartNumber = $plan.SegmentIndex; PrecedingMediaSeconds = 0; FirstCompleteSegmentWallSeconds = $readySeconds }
    }
}
$rows | ConvertTo-Json | Set-Content "$PSScriptRoot/direct-latency-results.json"
$rows | ConvertTo-Json
