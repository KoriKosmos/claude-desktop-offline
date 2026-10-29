# Offline installer for the Claude desktop app on Windows. Works from a clone
# of this repo with no access to downloads.claude.ai: it uses the MSIX that
# mirror.sh stored under releases\ instead.
#
# Usage: powershell -ExecutionPolicy Bypass -File .\install.ps1 [latest|VERSION]
#
# Uses only cmdlets and native commands (no .NET calls), so it also runs in
# Constrained Language Mode. The MSIX installs per-user; no admin needed.

param(
    [Parameter(Position=0)]
    [ValidatePattern('^(latest|\d+\.\d+\.\d+)$')]
    [string]$Target = "latest"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# PROCESSOR_ARCHITEW6432 is set when 32-bit PowerShell runs on 64-bit Windows.
$arch = $env:PROCESSOR_ARCHITECTURE
if ($env:PROCESSOR_ARCHITEW6432) { $arch = $env:PROCESSOR_ARCHITEW6432 }
switch ($arch) {
    "ARM64" { $arch = "arm64" }
    "AMD64" { $arch = "x64" }
    default {
        Write-Error "Unsupported architecture: $arch"
        exit 1
    }
}

$ReleasesDir = Join-Path $PSScriptRoot "releases"

if ($Target -eq "latest") {
    $pointer = Join-Path $ReleasesDir "latest"
    if (-not (Test-Path $pointer)) {
        Write-Error "No version mirrored. Run mirror.sh first."
        exit 1
    }
    $version = (Get-Content -Raw $pointer).Trim()
} else {
    $version = $Target
}

$archDir = Join-Path (Join-Path $ReleasesDir $version) $arch
$checksumFile = Join-Path $archDir "checksum"
if (-not (Test-Path $checksumFile)) {
    Write-Error "Claude desktop $version for $arch is not in this mirror."
    exit 1
}

Write-Output "Installing Claude desktop $version ($arch)..."

$msixPath = Join-Path $env:TEMP "Claude-$version-$arch.msix"

# Join the parts with cmd's `copy /b`: fast, and needs no .NET.
$parts = @(Get-ChildItem -Path $archDir -Filter "Claude.msix.part-*" | Sort-Object Name | ForEach-Object { $_.Name })
Push-Location $archDir
try {
    & cmd /c copy /b /y ($parts -join "+") $msixPath | Out-Null
    $copyExitCode = $LASTEXITCODE
} finally {
    Pop-Location
}
if ($copyExitCode -ne 0 -or -not (Test-Path $msixPath)) {
    Write-Error "Could not join the MSIX parts in $archDir"
    exit 1
}

try {
    $checksum = (Get-Content -Raw $checksumFile).Trim()
    $actual = (Get-FileHash -Path $msixPath -Algorithm SHA256).Hash.ToLower()
    if ($actual -ne $checksum) {
        Write-Error "Checksum verification failed (is the clone complete?)"
        exit 1
    }

    $sig = Get-AuthenticodeSignature -FilePath $msixPath
    if ($sig.Status -ne "Valid" -or $sig.SignerCertificate.Subject -notmatch 'O="?Anthropic') {
        Write-Error "The MSIX is not validly signed by Anthropic (status: $($sig.Status))"
        exit 1
    }

    Add-AppxPackage -Path $msixPath -ForceApplicationShutdown
} finally {
    Remove-Item -Force -ErrorAction SilentlyContinue $msixPath
}

Write-Output ""
Write-Output "$([char]0x2705) Installation complete!"
Write-Output "Start Claude from the Start menu."
Write-Output ""
