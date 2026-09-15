# Jumpback evidence

Collected evidence for the Jellyfin HLS ending-replay issue, consolidated here on September 15, 2026.

- [GitHub issue draft](github_issue/jellyfin-bug-report.md) and [prepared evidence ZIP](github_issue/jellyfin-12-official-roku-hls-replay-evidence.zip): the existing submission materials. The draft is an unchanged copy of the sanitized draft in `hls-capture/official-roku-evidence/`.
- `hls-capture/`: all original captures, packet reports, source snapshots, scripts, and original issue drafts, formerly in `C:\dev\starfin-roku\out\hls-capture`. The prepared ZIP was moved into `github_issue/`.
- [Current candidate-fix experiment report](server-experiments/DIRECT-RESULTS.md): direct-start restart checks and latency results. All server experiments were moved from `tests/Jellyfin.MediaEncoding.Hls.Tests/bin/hls-jumpback` into `server-experiments/`, including the historical results for the rejected earlier-processing approach.
- [Evidence manifest](evidence-manifest.json): original relative paths, sizes, and SHA-256 hashes for all 1,784 relocated files. `Group` identifies the destination subfolder, except the ZIP now located under `github_issue/`.

Existing evidence contents were preserved. Historical absolute paths, script defaults, and project references still describe their original locations; this relocation does not rewrite or rerun archived scripts. The issue draft and ZIP were not regenerated to include the later candidate-fix experiments.

## Git tracking and local evidence

Reports, the issue draft and ZIP, diagnostic JSON, packet hashes, logs, playlists, source snapshots, scripts, and the evidence manifest are versioned in Git. Captured .ts and .mp4 media and generated bin/ and obj/ directories under this folder are ignored and remain on this machine at their existing paths.

A clone or GitHub download contains only the versioned subset. Back up this complete folder separately to preserve the raw evidence. The manifest covers both tracked and local-only original files. Archived scripts may depend on local-only media or rebuilt dependencies.
