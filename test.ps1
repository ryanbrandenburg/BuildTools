#!/usr/bin/env powershell
#requires -version 4

[cmdletbinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory=$true)]
    [string]$RepoPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2

Write-Host "RepoPath: $RepoPath"

# Build it
& .\build.ps1

& .\scripts\bootstrapper\build.ps1 -p $RepoPath -s .\artifacts