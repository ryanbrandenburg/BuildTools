$BuildToolsRoot = Split-Path -Parent $PSScriptRoot

Write-Host -ForegroundColor Green "Initializing ASP.NET Build Tools..."

$dotnetVersionFile = "$BuildToolsRoot\dotnet-install\dotnet-version.txt"
$dotnetChannel = "rel-1.0.0"
$dotnetVersion = Get-Content $dotnetVersionFile

if ($env:ASPNETBUILD_DOTNET_CHANNEL)
{
    $dotnetChannel = $env:ASPNETBUILD_DOTNET_CHANNEL
}
if ($env:ASPNETBUILD_DOTNET_VERSION)
{
    $dotnetVersion = $env:ASPNETBUILD_DOTNET_VERSION
}

if ($env:ASPNETBUILD_SKIP_RUNTIME_INSTALL -eq "1")
{
    Write-Host -ForegroundColor Green "Skipping runtime installation because ASPNETBUILD_SKIP_RUNTIME_INSTALL = 1"
}
else
{
    Write-Host -ForegroundColor Green "Installing .NET Command-Line Tools ..."
    & "$BuildToolsRoot\dotnet-install\dotnet-install.ps1" -NoPath -Channel $dotnetChannel -Version $dotnetVersion -Architecture x64
}

# workaround for CLI issue: https://github.com/dotnet/cli/issues/2143
$DotNetInstallDir = "$env:LOCALAPPDATA\Microsoft\dotnet"
$sharedPath = (Join-Path $DotNetInstallDir "shared");
(Get-ChildItem $sharedPath -Recurse *dotnet.exe) | %{ $_.FullName } | Remove-Item;