Get-ChildItem -Filter *.flac | ForEach-Object {
    $inputFile = $_.FullName
    $base = [System.IO.Path]::GetFileNameWithoutExtension($inputFile)
    $outputName = "$base.opus"

    Write-Host "Converting $inputFile → $output"

    ffmpeg -i "$inputFile" -ar 48000 -ac 2 -c:a libopus `
        -b:a 192k -compression_level 10 -frame_duration 20 `
        -vbr on -application audio -map_metadata 0 "$outputName" -y
}