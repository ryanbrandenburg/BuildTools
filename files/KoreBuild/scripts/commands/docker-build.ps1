#required -version 4

<#
.SYNOPSIS
Builds a repository inside a docker container

.DESCRIPTION
STUFF
#>

[CmdletBinding(PositionalBinding = $false)]
param(
    [Parameter(Mandatory=$true)]
    [hashtable]$Config,
    [Parameter(Mandatory=$true)]
    [string]$platform,
    [string[]]$Args
)

Import-Module $Config.CommonModule

$containerName = "testcontainer"

$dockerFileName = "$platform.dockerfile"
$dockerFile = "$PSScriptRoot\docker\$dockerFileName"
$dfDestination = "$($global:KoreBuildSettings.RepoPath)\$dockerFileName"

# dockerfile must be inside the docker context
Copy-Item -Path $dockerFile -Destination $dfDestination -Force

Write-Host "Building '$dfDestination' as '$containerName'"
__exec docker build --build-arg BUILD_ARGS=$Args -t $containerName -f $dfDestination $global:KoreBuildSettings.RepoPath
Write-Host "Running docker on $containerName."
__exec docker run --rm -it  --name $containerName $containerName
