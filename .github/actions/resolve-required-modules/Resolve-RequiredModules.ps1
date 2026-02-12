# Resolves and installs/imports RequiredModules from a module manifest.
# Run from the repository root (workspace). ManifestPath is relative to current location.
param(
    [Parameter(Mandatory = $true)]
    [string]$ManifestPath
)

$ErrorActionPreference = 'Stop'
$resolvedManifestPath = Resolve-Path -Path $ManifestPath -ErrorAction Stop

$manifestData = Import-PowerShellDataFile -Path $resolvedManifestPath
$requiredModules = $manifestData.RequiredModules

if (-not $requiredModules) {
    Write-Host 'No RequiredModules in manifest.' -ForegroundColor Cyan
    return
}

$unresolved = @()
$repoRoot = Get-Location
$parent = Split-Path $resolvedManifestPath -Parent

foreach ($req in $requiredModules) {
    $reqName = $null
    if ($req -is [string]) { $reqName = $req }
    elseif ($req -is [hashtable]) {
        if ($req.ContainsKey('ModuleName')) { $reqName = $req.ModuleName }
        elseif ($req.ContainsKey('Name')) { $reqName = $req.Name }
        else { $reqName = $req.Values | Select-Object -First 1 }
    }
    elseif ($req -is [psobject]) {
        $reqName = if ($req.PSObject.Properties['ModuleName']) { $req.ModuleName }
                   elseif ($req.PSObject.Properties['Name']) { $req.Name }
                   else { $req.PSObject.Properties | Select-Object -First 1 -ExpandProperty Value }
    }
    if (-not $reqName) { continue }

    if (Get-Module -ListAvailable -Name $reqName) {
        Write-Host "Required module '$reqName' already available." -ForegroundColor Green
        continue
    }

    Write-Host "Required module '$reqName' not found. Attempting to install from PSGallery..." -ForegroundColor Yellow
    try {
        Install-Module -Name $reqName -Force -Scope CurrentUser -AllowClobber -ErrorAction Stop
        Write-Host "Installed '$reqName' from PSGallery." -ForegroundColor Green
        continue
    } catch {
        Write-Host "PSGallery install failed for '$reqName'. Trying local paths." -ForegroundColor Yellow
    }

    $candidates = @(
        (Join-Path $parent $reqName)
        (Join-Path $parent "$reqName\$reqName.psd1")
        (Join-Path $repoRoot $reqName)
        (Join-Path $repoRoot "modules\$reqName\$reqName.psd1")
        (Join-Path $repoRoot "modules\$reqName")
    )
    $imported = $false
    foreach ($cand in $candidates) {
        if (Test-Path $cand) {
            $p = Resolve-Path -Path $cand
            Write-Host "Importing dependency '$reqName' from: $p" -ForegroundColor Cyan
            Import-Module -Name $p -Force -ErrorAction Stop
            $imported = $true
            break
        }
    }
    if (-not $imported) {
        Write-Warning "Could not resolve required module '$reqName'."
        $unresolved += $reqName
    }
}

if ($unresolved.Count -gt 0) {
    $names = $unresolved -join ', '
    Write-Error "Required module(s) could not be resolved: $names"
    throw "Required module(s) could not be resolved: $names"
}

Write-Host 'All RequiredModules resolved successfully.' -ForegroundColor Green
