# Advisory only — see docs/ARCHITECTURE_MIGRATION.md (Z-ARCH-001).
# Not a required CI gate while the multi-feature migration is paused.
param(
    [Parameter(Mandatory = $false)]
    [string]$FeaturePath = "D:/zyntro_flutter/lib/features",

    [Parameter(Mandatory = $false)]
    [string]$FeatureName
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Test-LayerFolders {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $required = @("presentation", "domain", "data")
    $missing = @()

    foreach ($layer in $required) {
        $layerPath = Join-Path $Path $layer
        if (-not (Test-Path $layerPath)) {
            $missing += $layer
        }
    }

    return @{
        Missing = $missing
        IsValid = ($missing.Count -eq 0)
    }
}

if (-not (Test-Path $FeaturePath)) {
    Write-Error "Feature path not found: $FeaturePath"
    exit 1
}

$targets = @()
if ($FeatureName) {
    $single = Join-Path $FeaturePath $FeatureName
    if (-not (Test-Path $single)) {
        Write-Error "Feature '$FeatureName' not found under $FeaturePath"
        exit 1
    }
    $targets += Get-Item $single
}
else {
    $targets += Get-ChildItem -Path $FeaturePath -Directory
}

$failed = @()
foreach ($target in $targets) {
    $result = Test-LayerFolders -Path $target.FullName
    if ($result.IsValid) {
        Write-Output "[PASS] $($target.Name): presentation/domain/data detected."
    }
    else {
        $missingText = ($result.Missing -join ", ")
        Write-Output "[FAIL] $($target.Name): missing layers -> $missingText"
        $failed += $target.Name
    }
}

if ($failed.Count -gt 0) {
    Write-Error "Layer validation failed for: $($failed -join ', ')"
    exit 1
}

Write-Output "Feature layer validation completed successfully."
