# Shared paths/helpers for the NOVEXA Generals Online Windows deployment. Dot-source this file.
$ErrorActionPreference = 'Stop'
$Script:RepoRoot   = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$Script:ServerSrc  = Join-Path $RepoRoot 'server\upstream\GeneralsOnlineGameServer'
$Script:AppDir     = 'C:\NovexaGenerals\GameServer'          # published server (Release)
$Script:DataDir    = 'C:\ProgramData\NovexaGenerals'          # secrets + logs, admin-only ACL
$Script:SecretsFile = Join-Path $DataDir 'secrets.json'
$Script:TaskName   = 'NOVEXA GeneralsOnline GameServer'
$Script:PortalDir  = 'C:\NovexaGenerals\LoginPortal'         # published Discord login portal (phase 2)
$Script:PortalTaskName = 'NOVEXA Login Portal'

function Assert-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    if (-not ([Security.Principal.WindowsPrincipal]$id).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'Run this script from an elevated PowerShell (Run as Administrator).'
    }
}

function New-Secret([int]$bytes = 32) {
    $b = New-Object byte[] $bytes
    # Create().GetBytes works in both Windows PowerShell 5.1 (.NET Framework) and PowerShell 7.
    $rng = [Security.Cryptography.RandomNumberGenerator]::Create(); $rng.GetBytes($b); $rng.Dispose()
    -join ($b | ForEach-Object { $_.ToString('x2') })
}

function Protect-DataDir {
    New-Item -ItemType Directory -Force -Path $DataDir | Out-Null
    # Administrators + SYSTEM only; no inherited access for normal users.
    icacls $DataDir /inheritance:r /grant:r 'Administrators:(OI)(CI)F' 'SYSTEM:(OI)(CI)F' | Out-Null
}

function Get-Secrets {
    if (Test-Path $SecretsFile) { return Get-Content $SecretsFile -Raw | ConvertFrom-Json }
    Protect-DataDir
    $s = [ordered]@{
        db_root_password = New-Secret 24
        db_name          = 'generalsonline'
        db_user          = 'genonline'
        db_password      = New-Secret 24
        jwt_key          = New-Secret 32
        webserver_key    = New-Secret 32   # shared with the login portal (phase 2)
    }
    $s | ConvertTo-Json | Set-Content -Path $SecretsFile -Encoding UTF8
    return Get-Content $SecretsFile -Raw | ConvertFrom-Json
}

function Find-Exe([string]$name, [string[]]$extra = @()) {
    $c = Get-Command $name -ErrorAction SilentlyContinue
    if ($c) { return $c.Source }
    foreach ($p in $extra) { $hit = Get-ChildItem -Path $p -ErrorAction SilentlyContinue | Select-Object -First 1; if ($hit) { return $hit.FullName } }
    return $null
}

# Our own MariaDB instance. The VPS already runs an unrelated MariaDB 5.5 on 3306 (TCAdmin/OGP panels);
# never touch it. Ours is a separate 10.x/11.x install with its own service on 127.0.0.1:3307.
$Script:DbPort    = 3307
$Script:DbService = 'NovexaMariaDB'

function Get-MariaDbHome {
    Get-ChildItem 'C:\Program Files\MariaDB 1*' -Directory -ErrorAction SilentlyContinue |
        Where-Object { Test-Path (Join-Path $_.FullName 'bin\mariadb.exe') } |
        Sort-Object { [version]($_.Name -replace '^MariaDB\s+', '') } -Descending |
        Select-Object -First 1 -ExpandProperty FullName
}

function Get-MariaDbClient {
    $h = Get-MariaDbHome
    if ($h) { Join-Path $h 'bin\mariadb.exe' }
}
