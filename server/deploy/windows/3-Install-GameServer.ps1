# Phase 1, step 3: publish GenOnlineService (Release = no dev logins), write its production
# config outside the repo, and run it at boot as a SYSTEM scheduled task with auto-restart.
# -PublicHost: what clients use to reach the WebSocket (VPS IP now; play.novexa-jo.com in phase 3).
param([Parameter(Mandatory)] [string]$PublicHost, [switch]$OpenTestPort)
. "$PSScriptRoot\Common.ps1"
Assert-Admin
$s = Get-Secrets
$dotnet = Find-Exe 'dotnet.exe' @('C:\Program Files\dotnet\dotnet.exe')
if (-not $dotnet) { throw '.NET SDK not found. Run 1-Install-Prereqs.ps1 first.' }

Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue | Stop-ScheduledTask -ErrorAction SilentlyContinue
& $dotnet publish (Join-Path $ServerSrc 'GenOnlineService\GenOnlineService.csproj') -c Release -o $AppDir --nologo
if ($LASTEXITCODE -ne 0) { throw 'dotnet publish failed' }

# Production overrides. Kestrel listens on plain HTTP; TLS is terminated by the reverse proxy (phase 3).
# The second ("HTTPS") endpoint is rebound to localhost HTTP so no certificate is needed on the box.
$wsScheme = if ($PublicHost -match '^\d+\.\d+\.\d+\.\d+$') { 'ws' } else { 'wss' }
$wsAddr = if ($wsScheme -eq 'ws') { "ws://${PublicHost}:9001/ws" } else { "wss://$PublicHost/ws" }
$cfg = [ordered]@{
    # IP host = test phase (reachable directly on 9001); domain = behind Caddy (localhost only).
    Kestrel     = @{ Endpoints = @{ HTTP = @{ Url = $(if ($wsScheme -eq 'ws') { 'http://0.0.0.0:9001' } else { 'http://127.0.0.1:9001' }) }; HTTPS = @{ Url = 'http://127.0.0.1:9002' } } }
    JwtSettings = @{ Key = $s.jwt_key; Issuer = 'novexa-generals'; Audience = 'novexa-generals' }
    Core        = @{ ws_address = $wsAddr; ws_address_insecure = $wsAddr; use_os_cert_store = $true }
    API         = @{ webserver_key = $s.webserver_key }
    Database    = @{ db_host = '127.0.0.1'; db_port = $DbPort; db_name = $s.db_name; db_username = $s.db_user; db_password = $s.db_password }
}
$cfgPath = Join-Path $AppDir 'appsettings.Production.json'
$cfg | ConvertTo-Json -Depth 6 | Set-Content $cfgPath -Encoding UTF8
icacls $cfgPath /inheritance:r /grant:r 'Administrators:F' 'SYSTEM:F' | Out-Null

# Run at startup as SYSTEM, working directory = app dir (server resolves data/ relative to CWD).
$log = Join-Path $DataDir 'gameserver.log'
# Quoted form avoids cmd storing a trailing space in the value ("Production ").
$cmd = "cd /d `"$AppDir`" && set `"ASPNETCORE_ENVIRONMENT=Production`" && `"$dotnet`" GenOnlineService.dll >> `"$log`" 2>&1"
$action  = New-ScheduledTaskAction -Execute 'cmd.exe' -Argument "/c $cmd" -WorkingDirectory $AppDir
$trigger = New-ScheduledTaskTrigger -AtStartup
$settings = New-ScheduledTaskSettingsSet -RestartCount 999 -RestartInterval (New-TimeSpan -Minutes 1) `
            -ExecutionTimeLimit ([TimeSpan]::Zero) -StartWhenAvailable
Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings `
    -User 'SYSTEM' -RunLevel Highest -Force | Out-Null
Start-ScheduledTask -TaskName $TaskName

if ($OpenTestPort) {
    # Temporary: lets you test from your Mac before the HTTPS proxy exists. Remove in phase 3.
    New-NetFirewallRule -DisplayName 'NOVEXA GameServer TEST 9001' -Direction Inbound -Protocol TCP -LocalPort 9001 -Action Allow -ErrorAction SilentlyContinue | Out-Null
}
Write-Host "Started. Log: $log   Next: .\4-Test-GameServer.ps1"
