# Installs ASP.NET Build tools into a repo
[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact="High")]
param([string]$BuildToolsDir, [string]$Destination)

if(!$BuildToolsDir) {
    $BuildToolsDir = Split-Path -Parent $PSScriptRoot
}

if(!$Destination) {
    $Destination = Convert-Path (Get-Location)
}

function CopyFile($name) {
    $dest = Join-Path $Destination $name
    $src = Join-Path $BuildToolsDir $name

    if(!(Test-Path $src)) {
        throw "Unable to find template source file: $src"
    }

    if((Test-Path $dest) -and !$PSCmdlet.ShouldContinue("Replace existing file '$name'", "Replace File")) {
        return;
    }
    cp $src $dest
    Write-Host "Installed '$name'"
}

CopyFile "build.cmd"
CopyFile "build.sh"
CopyFile "build.ps1"

if(!(Test-Path (Join-Path $Destination "Trainfile"))) {
    CopyFile "Repofile"
}