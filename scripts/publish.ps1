param($StorageConnectionString, $PackagePath)

$Root = Split-Path $PSScriptRoot

if(!(Test-Path $PackagePath)) {
    throw "Can't find package $PackagePath"
}
$PackagePath = Convert-Path $PackagePath

$ContainerName = "aspnetbuildpackages"

pushd "$Root\src\PushBlob"

try {
    & "$env:LOCALAPPDATA\Microsoft\dotnet\dotnet.exe" run -- "$PackagePath" "$ContainerName" "$StorageConnectionString"
    if($LASTEXITCODE -ne 0) {
        throw "Failed to push package"
    }
} finally {
    popd
}