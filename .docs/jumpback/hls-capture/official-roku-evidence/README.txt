Official Jellyfin Roku reproduction, September 11, 2026.

Includes four FFmpeg logs, three timestamped FFmpeg cache playlist snapshots,
twelve video packet reports, verified comparison results, and the issue draft.
Capture filename timestamps are UTC; FFmpeg log filename times are EDT.

Paths, media title, item ID, ETag and output prefix were replaced with stable
placeholders. Packet SHA256 hashes, timestamps and durations are unchanged.
segment-N.ts in a playlist refers to segment number N; raw TS/media files are
not included. Cache playlists are NOT the HTTP playlists delivered to Roku.
Packet reports contain hashes and timing metadata, not encoded video payloads.

Compare packets-N.json arrays in order using data_hash and pts_time. All seven
pairs in packet-comparisons.json matched for every video packet and PTS.
Raw files and unmodified logs are preserved privately outside this archive.
The report still identifies unknown environment versions and evidence limits.
