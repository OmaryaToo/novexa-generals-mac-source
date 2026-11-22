# Phase 2: publish the NOVEXA Discord login portal and run it at boot as SYSTEM on 127.0.0.1:5080.
# Secrets are read at start time from secrets.json (admin-only) and passed as environment variables.
# Discord credentials: run .\Set-DiscordSecrets.ps1 (you type them; they are never shown or committed).
param([string]$PublicUrl = 'https://play.novexa-jo.com')
. "$PSScriptRoot\Common.ps1"
Assert-Admin
$null = Get-Secrets
$dotnet = Find-Exe 'dotnet.exe' @('C:\Program Files\dotnet\dotnet.exe')
$src = Join-Path $RepoRoot 'server\portal\NovexaLoginPortal\NovexaLoginPortal.csproj'

Get-ScheduledTask -TaskName $PortalTaskName -ErrorAction SilentlyContinue | Stop-ScheduledTask -ErrorAction SilentlyContinue
Get-CimInstance Win32_Process -Filter "Name='dotnet.exe'" | Where-Object { $_.CommandLine -match 'NovexaLoginPortal\.dll' } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
& $dotnet publish $src -c Release -o $PortalDir --nologo
if ($LASTEXITCODE -ne 0) { throw 'dotnet publish failed' }

# Launcher: loads secrets.json into env vars, then runs the portal. Kept in the admin-only data dir.
$launcher = Join-Path $DataDir 'run-portal.ps1'
@"
`$ErrorActionPreference = 'Stop'
`$s = Get-Content '$SecretsFile' -Raw | ConvertFrom-Json
`$env:DISCORD_CLIENT_ID     = `$s.discord_client_id
`$env:DISCORD_CLIENT_SECRET = `$s.discord_client_secret
`$env:WEBSERVER_KEY         = `$s.webserver_key
`$env:DB_HOST = '127.0.0.1'; `$env:DB_PORT = '$DbPort'; `$env:DB_NAME = `$s.db_name
`$env:DB_USER = `$s.db_user; `$env:DB_PASSWORD = `$s.db_password
`$env:PORTAL_PUBLIC_URL = '$PublicUrl'
`$env:ASPNETCORE_ENVIRONMENT = 'Production'
Set-Location '$PortalDir'
& '$dotnet' NovexaLoginPortal.dll *>> '$(Join-Path $DataDir 'portal.log')'
exit `$LASTEXITCODE
"@ | Set-Content $launcher -Encoding UTF8

$action   = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$launcher`"" -WorkingDirectory $PortalDir
$trigger  = New-ScheduledTaskTrigger -AtStartup
$settings = New-ScheduledTaskSettingsSet -RestartCount 999 -RestartInterval (New-TimeSpan -Minutes 1) `
            -ExecutionTimeLimit ([TimeSpan]::Zero) -StartWhenAvailable
Register-ScheduledTask -TaskName $PortalTaskName -Action $action -Trigger $trigger -Settings $settings `
    -User 'SYSTEM' -RunLevel Highest -Force | Out-Null
Start-ScheduledTask -TaskName $PortalTaskName

$s = Get-Secrets
if (-not $s.discord_client_id -or -not $s.discord_client_secret) {
    Write-Warning 'Discord credentials not set yet. Run .\Set-DiscordSecrets.ps1, then re-run this script.'
}
Write-Host "Portal started on http://127.0.0.1:5080  Log: $(Join-Path $DataDir 'portal.log')"
