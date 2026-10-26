[CmdletBinding()]
param(
    [ValidateSet('win-x64', 'win-arm64')]
    [string[]] $Runtime = @('win-x64', 'win-arm64')
)
$ErrorActionPreference = 'Stop'
if (-not $IsWindows) { throw 'Publication requires Windows.' }
$project = Join-Path $PSScriptRoot 'sounder/sounder.csproj'
foreach ($rid in $Runtime) {
    & dotnet publish $project -c Release -r $rid --self-contained true -p:RestoreLockedMode=true
    if ($LASTEXITCODE -ne 0) { throw "Publish failed for $rid." }
}
