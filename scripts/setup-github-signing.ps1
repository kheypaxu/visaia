<#
.SYNOPSIS
    Copies existing Android signing values for the one-time GitHub Actions setup.
.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\setup-github-signing.ps1
.EXAMPLE
    .\scripts\setup-github-signing.ps1 -SecretName ANDROID_KEYSTORE_BASE64
#>
[CmdletBinding()]
param (
    [ValidateSet('ANDROID_KEYSTORE_BASE64', 'ANDROID_KEYSTORE_PASSWORD', 'ANDROID_KEY_ALIAS', 'ANDROID_KEY_PASSWORD')]
    [string]$SecretName,
    [switch]$Check
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$propertiesPath = Join-Path $projectRoot 'android/key.properties'
$keystorePath = Join-Path $projectRoot 'android/app/release-key.jks'

if (!(Test-Path -LiteralPath $propertiesPath) -or !(Test-Path -LiteralPath $keystorePath)) {
    throw 'Your private android/key.properties and android/app/release-key.jks files must be present. This helper never creates a replacement key.'
}

$properties = @{}
foreach ($line in [IO.File]::ReadAllLines($propertiesPath)) {
    if ($line -match '^\s*(storePassword|keyAlias|keyPassword)\s*=(.*)$') {
        $properties[$matches[1]] = $matches[2].Trim()
    }
}
foreach ($key in @('storePassword', 'keyAlias', 'keyPassword')) {
    if ([string]::IsNullOrWhiteSpace($properties[$key])) {
        throw "The local key.properties file has no value for $key."
    }
}

$values = [ordered]@{
    ANDROID_KEYSTORE_BASE64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($keystorePath))
    ANDROID_KEYSTORE_PASSWORD = $properties['storePassword']
    ANDROID_KEY_ALIAS = $properties['keyAlias']
    ANDROID_KEY_PASSWORD = $properties['keyPassword']
}

if ($Check) {
    Write-Host 'All four signing values are available. No values were displayed, copied, or uploaded.'
    return
}

if ($SecretName) {
    Set-Clipboard -Value $values[$SecretName]
    Write-Host "$SecretName value copied. Paste it into that GitHub repository secret's Secret field."
    return
}

Write-Host 'Open: https://github.com/kheypaxu/visaia/settings/secrets/actions'
Write-Host 'Keep the Secrets tab selected. Add each name below as a repository secret, not a variable.'
Write-Host 'This helper copies existing values only. It does not build, upload, commit, or change your signing key.'
$lastCopied = $null
try {
    foreach ($name in $values.Keys) {
        Write-Host ""
        Write-Host "GitHub secret name: $name" -ForegroundColor Cyan
        $null = Read-Host 'Click New repository secret, enter this Name, then press Enter here to copy its value'
        Set-Clipboard -Value $values[$name]
        $lastCopied = $values[$name]
        Write-Host 'Value copied. Paste into the Secret field in GitHub, then click Add secret.'
        $null = Read-Host 'After saving it in GitHub, press Enter to continue'
    }
    Write-Host ""
    Write-Host 'Confirm GitHub lists all four secret names. Then commit/push the prepared workflow changes before your next release.'
} finally {
    # Avoid retaining the last password; preserve anything else the user copied.
    if ($null -ne $lastCopied -and (Get-Clipboard -Raw) -eq $lastCopied) {
        Set-Clipboard -Value ''
    }
}
