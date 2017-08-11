#requires -version 4

Set-StrictMode -Version 2

$CommonModule = "$PSScriptRoot/common.psm1"
Import-Module $CommonModule

if (Get-Command 'dotnet' -ErrorAction Ignore) {
    $global:dotnet = (Get-Command 'dotnet').Path
}

### constants
Set-Variable 'IS_WINDOWS' -Scope Script -Option Constant -Value $((Get-Variable -Name IsWindows -ValueOnly -ErrorAction Ignore) -or !(Get-Variable -Name IsCoreClr -ValueOnly -ErrorAction Ignore))
Set-Variable 'EXE_EXT' -Scope Script -Option Constant -Value $(if ($IS_WINDOWS) { '.exe' } else { '' })

function Set-KoreBuildSettings
(
    [string]$ToolsSource,
    [string]$DotNetHome,
    [string]$Path,
    [string]$ConfigFile 
)
{
    $global:KoreBuildSettings = @{
        ToolsSource = $ToolsSource
        DotNetHome = $DotNetHome
        RepoPath = $Path
        SDKVersion = __get_dotnet_sdk_version
        CommonModule = $CommonModule
        IS_WINDOWS = $IS_WINDOWS
        EXE_EXT = $EXE_EXT
    }
}

<#
.SYNOPSIS
Installs tools if required.

.PARAMETER ToolsSource
The base url where build tools can be downloaded.

.PARAMETER DotNetHome
The directory where tools will be stored on the local machine.
#>
function Install-Tools(
    [Parameter(Mandatory = $true)]
    [string]$ToolsSource,
    [Parameter(Mandatory = $true)]
    [string]$DotNetHome) {

    $ErrorActionPreference = 'Stop'
    if (-not $PSBoundParameters.ContainsKey('Verbose')) {
        $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference')
    }

    if (!(Test-Path $DotNetHome)) {
        New-Item -ItemType Directory $DotNetHome | Out-Null
    }

    $DotNetHome = Resolve-Path $DotNetHome
    $arch = __get_dotnet_arch
    $installDir = if ($IS_WINDOWS) { Join-Path $DotNetHome $arch } else { $DotNetHome }
    Write-Verbose "Installing tools to '$installDir'"
    if ($env:DOTNET_INSTALL_DIR -and $env:DOTNET_INSTALL_DIR -ne $installDir) {
        # DOTNET_INSTALL_DIR is used by dotnet-install.ps1 only, and some repos used it in their automation to isolate dotnet.
        # DOTNET_HOME is used by the rest of our KoreBuild tools and is set by the bootstrappers.
        Write-Verbose "installDir = $installDir"
        Write-Verbose "DOTNET_INSTALL_DIR = ${env:DOTNET_INSTALL_DIR}"
        Write-Warning 'The environment variable DOTNET_INSTALL_DIR is deprecated. The recommended alternative is DOTNET_HOME.'
    }

    $global:dotnet = Join-Path $installDir "dotnet$EXE_EXT"

    $dotnetOnPath = Get-Command dotnet -ErrorAction Ignore
    if ($dotnetOnPath -and ($dotnetOnPath.Path -ne $global:dotnet)) {
        $dotnetDir = Split-Path -Parent $global:dotnet
        Write-Warning "dotnet found on the system PATH is '$($dotnetOnPath.Path)' but KoreBuild will use '${global:dotnet}'."
        Write-Warning "Adding '$dotnetDir' to system PATH permanently may be required for applications like Visual Studio or VS Code to work correctly."
    }

    $pathPrefix = Split-Path -Parent $global:dotnet
    if ($env:PATH -notlike "${pathPrefix};*") {
        # only prepend if PATH doesn't already start with the location of dotnet
        Write-Host "Adding $pathPrefix to PATH"
        $env:PATH = "$pathPrefix;$env:PATH"
    }

    if ($env:KOREBUILD_SKIP_RUNTIME_INSTALL -eq "1") {
        Write-Host "Skipping runtime installation because KOREBUILD_SKIP_RUNTIME_INSTALL = 1"
        return
    }

    $scriptPath = `
        if ($IS_WINDOWS) { Join-Path $PSScriptRoot 'dotnet-install.ps1' } `
        else { Join-Path $PSScriptRoot 'dotnet-install.sh' }

    if (!$IS_WINDOWS) {
        & chmod +x $scriptPath
    }

    $channel = "preview"
    $runtimeChannel = "master"
    $version = __get_dotnet_sdk_version
    $runtimeVersion = Get-Content (Join-Paths $PSScriptRoot ('..', 'config', 'runtime.version'))

    if ($env:KOREBUILD_DOTNET_CHANNEL) {
        $channel = $env:KOREBUILD_DOTNET_CHANNEL
    }
    if ($env:KOREBUILD_DOTNET_SHARED_RUNTIME_CHANNEL) {
        $runtimeChannel = $env:KOREBUILD_DOTNET_SHARED_RUNTIME_CHANNEL
    }
    if ($env:KOREBUILD_DOTNET_SHARED_RUNTIME_VERSION) {
        $runtimeVersion = $env:KOREBUILD_DOTNET_SHARED_RUNTIME_VERSION
    }

    if ($runtimeVersion) {
        __install_shared_runtime $scriptPath $installDir -arch $arch -version $runtimeVersion -channel $runtimeChannel
    }

    # Install the main CLI
    if (!(Test-Path (Join-Paths $installDir ('sdk', $version, 'dotnet.dll')))) {
        Write-Verbose "Installing dotnet $version to $installDir"
        & $scriptPath `
            -Channel $channel `
            -Version $version `
            -Architecture $arch `
            -InstallDir $installDir
    }
    else {
        Write-Host -ForegroundColor DarkGray ".NET Core SDK $version is already installed. Skipping installation."
    }
}

function Invoke-CommandFunction(
    [Parameter(Mandatory=$true)]
    [string]$Command,
    # [Parameter(ValueFromRemainingArguments = $false)]
    [string[]]$Arguments
)
{
    # call the command
    $commandFile = Join-Paths $PSScriptRoot ('commands', "$Command.ps1")

    if (!(Test-Path $commandFile)) {
       Write-Error "Unrecognized command: $Command"
    }
    Invoke-Expression "$commandFile $Arguments"
}

<#
.SYNOPSIS
Uploads NuGet packages to a remote feed.

.PARAMETER Feed
The NuGet feed.

.PARAMETER ApiKey
The API key for the NuGet feed.

.PARAMETER Packages
The files to upload

.PARAMETER Retries
The number of times to retry pushing when the `nuget push` command fails.

.PARAMETER MaxParallel
The maxiumum number of parallel pushes to execute.
#>
# Should be a module
function Push-NuGetPackage {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Feed,
        [string]$ApiKey,
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string[]] $Packages,
        [int]$Retries = 5,
        [int]$MaxParallel = 4
    )

    begin {
        $ErrorActionPreference = 'Stop'
        if (-not $PSBoundParameters.ContainsKey('Verbose')) {
            $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference')
        }

        if (-not $PSBoundParameters.ContainsKey('WhatIf')) {
            $WhatIfPreference = $PSCmdlet.GetVariableValue('WhatIfPreference')
        }

        if (!$ApiKey) {
            Write-Warning 'The parameter -ApiKey was missing. This may be required to push to the remote feed.'
        }

        if ($Packages | ? { $_ -like '*.symbols.nupkg' }) {
            Write-Warning "Push-NuGetPackage does not yet support pushing symbols packages."
        }

        $jobs = @()
    }

    process {
        $packagesToPush = @()
        foreach ($package in $Packages) {
            if ($package -like '*.symbols.nupkg') {
                Write-Host -ForegroundColor DarkCyan "Skipping symbols package: $package"
                continue
            }

            if ($PSCmdlet.ShouldProcess((Split-Path -Leaf $package), "dotnet nuget push")) {
                $packagesToPush += $package
            }
        }

        foreach ($package in $packagesToPush) {
            $running = $jobs | ? { $_.State -eq 'Running' }
            if (($running | Measure-Object).Count -ge $MaxParallel) {
                Write-Debug "Waiting for a job to complete because max parallel pushes is set to $MaxParallel"
                $finished = $running | Wait-Job -Any
                $finished | Receive-Job
            }

            Write-Verbose "Starting job to push $(Split-Path -Leaf $package)"
            $job = Start-Job -ScriptBlock {
                param($dotnet, $feed, $apikey, $package, $remaining)

                $ErrorActionPreference = 'Stop'
                Set-StrictMode -Version Latest

                while ($remaining -ge 0) {
                    $arguments = @()
                    if ($apikey) {
                        $arguments = ('--api-key', $apikey)
                    }

                    try {
                        & $dotnet nuget push `
                            $package `
                            --source $feed `
                            --timeout 300 `
                            @arguments

                        if ($LASTEXITCODE -ne 0) {
                            throw "Exit code $LASTEXITCODE. Failed to push $package."
                        }
                        break
                    }
                    catch {
                        if ($remaining -le 0) {
                            throw
                        }
                        else {
                            Write-Host "Push failed. Retries left $remaining"
                        }
                    }
                    finally {
                        $remaining--
                    }
                }
            } -ArgumentList ($global:dotnet, $Feed, $ApiKey, $package, $Retries)
            $jobs += $job
        }
    }

    end {
        $jobs | Wait-Job | Out-Null
        $jobs | Receive-Job
        $jobs | Remove-Job | Out-Null
    }
}

#
# Private functions
#
function __get_dotnet_sdk_version {
    if ($env:KOREBUILD_DOTNET_VERSION) {
        return $env:KOREBUILD_DOTNET_VERSION
    }
    return Get-Content (Join-Paths $PSScriptRoot ('..', 'config', 'sdk.version'))
}

function __show_version_info {
    $versionFile = Join-Paths $PSScriptRoot ('..', '.version')
    if (Test-Path $versionFile) {
        $version = Get-Content $versionFile | Where-Object { $_ -like 'version:*' } | Select-Object -first 1
        if (!$version) {
            Write-Host -ForegroundColor Gray "Failed to parse version from $versionFile. Expected a line that begins with 'version:'"
        }
        else {
            $version = $version.TrimStart('version:').Trim()
            Write-Host -ForegroundColor Magenta "Using KoreBuild $version"
        }
    }
}

try {
    # show version info on console when KoreBuild is imported
    __show_version_info
}
catch { }
