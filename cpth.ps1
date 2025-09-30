param (
    [string]$path
)

function GetMainFolder {

    $mFolderName = Read-Host "Main folder name"

    if (Option("Use auto date(Y/N)")) {
        $date = (Get-Date).ToString("dd-MM-yyyy")
        return $date + ' ' + $mFolderName
    }
    else {
        return (Read-Host "Enter the date(DD-MM-YYYY)") + ' ' + $mFolderName
    }
}

function Option {
    param (
        [string]$optionMessage
    )
    
    $isOption = Read-Host($optionMessage)
    if ($isOption -eq "y" -or $isOption -eq "Y") {
        return 1
    }
    elseif ($isOption -eq "n" -or $isOption -eq "N") {
        return 0
    }
    else {
        Write-Host "Enter a valid option!`n"
        return Option($optionMessage)
    }
}

function TrimmedPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FullPath
    )

    $marker = '\iBankCBS\'
    
    $idx = $FullPath.IndexOf($marker, [System.StringComparison]::InvariantCultureIgnoreCase)

    if ($idx -ge 0) {
        return $FullPath.Substring($idx + $marker.Length)
    }
    else {
        return $FullPath
    }
}

if ($path -eq "") {
    $path = Read-Host "Enter path"
}

if ($path.Length -lt 5) {
    $path = $path.Substring(0, 2)
    Set-Location $path
}
else {
    Set-Location $path
}

Write-Host "Folder will be created on :- " $path "`n"

$mainPath = GetMainFolder
mkdir $mainPath
Set-Location $mainPath

$folder = Read-Host "Enter the folder name"

$trmPath = TrimmedPath -FullPath $folder
mkdir $trmPath
Write-Host ""

while (1) {
    if (Option("Create another folder(Y/N)")) {
        Write-Host ""
        $new_folder = Read-Host "Folder name"
        $trimmedPath = TrimmedPath -FullPath $new_folder
        mkdir $trimmedPath
    }
    else {
        break;
    }
}
