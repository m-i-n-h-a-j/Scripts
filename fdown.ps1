param (
    [Parameter(Mandatory = $true)]
    [string]$URL
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

$ConfPath = Join-Path $ScriptDir 'aria2.conf'

if (-Not (Test-Path $ConfPath)) {
    Write-Warning "Configuration file not found at `$ConfPath`. aria2c will run with its defaults."
}

Clear-Host

Set-Location ~/Downloads

& aria2c.exe --conf-path="$ConfPath" $URL