#!/usr/bin/env powershell
#requires -version 4

[cmdletbinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory=$true)]
    [string]$RepoPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2

& .\build.ps1 /t:Package

Write-Host "Finished packaging"

& .\scripts\bootstrapper\run.ps1 msbuild -p $RepoPath -s .\artifacts 