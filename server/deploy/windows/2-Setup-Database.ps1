# Phase 1, step 2: create the database, user and schema (safe to re-run).
. "$PSScriptRoot\Common.ps1"
Assert-Admin
$s = Get-Secrets
$client = Get-MariaDbClient
if (-not $client) { throw 'MariaDB client not found. Run 1-Install-Prereqs.ps1 first.' }

# Bind MariaDB to localhost only.
# Only our own instance's my.ini (never the unrelated MariaDB 5.5 on this VPS).
$ini = Get-Item (Join-Path (Get-MariaDbHome) 'data\my.ini') -ErrorAction SilentlyContinue
if ($ini -and -not (Select-String -Path $ini.FullName -Pattern '^\s*bind-address' -Quiet)) {
    (Get-Content $ini.FullName) -replace '^\[mysqld\]', "[mysqld]`r`nbind-address=127.0.0.1" | Set-Content $ini.FullName
    Restart-Service $DbService
}
$conn = @('-u', 'root', '-h', '127.0.0.1', '-P', "$DbPort")

$sql = @"
CREATE DATABASE IF NOT EXISTS ``$($s.db_name)`` CHARACTER SET utf8mb4;
CREATE USER IF NOT EXISTS '$($s.db_user)'@'127.0.0.1' IDENTIFIED BY '$($s.db_password)';
CREATE USER IF NOT EXISTS '$($s.db_user)'@'localhost' IDENTIFIED BY '$($s.db_password)';
GRANT ALL PRIVILEGES ON ``$($s.db_name)``.* TO '$($s.db_user)'@'127.0.0.1';
GRANT ALL PRIVILEGES ON ``$($s.db_name)``.* TO '$($s.db_user)'@'localhost';
FLUSH PRIVILEGES;
"@
$env:MYSQL_PWD = $s.db_root_password
try {
    $sql | & $client @conn
    if ($LASTEXITCODE -ne 0) { throw 'creating database/user failed' }
    $schema = Join-Path $ServerSrc 'GenOnlineService\Database_Structure\structure.sql'
    Get-Content $schema -Raw | & $client @conn $s.db_name
    if ($LASTEXITCODE -ne 0) { throw 'loading schema failed' }
    $n = & $client @conn -N -e "select count(*) from information_schema.tables where table_schema='$($s.db_name)'"
} finally { Remove-Item Env:\MYSQL_PWD -ErrorAction SilentlyContinue }
Write-Host "Database '$($s.db_name)' ready with $n tables. Next: 3-Install-GameServer.ps1"
