Get-ChildItem -Directory | ForEach-Object {
    if ($_.Name -match '^(\d{2})-(\d{2})-(\d{4})') {
        
        $month = [int]$matches[2]
        $year = $matches[3]

        $monthName = (Get-Culture).DateTimeFormat.GetMonthName($month)

        if ( $year -eq "2025") {
            $destination = Join-Path $PWD "$year\$monthName"

            if (!(Test-Path $destination)) {
                New-Item -ItemType Directory -Path $destination -Force | Out-Null
            }

            Move-Item $_.FullName -Destination $destination
        }
    }
}