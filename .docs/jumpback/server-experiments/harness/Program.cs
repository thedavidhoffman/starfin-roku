using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Text.Json;
using Jellyfin.MediaEncoding.Hls.Playlist;
using Jellyfin.MediaEncoding.Keyframes;

var ticks = JsonSerializer.Deserialize<double[]>(File.ReadAllText(args[0]))!
    .Select(seconds => Convert.ToInt64(seconds * TimeSpan.TicksPerSecond)).ToArray();
var data = new KeyframeData(76214547880, ticks);
var segmentsMethod = typeof(DynamicHlsPlaylistGenerator).GetMethod("ComputeSegments", BindingFlags.NonPublic | BindingFlags.Static)!;
var restartMethod = typeof(DynamicHlsPlaylistGenerator).GetMethod("ComputeVideoCopyRestart", BindingFlags.NonPublic | BindingFlags.Static)!;
var segments = (IReadOnlyList<double>)segmentsMethod.Invoke(null, [data, 6000])!;
var results = new List<object>();
long start = 0;
for (var i = 0; i < segments.Count; i++)
{
    var plan = (HlsVideoCopyRestart)restartMethod.Invoke(null, [data, 6000, i, start])!;
    results.Add(new { RequestedIndex = i, RequestedTicks = start, Duration = segments[i], Plan = plan });
    start += Convert.ToInt64(segments[i] * TimeSpan.TicksPerSecond);
}
File.WriteAllText(args[1], JsonSerializer.Serialize(results, new JsonSerializerOptions { WriteIndented = true }));
Console.WriteLine($"Computed {results.Count} restart plans using the modified server assembly.");
