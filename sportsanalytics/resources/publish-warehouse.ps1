<#
.SYNOPSIS
    Builds and publishes the sportsanalytics-dwh SQL project (dacpac) to the Fabric Data Warehouse.

.DESCRIPTION
    Auth: if TenantId, ClientId and ClientSecret are set (parameters or the
    BREAKINGSOUTH_TENANT_ID / BREAKINGSOUTH_CLIENT_ID / BREAKINGSOUTH_CLIENT_SECRET environment variables),
    a service principal token is used. Otherwise your current `az login` session is used.
    Requires: dotnet SDK, sqlpackage (installed as a dotnet tool if missing), Azure CLI (az login mode only).

.PARAMETER DryRun
    Generate the deployment script instead of applying it.

.EXAMPLE
    .\publish-warehouse.ps1
    .\publish-warehouse.ps1 -DryRun
#>
[CmdletBinding()]
param(
    [switch]$DryRun,
    [string]$SqlProj = (Join-Path $PSScriptRoot '..\workspace\sportsanalytics-dwh.Warehouse\sportsanalytics-dwh.sqlproj'),
    [string]$SqlDatabase = 'sportsanalytics-dwh',
    [string]$TenantId = $env:BREAKINGSOUTH_TENANT_ID,
    [string]$ClientId = $env:BREAKINGSOUTH_CLIENT_ID,
    [string]$ClientSecret = $env:BREAKINGSOUTH_CLIENT_SECRET
)

$ErrorActionPreference = 'Stop'

$SqlServer = 'nkc3sqzhtfweramv3d7c4re6ja-z6qm4eqwcuauhaj54jrjaawvam.datawarehouse.fabric.microsoft.com'

if (-not (Test-Path $SqlProj)) { throw "sqlproj not found: $SqlProj" }
$SqlProj = (Resolve-Path $SqlProj).Path

if (-not ($TenantId -and $ClientId -and $ClientSecret) -and -not (Get-Command az -ErrorAction SilentlyContinue)) {
    throw 'Azure CLI (az) is required when no service principal credentials are provided'
}
if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) { throw 'dotnet SDK is required' }

if (-not (Get-Command sqlpackage -ErrorAction SilentlyContinue)) {
    Write-Host 'Installing sqlpackage as a global dotnet tool...'
    dotnet tool install --global microsoft.sqlpackage
    if ($LASTEXITCODE -ne 0) { throw 'Failed to install sqlpackage' }
    $env:PATH = "$env:PATH;$env:USERPROFILE\.dotnet\tools"
}

$ProjectDir = Split-Path $SqlProj -Parent
$ProjectName = [System.IO.Path]::GetFileNameWithoutExtension($SqlProj)
$Dacpac = Join-Path $ProjectDir "bin\Release\$ProjectName.dacpac"

Write-Host "Building $SqlProj..."
dotnet build $SqlProj -c Release
if ($LASTEXITCODE -ne 0) { throw 'Build failed' }

if (-not (Test-Path $Dacpac)) { throw "dacpac not found after build: $Dacpac" }

if ($TenantId -and $ClientId -and $ClientSecret) {
    Write-Host "Getting Entra access token for service principal $ClientId..."
    $tokenResponse = Invoke-RestMethod -Method Post `
        -Uri "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token" `
        -ContentType 'application/x-www-form-urlencoded' `
        -Body @{
            grant_type    = 'client_credentials'
            client_id     = $ClientId
            client_secret = $ClientSecret
            scope         = 'https://database.windows.net/.default'
        }
    $AccessToken = $tokenResponse.access_token
    if (-not $AccessToken) { throw 'Failed to get service principal access token.' }
}
else {
    Write-Host 'Getting Entra access token from az login session...'
    $azArgs = @('account', 'get-access-token', '--resource', 'https://database.windows.net/', '--query', 'accessToken', '-o', 'tsv')
    if ($TenantId) { $azArgs += @('--tenant', $TenantId) }
    $AccessToken = az @azArgs
    if ($LASTEXITCODE -ne 0 -or -not $AccessToken) { throw 'Failed to get access token. Run `az login` first.' }
}

if ($DryRun) {
    $Out = Join-Path $ProjectDir "bin\Release\$ProjectName.deploy.sql"
    Write-Host "Dry run: generating deployment script at $Out"
    sqlpackage /Action:Script `
        /SourceFile:"$Dacpac" `
        /TargetServerName:"$SqlServer" `
        /TargetDatabaseName:"$SqlDatabase" `
        /AccessToken:"$AccessToken" `
        /OutputPath:"$Out" `
        /p:BlockOnPossibleDataLoss=true
    if ($LASTEXITCODE -ne 0) { throw 'Script generation failed' }
    exit 0
}

Write-Host "Publishing $ProjectName to $SqlServer/$SqlDatabase..."
sqlpackage /Action:Publish `
    /SourceFile:"$Dacpac" `
    /TargetServerName:"$SqlServer" `
    /TargetDatabaseName:"$SqlDatabase" `
    /AccessToken:"$AccessToken" `
    /p:BlockOnPossibleDataLoss=true
if ($LASTEXITCODE -ne 0) { throw 'Publish failed' }

Write-Host 'Published.'
