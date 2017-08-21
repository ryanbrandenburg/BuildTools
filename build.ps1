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

$korebuildConsoleproj = "tools/KoreBuild.Console/KoreBuild.Console.csproj"
$configDir = "files/KoreBuild/config"

& dotnet run -p $korebuildConsoleproj install-tools --toolsSource $ToolsSource --dotNetHome $DotNetHome --configDir $configDir $Arguments
& dotnet run -p $korebuildConsoleproj msbuild --toolsSource $ToolsSource --dotNetHome $DotNetHome --repoPath $Path --configDir $configDir $Arguments
