#!/usr/bin/env powershell
#requires -version 4
[CmdletBinding(PositionalBinding = $false)]
param(
    [Alias('p')]
    [string]$Path = $PSScriptRoot,
    [Alias('d')]
    [string]$DotNetHome = $(`
            if ($env:DOTNET_HOME) { $env:DOTNET_HOME } `
            elseif ($env:USERPROFILE) { Join-Path $env:USERPROFILE '.dotnet'} `
            elseif ($env:HOME) {Join-Path $env:HOME '.dotnet'}`
            else { Join-Path $PSScriptRoot '.dotnet'} ),
    [Alias('s')]
    [string]$ToolsSource = 'https://aspnetcore.blob.core.windows.net/buildtools',
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Arguments
)

$ErrorActionPreference = 'Stop'

& dotnet run -p tools/KoreBuild.Console/KoreBuild.Console.csproj install-tools --toolsSource $ToolsSource --dotNetHome $DotNetHome $Arguments
Write-Host "About to MSBuild"
& dotnet run -p tools/KoreBuild.Console/KoreBuild.Console.csproj msbuild --toolsSource $ToolsSource --dotNetHome $DotNetHome --repoPath $Path $Arguments
