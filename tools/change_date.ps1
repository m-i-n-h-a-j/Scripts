param([Parameter(Mandatory = $true)][string]$Path)

$f = Get-Item -LiteralPath $Path
$now = Get-Date

$f.CreationTime = $now
$f.LastWriteTime = $now
$f.LastAccessTime = $now
