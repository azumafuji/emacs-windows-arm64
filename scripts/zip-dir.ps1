# Wrap a directory in a .zip, preserving the top-level folder name.
param(
  [Parameter(Mandatory = $true)][string]$Source,
  [Parameter(Mandatory = $true)][string]$Destination
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
if (Test-Path $Destination) { Remove-Item $Destination -Force }
[System.IO.Compression.ZipFile]::CreateFromDirectory(
  (Resolve-Path $Source).Path, $Destination,
  [System.IO.Compression.CompressionLevel]::Optimal, $true)
$zip = [System.IO.Compression.ZipFile]::OpenRead($Destination)
$entries = $zip.Entries.Count
$zip.Dispose()
Write-Host ("zip written: {0} ({1:N1} MB, {2} entries)" -f $Destination, ((Get-Item $Destination).Length / 1MB), $entries)
