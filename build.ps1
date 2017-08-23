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

try {
    Import-Module -Force -Scope Local $PSScriptRoot/files/KoreBuild/KoreBuild.psd1
    Invoke-KoreBuildCommand "install-tools" -ToolsSource $ToolsSource -DotNetHome $DotNetHome @Arguments
    Invoke-KoreBuildCommand "msbuild" -ToolsSource $ToolsSource -DotNetHome $DotNetHome -repoPath $Path @Arguments
}
finally {
    Remove-Module 'KoreBuild' -ErrorAction Ignore
}
