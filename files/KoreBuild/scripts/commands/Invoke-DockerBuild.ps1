#required -version 4

<#
.SYNOPSIS
Builds a repository inside a docker container

.DESCRIPTION
STUFF
#>

$ErrorActionPreference = 'Stop'

function Invoke-DockerBuild(
    [string]$platform = "Ubuntu",
    [string[]]$Args
)
{
    $containerName = "testcontainer"

    $dockerFileName = "$platform.dockerfile"
    $dockerFile = "$PSScriptRoot\docker\$dockerFileName"
    $dfDestination = "$global:Path\$dockerFileName"

    # dockerfile must be inside the docker context
    Copy-Item -Path $dockerFile -Destination $dfDestination -Force

    Write-Host "Building '$dfDestination' as '$containerName'"
    & docker build --build-arg BUILD_ARGS=$Args -t $containerName -f $dfDestination $global:Path
    Write-Host "Running docker on $containerName."
    & docker run --rm -it  --name $containerName $containerName
}
