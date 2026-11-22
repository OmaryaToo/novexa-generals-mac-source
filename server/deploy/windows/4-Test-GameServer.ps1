# Phase 1, step 4: health checks.
. "$PSScriptRoot\Common.ps1"
$ok = $false
for ($i = 0; $i -lt 30 -and -not $ok; $i++) {
    try {
        $r = Invoke-WebRequest -UseBasicParsing -Method Post -Uri 'http://127.0.0.1:9001/env/live/contract/1/VersionCheck' -Body '{}' -ContentType 'application/json'
        $ok = $r.StatusCode -eq 200
    } catch { Start-Sleep -Seconds 2 }
}
if (-not $ok) { Write-Host 'VersionCheck FAILED. Last log lines:'; Get-Content (Join-Path $DataDir 'gameserver.log') -Tail 40; exit 1 }
Write-Host 'VersionCheck: 200 OK'
try { Invoke-WebRequest -UseBasicParsing -Uri 'http://127.0.0.1:9001/env/live/contract/1/MOTD' | Out-Null; Write-Host 'MOTD: unexpected 200' }
catch { Write-Host "MOTD without token: $($_.Exception.Response.StatusCode.value__) (expected 401)" }
try {
    $lc = Invoke-RestMethod -Uri 'http://127.0.0.1:9001/env/live/contract/1/LoginCode'
    Write-Host "LoginCode issued: $($lc.success) (login completes via the portal in phase 2)"
} catch { Write-Host "LoginCode request failed: $($_.Exception.Message)" }
Get-ScheduledTask -TaskName $TaskName | Select-Object TaskName, State | Format-Table
