param (
    [string]$fileName = ""
)
function Start-Rip {
    param (
        [string]$fileName,
        [string]$res,
        [string]$preset,
        [string]$quality,
        [string]$audioChannel
    )

    $scale = "scale=" + $res + ":-2"
    $crf = "crf=" + $quality + ":aq-mode=3"
    $audio = "0:a:" + $audioChannel

    Clear-Host

    Write-Host "Starting MIN-RIP..."

    ffmpeg.exe -i "$fileName" -map 0:v:0 -vf $scale -c:v libx265 -preset $preset `
        -x265-params $crf -pix_fmt yuv420p10le -map $audio -c:a aac -b:a 192k -ac 2 ".\output.mkv"
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

    if (Option("Use GPU(Y/N)")) {
        Write-Host "Encoding with GPU"
        $res = Read-Host "Enter Horizontal Resolution (e.g., 3840, 1920, 1280)"
        $crop = Read-Host "Want to crop? 1920:800:0:140"
        $quality = Read-Host "Enter Quality (18, 20, 22, 24, 26, 28)"
        $audioChannel = Read-Host "Enter the audio stream"
        $scale = ""

        if ([string]::IsNullOrWhiteSpace($crop)) {
            $scale = "scale=${res}:-2,format=yuv420p"
        }
        else {
            $scale = "crop=${crop},scale=${res}:-2,format=yuv420p"
        }

        $audio = "0:a:" + $audioChannel

        Clear-Host
        Write-Host "Starting MIN-RIP (8-bit, CPU scale, explicit maps)..."

        ffmpeg.exe -i "$fileName"  -map 0:v:0 -map "$audio" -vf "$scale" `
            -c:v hevc_nvenc -preset p7 -rc vbr -cq $quality -tune hq -multipass fullres `
            -spatial-aq 1 -temporal-aq 1 -aq-strength 8 -rc-lookahead 32 `
            -c:a libopus -b:a 160k -ac 2 ".\output_nvenc_${quality}_8bit.mkv"


    }
    else {
        $res = Read-Host "Enter Horizontal Resolution (e.g., 1920 or 1280)"
        $preset = Read-Host "Enter Preset (ultrafast, superfast, veryfast, faster, fast, medium, slow, slower, veryslow)"
        $quality = Read-Host "Enter Quality (18, 20, 22, 24, 26, 28)"
        $audioChannel = Read-Host "Enter the audio stream"
    
    
        Start-Rip -fileName "$fileName" -res $res -preset $preset -quality $quality -audioChannel $audioChannel
    }
}
elseif (Option("Use GPU(Y/N)")) {
    Write-Host "Encoding with GPU"
    $res = Read-Host "Enter Horizontal Resolution (e.g., 3840, 1920, 1280)"
    $crop = Read-Host "Want to crop? 1920:800:0:140"
    $quality = Read-Host "Enter Quality (18, 20, 22, 24, 26, 28)"
    $audioChannel = Read-Host "Enter the audio stream"
    
    $scale = ""

    if ([string]::IsNullOrWhiteSpace($crop)) {
        $scale = "scale=${res}:-2,format=yuv420p"
    }
    else {
        $scale = "crop=${crop},scale=${res}:-2,format=yuv420p"
    }

    $audio = "0:a:" + $audioChannel

    Clear-Host
    Write-Host "Starting MIN-RIP (8-bit, CPU scale, explicit maps)..."

    ffmpeg.exe -i "$fileName" -map 0:v:0 -map "$audio" -vf "$scale" `
        -c:v hevc_nvenc -preset p7 -rc vbr -cq $quality -tune hq -multipass fullres `
        -spatial-aq 1 -temporal-aq 1 -aq-strength 8 -rc-lookahead 32 `
        -c:a libopus -b:a 160k -ac 2 ".\output_nvenc_${quality}_8bit.mkv"
}
else {   
    $res = Read-Host "Enter Horizontal Resolution (e.g., 1920 or 1280)"
    $preset = Read-Host "Enter Preset (ultrafast, superfast, veryfast, faster, fast, medium, slow, slower, veryslow)"
    $quality = Read-Host "Enter Quality (18, 20, 22, 24, 26, 28)"
    $audioChannel = Read-Host "Enter the audio stream"

    Start-Rip -fileName "$fileName" -res $res -preset $preset -quality $quality -audioChannel $audioChannel  
}