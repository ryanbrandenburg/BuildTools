param($StorageConnectionString, [switch]$SkipRebuild)

# CI Build process for this repo is a little special. First we build the repo, then we try to build it again using the tools we just built
$ErrorActionPreference="Stop"
$Root = Split-Path -Parent $PSScriptRoot

& "$Root\build.ps1"

if(!$SkipRebuild) {
    # Move the tools
    $Stage1Out = Join-Path $Root ".stage1"

    if(Test-Path $Stage1Out) {
        del -rec -for -LiteralPath $Stage1Out
    }

    $ArtifactsLayout = Join-Path $Root "artifacts\build\layout"
    mv $ArtifactsLayout $Stage1Out

    # Build again using those tools
    & "$Root\build.ps1" -BuildTools $Stage1Out
}

if($StorageConnectionString) {
    $Package = @(dir "$Root\artifacts\build\aspnet-build.*.zip")
    if($Package.Length -eq 0) {
        throw "Package not found"
    } elseif($Package.Length -gt 1) {
        throw "Multiple packages found"
    }
    $PackagePath = $Package[0].FullName
    & "$PSScriptRoot\publish.ps1" -StorageConnectionString:$StorageConnectionString -PackagePath:$PackagePath
}

Write-Host -ForegroundColor Green "Bootstrap build complete"