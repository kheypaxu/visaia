<#
.SYNOPSIS
    Automates bumping app version, building, tagging, and triggering GitHub Release for VISAAIA.

.EXAMPLE
    .\scripts\release.ps1 -Version "2.0.1" -Build 12 -Notes "Bug fixes and monitoring enhancements"
#>

param (
    [Parameter(Mandatory = $true, HelpMessage = "New semantic version (e.g. 2.0.1)")]
    [string]$Version,

    [Parameter(Mandatory = $true, HelpMessage = "New build number / versionCode (e.g. 12)")]
    [int]$Build,

    [Parameter(Mandatory = $false)]
    [string]$Notes = "Release v$Version",

    [Parameter(Mandatory = $false)]
    [switch]$BuildLocal = $false
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "[VISAAIA Release Manager]" -ForegroundColor Green
Write-Host "Target Version: v$Version (Build: $Build)" -ForegroundColor Cyan
Write-Host "Release Notes : $Notes" -ForegroundColor Gray
Write-Host "---------------------------------------------------------"

# 1. Update pubspec.yaml
$pubspecPath = Join-Path $PSScriptRoot "..\pubspec.yaml"
if (Test-Path $pubspecPath) {
    Write-Host "[1/4] Updating pubspec.yaml..." -ForegroundColor Yellow
    $content = Get-Content $pubspecPath -Raw
    $newVersionLine = "version: $Version+$Build"
    $updatedContent = $content -replace "version:\s*[0-9\.\+]+", $newVersionLine
    Set-Content -Path $pubspecPath -Value $updatedContent
    Write-Host "      Set pubspec.yaml to '$newVersionLine'" -ForegroundColor Green
} else {
    Write-Error "Could not find pubspec.yaml at $pubspecPath"
    exit 1
}

# 2. Local Build (optional)
if ($BuildLocal) {
    Write-Host "[2/4] Building Release APK locally..." -ForegroundColor Yellow
    flutter build apk --release
    Write-Host "      Local APK ready at: build/app/outputs/flutter-apk/app-release.apk" -ForegroundColor Green
} else {
    Write-Host "[2/4] Skipping local build (GitHub Actions will build it)" -ForegroundColor DarkGray
}

$tagName = "v$Version+$Build"

# 3. Git Commit and Tag
Write-Host "[3/4] Committing and creating tag $tagName..." -ForegroundColor Yellow
git add pubspec.yaml
git commit -m "chore(release): bump version to $Version+$Build"
git tag -a "$tagName" -m "$Notes"

# 4. Push to GitHub
Write-Host "[4/4] Pushing changes and tag to origin..." -ForegroundColor Yellow
git push
git push origin "$tagName"

Write-Host ""
Write-Host "SUCCESS: Release $tagName published to GitHub!" -ForegroundColor Green
Write-Host "GitHub Actions is now automatically building your APK and creating the release." -ForegroundColor Cyan
Write-Host ""
Write-Host "Direct APK Download URL (Permanent):" -ForegroundColor White
Write-Host "https://github.com/kheypaxu/visaia/releases/latest/download/visaia-release.apk" -ForegroundColor Yellow
Write-Host ""
