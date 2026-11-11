# Builds the Windows desktop app with the Flutter version pinned in .fvmrc and packages it as a
# portable zip and, with -Msix, a Store MSIX, in build\windows\packages\. The CI job
# windows:release runs this script.
#
# Needs: Git for Windows, Visual Studio 2022 with "Desktop development with C++", FVM on PATH
# (`choco install fvm`, or `dart pub global activate fvm`), and SSH access to
# git.lifevalue.com (port 2822) for the private packages (CI rewrites them to HTTPS with its job token).
#
# Usage: .\scripts\build_windows.ps1 [-Msix] [-SkipCodegen] [-Clean]

param(
    [switch]$Msix,
    [switch]$SkipCodegen,
    [switch]$Clean
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $ProjectRoot

function Invoke-Step([string]$Description, [scriptblock]$Command) {
    Write-Host "`n==> $Description" -ForegroundColor Cyan
    & $Command
    if ($LASTEXITCODE -ne 0) { throw "$Description failed (exit code $LASTEXITCODE)" }
}

if (-not (Get-Command fvm -ErrorAction SilentlyContinue)) {
    throw "FVM not found. Install it (choco install fvm) and open a new shell."
}
$FlutterVersion = (Get-Content .fvmrc -Raw | ConvertFrom-Json).flutter

# Installs the pinned version when missing; FVM then runs it for this project.
Invoke-Step "Flutter $FlutterVersion (from .fvmrc)" { fvm install --skip-pub-get }
Invoke-Step "Windows desktop enabled" { fvm flutter config --enable-windows-desktop }

if (-not (Test-Path .env)) {
    Write-Warning ".env not found: the app builds with the default (empty) configuration."
}

if ($Clean) { Invoke-Step "Clean" { fvm flutter clean } }
Invoke-Step "Dependencies" { fvm flutter pub get --enforce-lockfile }
if (-not $SkipCodegen) {
    Invoke-Step "Code generation" { fvm dart run build_runner build --delete-conflicting-outputs }
}
Invoke-Step "Windows release build" {
    fvm flutter build windows --release --target lib/main_desktop.dart
}

$Version = (Select-String -Path pubspec.yaml -Pattern '^version:\s*([^+\s]+)').Matches[0].Groups[1].Value
$Release = "build\windows\x64\runner\Release"
$Out = "build\windows\packages"
if (Test-Path $Out) { Remove-Item $Out -Recurse -Force }
New-Item -ItemType Directory -Path $Out | Out-Null

# A package left from an earlier run would end up in the zip.
Get-ChildItem -Path $Release -Filter "*.msix" | Remove-Item -Force

$Zip = "$Out\HealthWallet-Windows-v$Version-portable.zip"
Write-Host "`n==> Portable zip" -ForegroundColor Cyan
Compress-Archive -Path "$Release\*" -DestinationPath $Zip -Force
Write-Host $Zip

if ($Msix) {
    # msix_config in pubspec.yaml; the Store signs the package.
    Invoke-Step "MSIX" { fvm dart run msix:create --version "$Version.0" }
    $Package = Get-ChildItem -Path $Release -Filter "*.msix" | Select-Object -First 1
    $MsixOut = "$Out\HealthWallet-Windows-v$Version-setup.msix"
    Copy-Item $Package.FullName $MsixOut
    Write-Host $MsixOut
}

Write-Host "`nDone: unzip the portable build and run health_wallet.exe." -ForegroundColor Green
