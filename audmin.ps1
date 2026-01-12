Get-ChildItem -Filter *.flac | ForEach-Object {
    $inputFile = $_.FullName
    $base = [System.IO.Path]::GetFileNameWithoutExtension($inputFile)
    $outputName = "$base.opus"

    Write-Host "Converting $inputFile → $outputName"

    ffmpeg -i "$inputFile" -map 0:a -map 0:v? `
        -c:v copy -ar 48000 -ac 2 -c:a libopus `
        -b:a 192k -compression_level 10 `
        -vbr on -application audio `
        -map_metadata 0 "$outputName" -y
}