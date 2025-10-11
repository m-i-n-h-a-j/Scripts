param (
    [string]$argURL
)

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

function DownloadAudio {
    param (
        [string]$URL
    )

    Set-Location ~\Music
    $AudID = Read-Host "Enter the Audio ID"
    if ($AudID -eq "") {
        $AudID = "ba/b"
    }
    Clear-Host

    yt-dlp.exe -f $AudID --cookies-from-browser firefox `
        -x --audio-format m4a --audio-quality 0 --embed-thumbnail --add-metadata `
        -o "%(title)s.%(ext)s" "$URL" `
        --exec 'powershell -NoProfile -ExecutionPolicy Bypass -File "C:\Other\Scripts\tools\change_date.ps1" {}'
}

function DownloadVideo {
    param (
        [string]$URL
    )
    Set-Location ~\Downloads
    $VidID = Read-Host "Enter the Video ID"
    if ($VidID -eq "") {
        $VidID = "bv"
    }

    $AudID = Read-Host "Enter the Audio ID"
    if ($AudID -eq "") {
        $AudID = "ba/b"
    }

    if (Option("Embed sub(Y/N)")) {
        Clear-Host
        yt-dlp.exe -f $VidID+$AudID --cookies-from-browser firefox `
            --write-subs --write-auto-subs --convert-subs srt --sub-lang en `
            --embed-subs --merge-output-format mp4 --embed-thumbnail `
            --embed-metadata --embed-chapters --compat-options no-keep-subs `
            -o "%(title)s.%(ext)s" "$URL"
    }
    else {
        Clear-Host
        yt-dlp.exe -f $VidID+$AudID --cookies-from-browser firefox --merge-output-format mp4 `
            --embed-thumbnail --embed-metadata --embed-chapters -o "%(title)s.%(ext)s" "$URL"
    }
}
function StartDownload {
    param(
        [string]$URL
    )
   

    Clear-Host

    yt-dlp.exe -F --cookies-from-browser firefox "$URL"
        
    if (Option("Download audio only(Y/N)")) {
        
        DownloadAudio($URL)
    }
    else {
        
        DownloadVideo($URL)
    }
}
function validateURL {
    param(
        [string]$URL
    )
    if ($URL -eq "" -or $URL.length -lt 8) {
        Write-Host ""
        Write-Host "Enter a valid URL!"
        $URL = Read-Host "Enter URL"
        validateURL($URL)
    }
    else {
        StartDownload($URL)
    }
}


Clear-Host

if ($argURL -eq "") {

    if (Option("Search on YouTube(Y/N)")) {
        Clear-Host
        $keyword = Read-Host "Search"

        Write-Host "Fetching titles and URLs..."

        $lines = & yt-dlp.exe "ytsearch5:$keyword" --cookies-from-browser firefox --skip-download --get-title --get-id
        $printMsg = ""
        [string[]] $urls = @()     

        $j = 1
        for ($i = 0; $i -lt $lines.Count; $i += 2) {
            $urls += $lines[$i + 1].Trim()
              
            $vidName = $lines[$i].Trim()
            $printMsg += "$j - $vidName`n"
            $j++
        }

        $urls = $urls | ForEach-Object { "https://youtu.be/$_" }
        
        Write-Host $printMsg

        $Vno = [int](Read-Host "Enter the video number")
        if ($Vno -lt 1 -or $Vno -gt $urls.Count) {
            Write-Host "❌ Invalid selection. Please pick a number between 1 and $($urls.Count)." -ForegroundColor Red
            $Vno = [int](Read-Host "Enter the video number")
        }
          
        
        $searchURL = $urls[$Vno - 1]

        yt-dlp.exe -F --cookies-from-browser firefox $searchURL

        if (Option("Download audio only(Y/N)")) {
            DownloadAudio($searchURL)
        }
        else {
            DownloadVideo($searchURL)
        }
    }
    else {
        Clear-Host
        $argURL = Read-Host "Enter URL"
        validateURL($argURL)
    }
}
else {
    validateURL($argURL)
}
