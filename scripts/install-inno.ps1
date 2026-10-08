# Make ISCC.exe available on a machine that does not have Inno Setup yet.
# Tries Chocolatey, then the official installer, in that order. CI uses this.
$ErrorActionPreference = 'Continue'

if ((Get-Command ISCC.exe -ErrorAction SilentlyContinue) -or
    (Get-ChildItem "$env:LOCALAPPDATA\Programs\Inno Setup*\ISCC.exe" -ErrorAction SilentlyContinue)) {
  Write-Host 'Inno Setup already present'
  exit 0
}

if (Get-Command choco.exe -ErrorAction SilentlyContinue) {
  Write-Host 'installing Inno Setup via Chocolatey'
  choco install innosetup --no-progress -y
  if ($LASTEXITCODE -eq 0) { exit 0 }
  Write-Host "choco install failed ($LASTEXITCODE); falling back to the official installer"
}

$exe = Join-Path $env:TEMP 'innosetup.exe'
Write-Host "downloading $exe"
Invoke-WebRequest -Uri 'https://jrsoftware.org/download.php/is.exe' -OutFile $exe -UseBasicParsing
Start-Process -FilePath $exe -ArgumentList '/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/CURRENTUSER' -Wait
if (Test-Path "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe") { exit 0 }
Write-Host 'Inno Setup installation could not be verified' -ForegroundColor Yellow
exit 1
