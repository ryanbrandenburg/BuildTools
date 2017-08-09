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
    [string[]]$MSBuildArgs
)

$ErrorActionPreference = 'Stop'

try {
    Import-Module -Force -Scope Local $PSScriptRoot/files/KoreBuild/KoreBuild.psd1

    Set-KoreBuildSettings $ToolsSource $DotNetHome $Path

    # TODO: Rename to Invoke-KoreBuildCommand
    Invoke-CommandFunction "install-tools" $ToolsSource $DotNetHome
    Invoke-CommandFunction "msbuild" @MSBuildArgs
}
finally {
    Remove-Module 'KoreBuild' -ErrorAction Ignore
}
