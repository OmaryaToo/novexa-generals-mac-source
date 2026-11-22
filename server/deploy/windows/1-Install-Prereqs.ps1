# Phase 1, step 1: install .NET 10 SDK and MariaDB Server with winget (official packages).
. "$PSScriptRoot\Common.ps1"
Assert-Admin
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    throw 'winget is not available. Install "App Installer" from Microsoft, or install .NET 10 SDK and MariaDB 11.x manually, then continue with 2-Setup-Database.ps1.'
}
$secrets = Get-Secrets

$dotnetExe = Find-Exe 'dotnet.exe' @('C:\Program Files\dotnet\dotnet.exe')
if (-not $dotnetExe -or -not ((& $dotnetExe --list-sdks) -match '^10\.')) {
    winget install --id Microsoft.DotNet.SDK.10 --exact --silent --accept-package-agreements --accept-source-agreements
} else { Write-Host '.NET already installed:' (& dotnet --list-sdks) }

if (-not (Get-MariaDbClient)) {
    # Root password is generated and stored in the admin-only secrets file; service listens on localhost only.
    $override = "/qn SERVICENAME=$DbService PORT=$DbPort PASSWORD=$($secrets.db_root_password) ALLOWREMOTEROOTACCESS=0"
    winget install --id MariaDB.Server --exact --silent --accept-package-agreements --accept-source-agreements --override $override
} else { Write-Host 'MariaDB already installed:' (Get-MariaDbClient) }

Write-Host "`nDone. Open a NEW elevated PowerShell (to refresh PATH) and run 2-Setup-Database.ps1"
