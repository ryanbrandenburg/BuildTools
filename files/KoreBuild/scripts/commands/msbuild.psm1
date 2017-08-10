function msbuild(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Args
)
{
    Import-Module (Join-Path $PSScriptRoot "Invoke-MSBuild.psm1")
    Invoke-MSBuild $Args
}