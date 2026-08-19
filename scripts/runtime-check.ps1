[CmdletBinding()]
param()

$ErrorActionPreference = 'Continue'

function Write-Row([string]$Name, [string]$Value) {
    Write-Host ('  {0,-22} {1}' -f $Name, $Value)
}

Write-Host 'Day 19 - container runtime check' -ForegroundColor Cyan
Write-Row 'host' ([Environment]::OSVersion.VersionString)
Write-Row 'PowerShell' $PSVersionTable.PSVersion.ToString()
Write-Host ''

$haveCompose = $false
$havePodman = $false

Write-Host 'docker' -ForegroundColor Cyan
if (Get-Command docker -ErrorAction SilentlyContinue) {
    Write-Row 'version' ((& docker --version 2>&1 | Select-Object -First 1) -as [string])
    & docker compose version *> $null
    if ($LASTEXITCODE -eq 0) {
        $haveCompose = $true
        Write-Row 'compose v2' ((& docker compose version 2>&1 | Select-Object -First 1) -as [string])
    } else {
        Write-Row 'compose v2' 'MISSING (install/update Docker Desktop)'
    }
    & docker info *> $null
    if ($LASTEXITCODE -eq 0) {
        Write-Row 'daemon' 'running'
    } else {
        Write-Row 'daemon' 'NOT running - start Docker Desktop'
        $haveCompose = $false
    }
} else {
    Write-Row 'version' 'not installed'
}
Write-Host ''

Write-Host 'podman' -ForegroundColor Cyan
if (Get-Command podman -ErrorAction SilentlyContinue) {
    $havePodman = $true
    Write-Row 'version' ((& podman --version 2>&1 | Select-Object -First 1) -as [string])
    & podman compose version *> $null
    if ($LASTEXITCODE -eq 0 -or (Get-Command podman-compose -ErrorAction SilentlyContinue)) {
        Write-Row 'compose' 'available'
    } else {
        Write-Row 'compose' 'missing (install podman-compose)'
    }
} else {
    Write-Row 'version' 'not installed'
}
Write-Host ''

Write-Host 'apple container' -ForegroundColor Cyan
Write-Row 'availability' 'unsupported on Windows (Apple silicon/macOS 26+ only)'
Write-Host ''

Write-Host 'recommended path' -ForegroundColor Cyan
if ($haveCompose) {
    Write-Host '  .\setup-docker.ps1       # Docker Compose, full stack'
} elseif ($havePodman) {
    Write-Host '  podman compose up -d      # then configure/run the Docker path'
} else {
    Write-Host '  .\setup-lite.ps1         # no container runtime required'
    Write-Host '  (lite covers every graded core criterion)'
}
