# HealthWallet Windows Build Script
# Run this on a Windows machine with Flutter installed
# Usage: .\scripts\build_windows.ps1

param(
    [switch]$SkipCodegen,
    [switch]$Clean
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)

Write-Host "`n=== HealthWallet Windows Build ===" -ForegroundColor Cyan

# --- Prerequisites check ---
Write-Host "`n[1/6] Checking prerequisites..." -ForegroundColor Yellow

$flutter = Get-Command flutter -ErrorAction SilentlyContinue
if (-not $flutter) {
    Write-Host "ERROR: Flutter not found. Install Flutter and add it to PATH." -ForegroundColor Red
    exit 1
}

$flutterVersion = flutter --version 2>&1 | Select-String "Flutter (\d+\.\d+\.\d+)"
Write-Host "  Flutter: $($flutterVersion.Matches.Groups[1].Value)"

# Check Windows desktop is enabled
$devices = flutter devices 2>&1
if ($devices -notmatch "windows") {
    Write-Host "  Enabling Windows desktop support..."
    flutter config --enable-windows-desktop
}
Write-Host "  Windows desktop: enabled" -ForegroundColor Green

# --- Check .env ---
Write-Host "`n[2/6] Checking .env file..." -ForegroundColor Yellow
if (-not (Test-Path "$ProjectRoot\.env")) {
    Write-Host "WARNING: .env file not found. Build may fail if env vars are required." -ForegroundColor DarkYellow
    Write-Host "  Copy your .env file to: $ProjectRoot\.env"
} else {
    Write-Host "  .env found" -ForegroundColor Green
}

# --- Clean (optional) ---
if ($Clean) {
    Write-Host "`n[3/6] Cleaning previous build..." -ForegroundColor Yellow
    Set-Location $ProjectRoot
    flutter clean
    Write-Host "  Cleaned" -ForegroundColor Green
} else {
    Write-Host "`n[3/6] Skipping clean (use -Clean to force)" -ForegroundColor Gray
}

# --- Dependencies ---
Write-Host "`n[4/6] Getting dependencies..." -ForegroundColor Yellow
Set-Location $ProjectRoot
flutter pub get
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: flutter pub get failed" -ForegroundColor Red
    exit 1
}
Write-Host "  Dependencies resolved" -ForegroundColor Green

# --- Code generation ---
if (-not $SkipCodegen) {
    Write-Host "`n[5/6] Running code generation..." -ForegroundColor Yellow
    dart run build_runner build --delete-conflicting-outputs
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: Code generation failed" -ForegroundColor Red
        exit 1
    }
    Write-Host "  Code generation complete" -ForegroundColor Green
} else {
    Write-Host "`n[5/6] Skipping code generation (use without -SkipCodegen to run)" -ForegroundColor Gray
}

# --- Build ---
Write-Host "`n[6/6] Building Windows release..." -ForegroundColor Yellow
Set-Location $ProjectRoot
flutter build windows --release
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Build failed" -ForegroundColor Red
    exit 1
}

# --- Package output ---
$BuildOutput = "$ProjectRoot\build\windows\x64\runner\Release"
$Version = (Select-String -Path "$ProjectRoot\pubspec.yaml" -Pattern "^version:\s*(.+)$").Matches.Groups[1].Value.Trim()
$ZipName = "HealthWallet-Windows-v$Version.zip"
$ZipPath = "$ProjectRoot\build\$ZipName"

Write-Host "`nPackaging build output..." -ForegroundColor Yellow

if (Test-Path $ZipPath) {
    Remove-Item $ZipPath -Force
}

Compress-Archive -Path "$BuildOutput\*" -DestinationPath $ZipPath -Force
$SizeMB = [math]::Round((Get-Item $ZipPath).Length / 1MB, 1)

Write-Host "`n=== Build Complete ===" -ForegroundColor Green
Write-Host "  Output:  $BuildOutput" -ForegroundColor White
Write-Host "  Package: $ZipPath ($SizeMB MB)" -ForegroundColor White
Write-Host ""
Write-Host "To install: unzip and run health_wallet.exe" -ForegroundColor Cyan
Write-Host ""
