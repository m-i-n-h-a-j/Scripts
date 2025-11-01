param (
    [string]$fileName = ""
)
function Start-CpuRip {
    param (
        [string]$fileName,
        [string]$scale,
        [string]$start,
        [string]$end,
        [string]$title,
        [string]$preset,
        [string]$quality,
        [string]$audio
    )

    $crf = "crf=" + $quality + ":aq-mode=3"

    Write-Host "Starting MIN-RIP (SW)..."

    ffmpeg.exe -hide_banner -i "$fileName" -ss $start -to $end -map 0:v:0 `
        -vf $scale -c:v libx265 -preset $preset -x265-params $crf `
        -pix_fmt yuv420p10le -map $audio -c:a libopus -b:a 128k `
        -vbr on -application audio -ar 48000 -ac 2 `
        -metadata title="$title" -metadata:s:v title="HEVC-10bit" `
        -metadata:s:a title="OPUS-2CH - VBR(128kbps)" ".\cpu_${title}__${preset}__${quality}_output.mkv"
}


function Start-CpuRipAv1 {
    param (
        [string]$fileName,
        [string]$scale,
        [string]$start,
        [string]$end,
        [string]$title,
        [string]$quality,
        [string]$audio
    )

    Write-Host "Starting MIN-RIP (SW - AV1)..."

    ffmpeg -hide_banner -i "$fileName" -ss $start -to $end `
        -map 0:v:0 -c:v libsvtav1 -vf "$scale" -pix_fmt yuv420p10le `
        -preset -2 -crf $quality -map $audio -c:a libopus -b:a 128k `
        -vbr on -application audio -ar 48000 -ac 2 ".\av1_${title}__${preset}__${quality}_output.mkv"
}

function Start-GpuRip {
    param (
        [string]$fileName,
        [string]$scale,
        [string]$start,
        [string]$end,
        [string]$title,
        [string]$quality,
        [string]$audio
    )
    
    Write-Host "Starting MIN-RIP (HW)..."

    ffmpeg.exe -hide_banner -i "$fileName" -ss $start -to $end -c:v hevc_nvenc -map 0:v:0 `
        -map "$audio" -vf "$scale" -preset p7 -tune uhq -profile:v main10 -pix_fmt p010le `
        -rc vbr -cq $quality -b:v 0 -rc-lookahead 32 -lookahead_level auto -spatial_aq 1 `
        -temporal_aq 1 -aq-strength 8 -b_ref_mode each -unidir_b 0 -c:a libopus -b:a 128k `
        -vbr on -application audio -ar 48000 -metadata title="$title" `
        -metadata:s:v title="HEVC-10bit" -metadata:s:a title="OPUS-2CH - VBR(128kbps)" `
        -ac 2 ".\nvenc_${title}_${quality}_10bit.mkv"

} 

function Option {
    param (
        [string]$optionMessage
    )
    
    $isOption = Read-Host($optionMessage)
    if ($isOption -eq "y" -or $isOption -eq "Y") {
        return 1
    }
    elseif ($isOption -eq "n" -or $isOption -eq "N" -or $isOption -eq "") {
        return 0
    }
    else {
        Write-Host "Enter a valid option!"
        return Option($optionMessage)
    }
}

Clear-Host

if ([string]::IsNullOrWhiteSpace($fileName)) {
    $fileName = Read-Host "Enter the input video file name"
}
$scaleG = ""
$resG = Read-Host "Enter Resolution (e.g., 3840, 1920, 1280)"
$cropG = Read-Host "Want to crop? (e.g., 1920:800:0:140)"

if (Option("Is Horizontal Resolution(Y/N))")) {
    if ([string]::IsNullOrWhiteSpace($cropG)) {
        $scaleG = "scale=${resG}:-2"
    }
    else {
        $scaleG = "crop=${cropG},scale=${resG}:-2"
    }
}
else {
    if ([string]::IsNullOrWhiteSpace($cropG)) {
        $scaleG = "scale=-2:${resG}"
    }
    else {
        $scaleG = "crop=${cropG},scale=-2:${resG}"
    }
}

$qualityG = Read-Host "Enter Quality (18, 20, 22, 24, 26, 28)"
$audioChannelG = Read-Host "Enter the audio stream"
$startG = Read-Host "Start at"
$endG = Read-Host "End at"
$titleG = Read-Host "File name"
$audioG = "0:a:" + $audioChannelG


if (Option("Use GPU(Y/N)")) {
    Start-GpuRip -fileName "$fileName" -scale "$scaleG" `
        -start $startG -end $endG -title $titleG `
        -quality $qualityG -audio $audioG
}
elseif (Option("AV1 (Y/N)")) {
    Start-CpuRipAv1 -fileName "$fileName" -scale "$scaleG" `
        -start $startG -end $endG -title $titleG `
        -quality $qualityG -audio $audioG
}
else {
    $preset = Read-Host "Enter Preset (ultrafast, superfast, veryfast, faster, fast, medium, slow, slower, veryslow)"
  
    Start-CpuRip -fileName "$fileName" -scale $scaleG `
        -start $startG -end $endG -title $titleG -preset $preset `
        -quality $qualityG -audio $audioG
}