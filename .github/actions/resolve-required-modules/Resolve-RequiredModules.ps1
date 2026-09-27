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

function Get-RequirementValue {
    param($Requirement, [string]$Key)
    if ($Requirement -is [hashtable]) {
        if ($Requirement.ContainsKey($Key)) { return $Requirement[$Key] }
        return $null
    }
    if ($Requirement -is [psobject] -and $Requirement.PSObject.Properties[$Key]) {
        return $Requirement.$Key
    }
    return $null
}

function Test-VersionInRange {
    param([version]$Version, $Minimum, $Required, $Maximum)
    if ($Required) { return $Version -eq [version]$Required }
    if ($Minimum -and $Version -lt [version]$Minimum) { return $false }
    if ($Maximum -and $Version -gt [version]$Maximum) { return $false }
    return $true
}

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

    # Honour the version the manifest asks for: a cached older copy must not count as available
    $minimumVersion = Get-RequirementValue -Requirement $req -Key 'ModuleVersion'
    $requiredVersion = Get-RequirementValue -Requirement $req -Key 'RequiredVersion'
    $maximumVersion = Get-RequirementValue -Requirement $req -Key 'MaximumVersion'
    $versionText = if ($requiredVersion) { " $requiredVersion" }
                   elseif ($minimumVersion -and $maximumVersion) { " $minimumVersion-$maximumVersion" }
                   elseif ($minimumVersion) { " $minimumVersion or later" }
                   elseif ($maximumVersion) { " $maximumVersion or earlier" }
                   else { '' }

    $matching = @(Get-Module -ListAvailable -Name $reqName | Where-Object {
            Test-VersionInRange -Version $_.Version -Minimum $minimumVersion -Required $requiredVersion -Maximum $maximumVersion
        })
    if ($matching.Count -gt 0) {
        Write-Host "Required module '$reqName'$versionText already available ($($matching[0].Version))." -ForegroundColor Green
        continue
    }

    Write-Host "Required module '$reqName'$versionText not found. Attempting to install from PSGallery..." -ForegroundColor Yellow
    $installParameters = @{
        Name         = $reqName
        Force        = $true
        Scope        = 'CurrentUser'
        AllowClobber = $true
        ErrorAction  = 'Stop'
    }
    if ($requiredVersion) { $installParameters['RequiredVersion'] = $requiredVersion }
    else {
        if ($minimumVersion) { $installParameters['MinimumVersion'] = $minimumVersion }
        if ($maximumVersion) { $installParameters['MaximumVersion'] = $maximumVersion }
    }
    try {
        Install-Module @installParameters
        Write-Host "Installed '$reqName'$versionText from PSGallery." -ForegroundColor Green
        continue
    } catch {
        Write-Host "PSGallery install failed for '$reqName'$versionText. Trying local paths." -ForegroundColor Yellow
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
