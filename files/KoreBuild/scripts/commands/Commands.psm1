#requires -version 4

Set-StrictMode -Version 2
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot\Invoke-DockerBuild.ps1"
. "$PSScriptRoot\Invoke-MSBuild.ps1"
. "$PSScriptRoot\Install-Tools.ps1"
