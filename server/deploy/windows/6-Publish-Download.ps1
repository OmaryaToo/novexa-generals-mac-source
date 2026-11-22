# Publishes a launcher release on play.novexa-jo.com/download.
# Downloads the ZIP (or DMG) from the public GitHub release, verifies its SHA-256 against the release's
# .sha256 file, and writes latest.json for the portal's /api/download endpoint.
# Usage: .\6-Publish-Download.ps1 -Version 0.1.0 [-Notes "text"] [-Format zip|dmg]
# ZIP is the default: without Apple notarization a downloaded DMG triggers an extra Gatekeeper prompt.
param([Parameter(Mandatory)][string]$Version, [string]$Notes = '', [ValidateSet('zip','dmg')][string]$Format = 'zip')
. "$PSScriptRoot\Common.ps1"
Assert-Admin
if ($Version -notmatch '^\d+\.\d+\.\d+$') { throw 'Version must look like 1.2.3' }
$dir  = 'C:\NovexaGenerals\Downloads'
$file = "NOVEXA-Generals-Mac-$Version.$Format"
$base = "https://github.com/OmaryaToo/novexa-generals-mac-source/releases/download/v$Version"
New-Item -ItemType Directory -Force -Path $dir | Out-Null
$tmp = Join-Path $dir "$file.part"
Invoke-WebRequest -UseBasicParsing -Uri "$base/$file" -OutFile $tmp
$expected = ((Invoke-WebRequest -UseBasicParsing -Uri "$base/$file.sha256").Content -split '\s+')[0].ToLower()
$actual = (Get-FileHash -Algorithm SHA256 $tmp).Hash.ToLower()
if ($expected -ne $actual) { Remove-Item $tmp; throw "SHA-256 mismatch: expected $expected got $actual" }
Move-Item -Force $tmp (Join-Path $dir $file)
[ordered]@{ version = $Version; file = $file; sha256 = $actual; notes = $Notes } |
    ConvertTo-Json | Set-Content -Path (Join-Path $dir 'latest.json') -Encoding UTF8
Write-Host "Published $file ($([math]::Round((Get-Item (Join-Path $dir $file)).Length/1MB,1)) MB), sha256 $actual"
try { (Invoke-RestMethod 'http://127.0.0.1:5080/api/download') | Format-List } catch { Write-Host "Check https://play.novexa-jo.com/download" }
