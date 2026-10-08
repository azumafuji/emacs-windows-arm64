# Compile the Inno Setup installer for one variant.
#
#   powershell -File scripts/build-installer.ps1 -Variant portable
#
# Substitutes installer/emacs.iss.in and runs ISCC. ISCC is located on PATH, in
# a per-user Inno Setup install, or in Program Files, in that order.
param(
  [Parameter(Mandatory = $true)][ValidateSet('portable', 'native')][string]$Variant,
  [string]$Root = '',
  [string]$Iscc = ''
)

$ErrorActionPreference = 'Stop'

# $PSScriptRoot is NOT available in a param() block: parameter binding happens
# before the automatic variables are set, so a default of
# (Split-Path -Parent $PSScriptRoot) silently yields an empty string.
# Resolve it here instead, and let the caller pass -Root explicitly.
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $Root) { $Root = Split-Path -Parent $scriptDir }

$VERSION = '31.1'
$meta = @{
  portable = @{
    AppName  = 'GNU Emacs (portable ARM64)'
    AppDir   = "emacs-$VERSION"
    AppId    = 'B7A5E9C2-3F4D-4E8B-9C1A-6D2F0B7E4A31'
    OutBase  = "emacs-$VERSION-aarch64-setup"
    Desc     = "GNU Emacs $VERSION for Windows on ARM64 (portable-optimised)"
    Folder   = "emacs-$VERSION-aarch64"
  }
  native = @{
    AppName  = 'GNU Emacs (native ARM64)'
    AppDir   = "emacs-$VERSION-native"
    AppId    = 'C4E1A7D9-6B23-4F58-8A0D-1E9C3F5B2D74'
    OutBase  = "emacs-$VERSION-aarch64-native-setup"
    Desc     = "GNU Emacs $VERSION for this ARM64 PC (native-optimised)"
    Folder   = "emacs-$VERSION-aarch64-native"
  }
}[$Variant]

$sourceDir = Join-Path $Root "work\portable\$($meta.Folder)"
if (-not (Test-Path (Join-Path $sourceDir 'bin\emacs.exe'))) {
  throw "portable tree not found at $sourceDir - run scripts/05-package-portable.sh $Variant first"
}

# Icon: taken from the Emacs source tree (same licence as everything else here).
$iconLine = ''
$srcIcon = Join-Path $Root 'work\emacs\nt\icons\emacs.ico'
if (Test-Path $srcIcon) {
  $iconDir = Join-Path $Root 'work'
  New-Item -ItemType Directory -Force -Path $iconDir | Out-Null
  $icon = Join-Path $iconDir 'emacs.ico'
  Copy-Item $srcIcon $icon -Force
  $iconLine = "SetupIconFile=$icon"
}

$outDir = Join-Path $Root 'dist'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$generated = Join-Path $Root 'installer\generated'
New-Item -ItemType Directory -Force -Path $generated | Out-Null

$template = Get-Content (Join-Path $scriptDir '..\installer\emacs.iss.in') -Raw
$iss = $template.
  Replace('@@APPNAME@@',   $meta.AppName).
  Replace('@@VERSION@@',   $VERSION).
  Replace('@@APPID@@',     $meta.AppId).
  Replace('@@APPDIR@@',    $meta.AppDir).
  Replace('@@OUTBASE@@',   $meta.OutBase).
  Replace('@@DESC@@',      $meta.Desc).
  Replace('@@SOURCEDIR@@', $sourceDir).
  Replace('@@OUTDIR@@',    $outDir).
  Replace('@@ICONLINE@@',  $iconLine)
$issPath = Join-Path $generated "$Variant.iss"
Set-Content -Path $issPath -Value $iss -Encoding UTF8

if (-not $Iscc) {
  $Iscc = (Get-Command ISCC.exe -ErrorAction SilentlyContinue).Source
}
if (-not $Iscc) {
  foreach ($pattern in @(
      "$env:LOCALAPPDATA\Programs\Inno Setup*\ISCC.exe",
      "${env:ProgramFiles(x86)}\Inno Setup*\ISCC.exe",
      "$env:ProgramFiles\Inno Setup*\ISCC.exe")) {
    $hit = Get-ChildItem $pattern -ErrorAction SilentlyContinue | Sort-Object FullName -Descending | Select-Object -First 1
    if ($hit) { $Iscc = $hit.FullName; break }
  }
}
if (-not $Iscc -or -not (Test-Path $Iscc)) {
  throw "ISCC.exe not found. Install Inno Setup 6.3+ (winget install JRSoftware.InnoSetup) or pass -Iscc <path>."
}

Write-Host "compiling $issPath with $Iscc"
# ISCC writes its progress to stderr, and with $ErrorActionPreference = 'Stop' a
# native command's stderr can be promoted to a terminating error. Relax it for this
# one call and check the exit code explicitly instead.
$prevEap = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
& $Iscc "/O$outDir" $issPath 2>&1 | Out-Host
$isccExit = $LASTEXITCODE
$ErrorActionPreference = $prevEap
if ($isccExit -ne 0) { throw "ISCC failed with exit code $isccExit" }
Write-Host "installer written to $outDir\$($meta.OutBase).exe"
