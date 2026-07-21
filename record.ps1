# Screen recorder: 2880x1800@90 panel -> 1920x1200@60 AVC via ffmpeg ddagrab
# Usage:
#   .\record.ps1                      # Quick Sync zero-copy (default), record until you press q
#   .\record.ps1 -Encoder dgpu        # NVENC, until q — best while gaming (encode off the iGPU)
#   .\record.ps1 -Encoder cpu -Seconds 30 -OutFile clip.mp4
param(
    [ValidateSet('cpu', 'igpu', 'dgpu')] [string]$Encoder = 'igpu',
    [ValidateSet(800, 1200, 1600, 1800)] [int]$Resolution = 1200,   # output height, 16:10 like the panel; 1800 = native (no scaling)
    [int]$Seconds = 0,
    [string]$OutFile = '',
    [switch]$NoAudio   # system audio via the enabled "Stereo Mix" endpoint; captures only what plays through the Realtek output (speakers/jack, not Bluetooth)
)

$ffmpeg = (Get-Command ffmpeg).Source

# One-time per-exe-path setup, re-applied automatically if ffmpeg's path changes (e.g. winget upgrade).
# 1) GpuPreference=1 (power saving / Intel iGPU): on this hybrid laptop the panel is owned by the
#    Intel adapter, but processes default to the NVIDIA GPU, which makes Desktop Duplication fail
#    with DXGI_ERROR_UNSUPPORTED. 2) HIGHDPIAWARE: DuplicateOutput1 needs DPI awareness at 175% scaling.
$prefKey = 'HKCU:\Software\Microsoft\DirectX\UserGpuPreferences'
if (-not (Test-Path $prefKey)) { New-Item $prefKey -Force | Out-Null }
if ((Get-ItemProperty $prefKey -Name $ffmpeg -ErrorAction SilentlyContinue).$ffmpeg -ne 'GpuPreference=1;') {
    Set-ItemProperty $prefKey -Name $ffmpeg -Value 'GpuPreference=1;'
}
$layers = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers'
if (-not (Test-Path $layers)) { New-Item $layers -Force | Out-Null }
if ((Get-ItemProperty $layers -Name $ffmpeg -ErrorAction SilentlyContinue).$ffmpeg -notmatch 'HIGHDPIAWARE') {
    Set-ItemProperty $layers -Name $ffmpeg -Value '~ HIGHDPIAWARE'
}

if (-not $OutFile) {
    $outDir = Join-Path $HOME 'Videos\Screen-Recordings'
    if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Force $outDir | Out-Null }
    $OutFile = Join-Path $outDir ("record-{0}-{1}p-{2}.mp4" -f $Encoder, $Resolution, (Get-Date -Format 'yyyyMMdd-HHmmss'))
}

# Capture at the panel's native 90 Hz, resample to exact CFR 60 (capturing at 60 directly
# lands at ~58 fps due to Windows timer granularity).
# Scaling/format conversion happens ON the iGPU via vpp_qsv (ddagrab's D3D11 frames mapped into
# QSV): downloading raw 90fps 2880x1800 BGRA to the CPU (~1.8 GB/s) capped capture at ~45-48 fps
# regardless of scaler flags. igpu encodes fully zero-copy; cpu/dgpu download the already-scaled
# NV12 frames (~6x less readback). NVENC can't take these frames directly — CUDA can't interop
# with the Intel-owned D3D11 device on this Optimus setup, so dgpu goes through system memory.
$width = [int]($Resolution * 16 / 10)
$vpp = if ($Resolution -eq 1800) { 'vpp_qsv=format=nv12' } else { "vpp_qsv=w=${width}:h=${Resolution}:format=nv12" }
$vfCommon = "hwmap=derive_device=qsv,$vpp,fps=60"
switch ($Encoder) {
    'cpu' { $vf = "$vfCommon,hwdownload,format=nv12"; $enc = @('-c:v', 'libx264', '-preset', 'faster', '-crf', '15') }
    'igpu' { $vf = $vfCommon; $enc = @('-c:v', 'h264_qsv', '-global_quality', '15') }
    'dgpu' { $vf = "$vfCommon,hwdownload,format=nv12"; $enc = @('-c:v', 'h264_nvenc', '-preset', 'p5', '-rc', 'vbr', '-cq', '15', '-b:v', '0') }
}

$ffArgs = @('-hide_banner', '-y', '-f', 'lavfi', '-i', 'ddagrab=framerate=90')
if (-not $NoAudio) {
    $ffArgs += @('-f', 'dshow', '-audio_buffer_size', '50', '-i', 'audio=Stereo Mix (Realtek(R) Audio)')
}
$ffArgs += @('-vf', $vf) + $enc
if (-not $NoAudio) { $ffArgs += @('-c:a', 'aac', '-b:a', '192k') }
if ($Seconds -gt 0) { $ffArgs += @('-t', "$Seconds") } else { Write-Host "Recording... press q in this window to stop." }
$ffArgs += $OutFile

# The fps=60 filter always emits perfect CFR — when capture falls behind it pads the gaps with
# duplicated frames, so the container reads 60 fps even for a lagged recording. The only reliable
# lag signal is the fps filter's own "frames duplicated" summary, which it prints only at
# -v verbose. FFREPORT tees a verbose log to a temp file without touching console output
# (path needs ffmpeg's option escaping: forward slashes, drive colon escaped).
$fpsLog = Join-Path $env:TEMP 'record-ffreport.log'
Remove-Item $fpsLog -Force -ErrorAction SilentlyContinue
$env:FFREPORT = 'file={0}:level=40' -f (($fpsLog -replace '\\', '/') -replace ':', '\:')

& $ffmpeg @ffArgs

Remove-Item Env:\FFREPORT

Write-Host "`n--- Verification: $OutFile ---"
$probe = ffprobe -v error -count_frames -select_streams v:0 `
    -show_entries "stream=width,height,nb_read_frames : format=duration" -of default=nw=1 $OutFile
$probe
ffprobe -v error -select_streams a:0 -show_entries "stream=codec_name,sample_rate,channels" -of default=nw=1 $OutFile
$frames = [int]   ($probe | Select-String 'nb_read_frames=(\d+)').Matches[0].Groups[1].Value
$duration = [double]($probe | Select-String 'duration=([\d.]+)').Matches[0].Groups[1].Value
$fps = [math]::Round($frames / $duration, 2)

# Container fps is only a sanity check (catches truncated/broken files) — it reads ~60 even when
# capture lagged, because fps=60 fills gaps with duplicates.
if ([math]::Abs($fps - 60) -gt 0.5) {
    Write-Host ("WARNING: container is {0} fps ({1} frames / {2}s), expected 60 - truncated or broken file?" -f $fps, $frames, $duration)
}

# Real check: the fps filter's frames-in rate. The verdict keys on capture fps, not dup count:
# on a static/low-motion screen ddagrab's timeout-based dup pacing delivers only ~70 fps (Windows
# timer granularity again) and the 90Hz->60fps grid mismatch adds jitter dups, so ~15-20% duplicated
# frames are normal even for a healthy pipeline. What matters is whether ddagrab was drained at
# >=60 fps — then every frame of 60fps screen content was sampled. Below 60, content was missed.
# First summary in the report is a zero-frame filter-init instance; take the last one with frames > 0.
$stats = Select-String -Path $fpsLog -Pattern '(\d+) frames in, (\d+) frames out; (\d+) frames dropped, (\d+) frames duplicated' |
Where-Object { [int]$_.Matches[0].Groups[1].Value -gt 0 } | Select-Object -Last 1
Remove-Item $fpsLog -Force -ErrorAction SilentlyContinue
if (-not $stats) {
    Write-Host 'WARNING: fps filter summary not found in ffmpeg report - cannot verify capture lag'
}
else {
    $g = $stats.Matches[0].Groups
    $in = [int]$g[1].Value; $out = [int]$g[2].Value; $dup = [int]$g[4].Value
    $captureFps = [math]::Round($in / $duration, 1)
    $dupPct = [math]::Round(100.0 * $dup / $out, 1)
    Write-Host ("Capture: {0} frames from ddagrab ({1} fps); {2} of {3} output frames duplicated ({4}%)" -f $in, $captureFps, $dup, $out, $dupPct)
    if ($captureFps -ge 60) {
        Write-Host ("OK: pipeline kept up ({0} fps captured; duplicates are sampling jitter, not lag)" -f $captureFps)
    }
    else {
        Write-Host ("WARNING: capture lagged - only {0} unique fps from ddagrab (need >=60); {1} output frames ({2}%) are duplicated padding" -f $captureFps, $dup, $dupPct)
    }
}
