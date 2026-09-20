<#
.SYNOPSIS
    Automates bumping app version, tagging, and triggering GitHub Release for VISAAIA.

.EXAMPLE
    .\scripts\release.ps1
    .\scripts\release.ps1 -Notes "Fixed issue with dashboard"
    .\scripts\release.ps1 -Version "2.0.3" -Notes "Major update"
#>

param (
    [Parameter(Mandatory = $false, Position = 0, HelpMessage = "Optional release notes")]
    [string]$Notes = "",

    [Parameter(Mandatory = $false, HelpMessage = "New semantic version (e.g. 2.0.3). If omitted, keeps current version.")]
    [string]$Version = "",

    [Parameter(Mandatory = $false, HelpMessage = "New build number (e.g. 16). If omitted, auto-increments by 1.")]
    [int]$Build = 0,

    [Parameter(Mandatory = $false)]
    [switch]$BuildLocal = $false
)

$ErrorActionPreference = "Stop"

# Always ensure working directory is project root
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $projectRoot

# 1. Read current pubspec.yaml
$pubspecPath = Join-Path $projectRoot "pubspec.yaml"
if (-not (Test-Path $pubspecPath)) {
    Write-Error "Could not find pubspec.yaml at $pubspecPath"
    exit 1
}

$content = Get-Content $pubspecPath -Raw
if ($content -match "version:\s*([0-9\.]+)\+([0-9]+)") {
    $currentVersion = $matches[1]
    $currentBuild = [int]$matches[2]
}
else {
    Write-Error "Could not parse version from pubspec.yaml"
    exit 1
}

# Auto-calculate Version and Build if not provided
if ([string]::IsNullOrWhiteSpace($Version)) {
    $Version = $currentVersion
}

if ($Build -le 0) {
    $Build = $currentBuild + 1
}

if ([string]::IsNullOrWhiteSpace($Notes)) {
    $Notes = "Release v$Version+$Build"
}

Write-Host ""
Write-Host "=========================================================" -ForegroundColor Green
Write-Host " [VISAAIA Auto-Release Manager]" -ForegroundColor Green
Write-Host " Current Version : v$currentVersion (Build: $currentBuild)" -ForegroundColor DarkGray
Write-Host " New Version     : v$Version (Build: $Build) [Auto-Incremented]" -ForegroundColor Cyan
Write-Host " Release Notes   : $Notes" -ForegroundColor Gray
Write-Host "=========================================================" -ForegroundColor Green
Write-Host ""

# 2. Update pubspec.yaml
Write-Host "[1/4] Updating pubspec.yaml to $Version+$Build..." -ForegroundColor Yellow
$newVersionLine = "version: $Version+$Build"
$updatedContent = $content -replace "version:\s*[0-9\.\+]+", $newVersionLine
Set-Content -Path $pubspecPath -Value $updatedContent
Write-Host "      Done!" -ForegroundColor Green

# 3. Local Build (optional)
if ($BuildLocal) {
    Write-Host "[2/4] Building Release APK locally..." -ForegroundColor Yellow
    flutter build apk --release
    Write-Host "      Local APK ready at: build/app/outputs/flutter-apk/app-release.apk" -ForegroundColor Green
}
else {
    Write-Host "[2/4] Skipping local build (GitHub Actions will build it in the cloud)" -ForegroundColor DarkGray
}

$tagName = "v$Version+$Build"

# 4. Git Commit and Tag
Write-Host "[3/4] Staging changes and creating tag $tagName..." -ForegroundColor Yellow
git add .
git commit -m "chore(release): bump version to $Version+$Build - $Notes"
git tag -a "$tagName" -m "$Notes"
Write-Host "      Done!" -ForegroundColor Green

# 5. Push to GitHub
Write-Host "[4/4] Pushing code & tag to origin..." -ForegroundColor Yellow
git push
git push origin "$tagName"
Write-Host "      Done!" -ForegroundColor Green

Write-Host ""
Write-Host "SUCCESS: Release $tagName published to GitHub!" -ForegroundColor Green
Write-Host "GitHub Actions is now automatically building the APK with permanent keystore." -ForegroundColor Cyan
Write-Host ""
Write-Host "Direct APK Download URL:" -ForegroundColor White
Write-Host "https://github.com/kheypaxu/visaia/releases/latest/download/visaia-release.apk" -ForegroundColor Yellow
Write-Host ""
