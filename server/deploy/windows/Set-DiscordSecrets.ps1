# Stores the Discord application's Client ID and Client Secret in the admin-only secrets.json.
# Run it yourself in an elevated PowerShell; the secret is typed hidden and never printed.
. "$PSScriptRoot\Common.ps1"
Assert-Admin
$s = Get-Secrets
$id = Read-Host 'Discord Client ID'
$sec = Read-Host 'Discord Client Secret' -AsSecureString
$plain = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec))
$s | Add-Member -NotePropertyName discord_client_id -NotePropertyValue $id.Trim() -Force
$s | Add-Member -NotePropertyName discord_client_secret -NotePropertyValue $plain.Trim() -Force
$s | ConvertTo-Json | Set-Content -Path $SecretsFile -Encoding UTF8
Write-Host 'Saved. Now run .\5-Install-LoginPortal.ps1 (or restart its scheduled task).'
