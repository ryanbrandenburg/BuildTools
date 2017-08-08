[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$gitRepo,
    [Parameter(Mandatory=$true)]
    [string]$containerName
)

Copy-Item -force -Recurse $gitRepo/* .\repo
& docker build -t $containerName -f .\BuildAgent\Ubuntu\Dockerfile .
& docker run --rm -it --name $containerName $containerName
