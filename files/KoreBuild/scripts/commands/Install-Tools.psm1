#requires -version 4

Set-StrictMode -Version 2

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

    Import-Module $global:KoreBuildSettings.CommonModule

    if (-not $PSBoundParameters.ContainsKey('Verbose')) {
        $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference')
    }

    if (!(Test-Path $DotNetHome)) {
        New-Item -ItemType Directory $DotNetHome | Out-Null
    }

    $DotNetHome = Resolve-Path $DotNetHome
    $arch = __get_dotnet_arch
    $installDir = if ($global:KoreBuildSettings.IS_WINDOWS) { Join-Path $DotNetHome $arch } else { $DotNetHome }
    Write-Verbose "Installing tools to '$installDir'"
    if ($env:DOTNET_INSTALL_DIR -and $env:DOTNET_INSTALL_DIR -ne $installDir) {
        # DOTNET_INSTALL_DIR is used by dotnet-install.ps1 only, and some repos used it in their automation to isolate dotnet.
        # DOTNET_HOME is used by the rest of our KoreBuild tools and is set by the bootstrappers.
        Write-Verbose "installDir = $installDir"
        Write-Verbose "DOTNET_INSTALL_DIR = ${env:DOTNET_INSTALL_DIR}"
        Write-Warning 'The environment variable DOTNET_INSTALL_DIR is deprecated. The recommended alternative is DOTNET_HOME.'
    }

    $global:dotnet = Join-Path $installDir "dotnet$($global:KoreBuildSettings.EXE_EXT)"

    $dotnetOnPath = Get-Command dotnet -ErrorAction Ignore
    if ($dotnetOnPath -and ($dotnetOnPath.Path -ne $global:dotnet)) {
        Write-Warning "dotnet found on the system PATH is '$($dotnetOnPath.Path)' but KoreBuild will use '${global:dotnet}'"
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
        if ($global:KoreBuildSettings.IS_WINDOWS) { Join-Paths $PSScriptRoot ( '..', 'dotnet-install.ps1') } `
        else { Join-Paths $PSScriptRoot ('..', 'dotnet-install.sh') }

    if (!$global:KoreBuildSettings.IS_WINDOWS) {
        & chmod +x $scriptPath
    }

    $channel = "preview"
    $runtimeChannel = "master"
    $version = $global:KoreBuildSettings.SDKVersion
    $runtimeVersion = Get-Content (Join-Paths $PSScriptRoot ('..', '..', 'config', 'runtime.version'))

    if ($env:KOREBUILD_DOTNET_CHANNEL) {
        $channel = $env:KOREBUILD_DOTNET_CHANNEL
    }
    if ($env:KOREBUILD_DOTNET_SHARED_RUNTIME_CHANNEL) {
        $runtimeChannel = $env:KOREBUILD_DOTNET_SHARED_RUNTIME_CHANNEL
    }
    if ($env:KOREBUILD_DOTNET_SHARED_RUNTIME_VERSION) {
        $runtimeVersion = $env:KOREBUILD_DOTNET_SHARED_RUNTIME_VERSION
    }

    # Temporarily install these runtimes to prevent build breaks for repos not yet converted
    # 1.0.5 - for tools
    __install_shared_runtime $scriptPath $installDir -arch $arch -version "1.0.5" -channel "preview"
    # 1.1.2 - for test projects which haven't yet been converted to netcoreapp2.0
    __install_shared_runtime $scriptPath $installDir -arch $arch -version "1.1.2" -channel "release/1.1.0"

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

function __install_shared_runtime($installScript, $installDir, [string]$arch, [string] $version, [string] $channel) {
    $sharedRuntimePath = Join-Paths $installDir ('shared', 'Microsoft.NETCore.App', $version)
    # Avoid redownloading the CLI if it's already installed.
    if (!(Test-Path $sharedRuntimePath)) {
        Write-Verbose "Installing .NET Core runtime $version"
        & $installScript `
            -Channel $channel `
            -SharedRuntime `
            -Version $version `
            -Architecture $arch `
            -InstallDir $installDir
    }
    else {
        Write-Host -ForegroundColor DarkGray ".NET Core runtime $version is already installed. Skipping installation."
    }
}

function __get_dotnet_arch {
    if ($env:KOREBUILD_DOTNET_ARCH) {
        return $env:KOREBUILD_DOTNET_ARCH
    }
    return 'x64'
}
