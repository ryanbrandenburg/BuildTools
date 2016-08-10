<#
.SYNOPSIS
    Starts the build of the ASP.NET Repository in which this file is located
.PARAMETER BuildTools
    Optional: Path to the 'aspnet-build' tools to use for this build.
.PARAMETER ResetTools
    Force the tools to be reinstalled even if they already exist and are up-to-date.
#>
[CmdletBinding(DefaultParameterSetName="DefaultBuildTools")]
param(
    [Parameter(ParameterSetName="CustomBuildTools")]
    [string]$BuildTools,

    [Parameter(ParameterSetName="DefaultBuildTools")]
    [switch]$ResetTools,

    [Parameter(ValueFromRemainingArguments=$true)]
    [string[]]$MSBuildArgs
)

$ErrorActionPreference = "Stop"
$PackageNamePattern = "aspnet-build\.(.*)\.zip"
$InstallationRoot = Join-Path (Join-Path $env:LOCALAPPDATA "Microsoft") "aspnet-build"

function GetTrainfile() {
    $Trainfile = Join-Path $PSScriptRoot "Trainfile"
    $Repofile = Join-Path $PSScriptRoot "Repofile"
    if(Test-Path $Trainfile) {
        $Trainfile
    } elseif(Test-Path $Repofile) {
        $Repofile
    }
}

function GetFolderNameFromBranch($Branch) {
    $Branch.Replace("/", "-")
}

function GetInstallPath($Branch) {
    $Folder = GetFolderNameFromBranch $Branch
    Join-Path (Join-Path $InstallationRoot "branches") $Folder
}

function GetBranch($PackageFileName)
{
    if($PackageFileName -notmatch $PackageNamePattern) {
        throw "Invalid Package File Name: $PackageFileName"
    }
    [regex]::Replace($PackageFileName, $PackageNamePattern, "`$1")
}

function GetUrlFromTrainfile() {
    if(!(Test-Path $Trainfile)) {
        throw "Trainfile not found: $Trainfile"
    }
    $Trainfile = Convert-Path $Trainfile
    cat $Trainfile | where { $_ -match "^BuildTools: (.*)$" } | foreach { $matches[1] }
}

function InstallFromUrl($SourceUrl) {
    if(!$SourceUrl.StartsWith("http")) {
        throw "Source URL must be an HTTP(S) endpoint!"
    }

    # Identify the Branch from the URL
    $PackageFileName = Split-Path -Leaf $SourceUrl
    $PackageBranch = GetBranch $PackageFileName
    $InstallPath = GetInstallPath $PackageBranch
    $script:BuildTools = $InstallPath

    if($ResetTools -and (Test-Path $InstallPath)) {
        Write-Host -ForegroundColor Yellow "Clearing existing build tools as requested by -ResetTools switch."
        del -rec -for $InstallPath
    }

    if(Test-Path "$InstallPath\.etag") {
        Write-Host "Tools for $PackageBranch are already installed. Checking for updates..."
        $ETag = [IO.File]::ReadAllText((Convert-Path "$InstallPath\.etag"))

        # Check if there's actually a new version available
        try {
            $resp = Invoke-WebRequest $SourceUrl -Method Head -Headers @{"If-None-Match" = $ETag} 
        } catch {
            $resp = $_.Exception.Response
        }

        if($resp.StatusCode -eq "NotModified") {
            # It's already installed!
            Write-Host -ForegroundColor Green "The latest version of the ASP.NET Build Tools from branch $PackageBranch are already present in $InstallPath"
            return
        }
        Write-Host "Your build tools are out-of-date. Downloading the latest build tools."
    }

    # If we made it here, either a) There is no existing install or b) The ETag didn't match so there's a new version

    $TempFile = Join-Path ([IO.Path]::GetTempPath()) $PackageFileName
    if(Test-Path $TempFile) {
        del -Force -LiteralPath $TempFile
    }
    Write-Host -ForegroundColor Green "Downloading ASP.NET Build Tools Package from $SourceUrl"

    $resp = Invoke-WebRequest $SourceUrl -OutFile $TempFile -PassThru
    $ETag = $resp.Headers.ETag

    try {
        Add-Type -Assembly "System.IO.Compression.FileSystem"
    } catch {
        throw "Failed to load System.IO.Compression.FileSystem.dll, which is required."
        exit
    }

    # If we're here, we're definitely installing, so clean any previous versions
    if(Test-Path $InstallPath) {
        del -Recurse -Force -LiteralPath $InstallPath
    }

    mkdir $InstallPath | Out-Null
    $InstallPath = Convert-Path $InstallPath

    [System.IO.Compression.ZipFile]::ExtractToDirectory((Convert-Path $TempFile), $InstallPath)

    if($ETag) {
        "$ETag" > (Join-Path $InstallPath ".etag")
    }
}


function InstallBuildTools() {
    $Trainfile = GetTrainfile
    if(!$Trainfile) {
        throw "This repo does not have a 'Trainfile' or a 'Repofile'"
    }

    Write-Host -ForegroundColor DarkGray "Using Trainfile: $Trainfile"
    $Url = GetUrlFromTrainfile $Trainfile
    Write-Host -ForegroundColor DarkGray "Using Build Tools: $Url"
    InstallFromUrl $Url
}

function EnsureBuildTools() {
    if($BuildTools) {
        if(!(Test-Path $BuildTools)) {
            throw "Could not find build tools in '$BuildTools'"
        }
    } else {
        InstallBuildTools
    }
}

# Clean up the arguments because PowerShell insists on trying to parse them...
$newArgs = @()
$MSBuildArgs | ForEach-Object {
    $arg = $_
    $prev = $newArgs.Length - 1;
    if($newArgs.Length -eq 0) {
        # this clause is here so I don't have to put "$newArgs.Length -gt 0" in the other else branches.
        # this is the first arg, just add it
        $newArgs+=@($arg)
    } elseif($newArgs[$prev].EndsWith(":")) {
        # reattach this to the previous arg (there was a ':' separating them and PowerShell split it)
        # in this case "-t=a" becomes "-t" and "=a"
        $newArgs[$prev] += $arg
    } else {
        # this is the first arg, just add it
        $newArgs+=@($arg)
    }
}

# This "try..catch" weirdness is needed because PowerShell aggresively wraps exceptions.
try {
    EnsureBuildTools
} catch {
    throw $error[0]
}

Write-Host -ForegroundColor DarkGray "> aspnet-build $newArgs"
& "$BuildTools\bin\aspnet-build.ps1" @newArgs