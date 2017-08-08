#requires -version 4

Set-StrictMode -Version 2

<#
.SYNOPSIS
Builds a repository

.DESCRIPTION
Invokes the default MSBuild lifecycle on a repostory. This will download any required tools.

.PARAMETER Path
The path to the repository to be compiled

.PARAMETER MSBuildArgs
Arguments to be passed to the main MSBuild invocation

.EXAMPLE
Invoke-RepositoryBuild $PSScriptRoot /p:Configuration=Release /t:Verify

.NOTES
This is the main function used by most repos.
#>
function Invoke-RepositoryBuild(
    [Parameter(Mandatory = $true)]
    [string] $Path,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]] $MSBuildArgs) {

    $ErrorActionPreference = 'Stop'

    if (-not $PSBoundParameters.ContainsKey('Verbose')) {
        $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference')
    }

    $Path = Resolve-Path $Path
    Push-Location $Path | Out-Null
    try {
        Write-Verbose "Building $Path"
        Write-Verbose "dotnet = ${global:dotnet}"

        # Generate global.json to ensure the repo uses the right SDK version
        $sdkVersion = __get_dotnet_sdk_version
        if ($sdkVersion -ne 'latest') {
            "{ `"sdk`": { `"version`": `"$sdkVersion`" } }" | Out-File (Join-Path $Path 'global.json') -Encoding ascii
        } else {
            Write-Verbose "Skipping global.json generation because the `$sdkVersion = $sdkVersion"
        }

        $makeFileProj = Join-Paths $PSScriptRoot ('..', 'KoreBuild.proj')
        $msbuildArtifactsDir = Join-Paths $Path ('artifacts', 'msbuild')
        $msBuildResponseFile = Join-Path $msbuildArtifactsDir msbuild.rsp

        $msBuildLogArgument = ""

        if ($VerbosePreference -eq 'Continue' -or $env:KOREBUILD_ENABLE_BINARY_LOG -eq "1") {
            Write-Verbose 'Enabling binary logging'
            $msbuildLogFilePath = Join-Path $msbuildArtifactsDir msbuild.binlog
            $msBuildLogArgument = "/bl:$msbuildLogFilePath"
        }

        $msBuildArguments = @"
/nologo
/m
/p:RepositoryRoot="$Path/"
"$msBuildLogArgument"
/clp:Summary
"$makeFileProj"
"@

        $MSBuildArgs | ForEach-Object { $msBuildArguments += "`n`"$_`"" }

        if (!(Test-Path $msbuildArtifactsDir)) {
            New-Item -Type Directory $msbuildArtifactsDir | Out-Null
        }

        $msBuildArguments | Out-File -Encoding ASCII -FilePath $msBuildResponseFile

        $noop = ($MSBuildArgs -contains '/t:Noop' -or $MSBuildArgs -contains '/t:Cow')
        Write-Verbose "Noop = $noop"
        $firstTime = $env:DOTNET_SKIP_FIRST_TIME_EXPERIENCE
        if ($noop) {
            $env:DOTNET_SKIP_FIRST_TIME_EXPERIENCE = 'true'
        }
        else {
            __build_task_project $Path
        }

        Write-Verbose "Invoking msbuild with '$(Get-Content $msBuildResponseFile)'"

        __exec $global:dotnet msbuild `@"$msBuildResponseFile"
    }
    finally {
        Pop-Location
        $env:DOTNET_SKIP_FIRST_TIME_EXPERIENCE = $firstTime
    }
}