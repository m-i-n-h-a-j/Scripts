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

    $AudID = Read-Host "Enter the Audio ID"
    if ($AudID -eq "") {
        $AudID = "ba/b"
    }

    Clear-Host

    yt-dlp.exe -f $AudID --cookies-from-browser firefox -N 4 `
        -P "$HOME\Music" -x --embed-thumbnail `
        --embed-metadata -o "%(title)s.%(ext)s" "$URL"
}

function DownloadVideo {
    param (
        [string]$URL
    )
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
        yt-dlp.exe -f $VidID+$AudID --cookies-from-browser firefox -N 4 `
            -P "$HOME\Downloads" -t mkv `
            --write-subs --write-auto-subs --sub-langs "en" `
            --embed-subs --compat-options no-keep-subs `
            --embed-thumbnail --embed-metadata --embed-chapters `
            --sponsorblock-mark all -o "%(title)s.%(ext)s" "$URL"
    }
    else {
        Clear-Host
        yt-dlp.exe -f $VidID+$AudID --cookies-from-browser firefox -N 4 `
            -P "$HOME\Downloads" -t mkv --embed-thumbnail --embed-metadata `
            --embed-chapters --sponsorblock-mark all -o "%(title)s.%(ext)s" "$URL"
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

        $lines = & yt-dlp.exe "ytsearch5:$keyword" --cookies-from-browser firefox `
            --print "%(id)s`t%(title)s"

        $printMsg = ""
        [string[]] $urls = @()

        $j = 1
        foreach ($line in $lines) {
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            $id, $vidName = ($line -split "`t", 2)
            $urls += "https://youtu.be/$id"
            $printMsg += "$j - $vidName`n"
            $j++
        }

        if ($urls.Count -eq 0) {
            Write-Host "No results found for '$keyword'." -ForegroundColor Red
            exit 1
        }

        Write-Host $printMsg -ForegroundColor Green

        $Vno = 0
        while ($true) {
            $choice = Read-Host "Enter the video number"
            if ([int]::TryParse($choice, [ref]$Vno) -and $Vno -ge 1 -and $Vno -le $urls.Count) {
                break
            }
            Write-Host "❌ Invalid selection. Please pick a number between 1 and $($urls.Count)." -ForegroundColor Red
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
