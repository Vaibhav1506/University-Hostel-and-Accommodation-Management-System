# Optional maintainer validation only. Requires local OS DBA authentication.
# Creates a uniquely named temporary schema; never targets an existing schema.
param([ValidateSet('run_all.sql','hostel_complete.sql')][string]$Installer = 'run_all.sql')
$ErrorActionPreference = 'Stop'
$sqlplusPath = 'C:\app\bvaib_fee5mh\product\26ai\dbhomeFree\bin\sqlplus.exe'
$testUser = 'C6TEST_' + [guid]::NewGuid().ToString('N').Substring(0,12).ToUpperInvariant()
$testPassword = 'C6a_' + [guid]::NewGuid().ToString('N')
$scriptRoot = $PSScriptRoot
$created = $false
Push-Location -LiteralPath $scriptRoot
try {
    $createScript = @"
WHENEVER SQLERROR EXIT SQL.SQLCODE
SET ECHO OFF VERIFY OFF
ALTER SESSION SET CONTAINER=FREEPDB1;
CREATE USER $testUser IDENTIFIED BY "$testPassword" DEFAULT TABLESPACE USERS QUOTA 20M ON USERS;
EXIT
"@
    $createOutput = $createScript | & $sqlplusPath -L -S '/ as sysdba' 2>&1
    $createCode = $LASTEXITCODE
    $createOutput | Set-Content -LiteralPath 'validation_admin_create.log'
    if ($createCode -ne 0) { throw "Temporary schema creation failed; see validation_admin_create.log." }
    $created = $true
    $grantScript = @"
WHENEVER SQLERROR EXIT SQL.SQLCODE
ALTER SESSION SET CONTAINER=FREEPDB1;
GRANT CREATE SESSION, CREATE TABLE, CREATE VIEW, CREATE TRIGGER, CREATE PROCEDURE TO $testUser;
EXIT
"@
    $grantOutput = $grantScript | & $sqlplusPath -L -S '/ as sysdba' 2>&1
    if ($LASTEXITCODE -ne 0) { throw "Temporary schema grants failed: $grantOutput" }
    $testScript = @"
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK
SET ECHO OFF VERIFY OFF
CONNECT $testUser/"$testPassword"@localhost:1521/FREEPDB1
@$Installer
EXIT SUCCESS
"@
    $testOutput = $testScript | & $sqlplusPath -L -S /nolog 2>&1
    $testCode = $LASTEXITCODE
    $testOutput | Set-Content -LiteralPath 'validation_console.log'
    $testOutput | Select-String -Pattern 'PASS:|ALL ASSERTIONS|ORA-|PLS-|SP2-|completed\.'
    if ($testCode -ne 0) { throw "Oracle validation failed (exit $testCode); see validation_console.log." }
    Write-Output 'ORACLE VALIDATION SUCCEEDED'
} finally {
    if ($created) {
        # This is precisely the random schema created above, not a user-supplied name.
        if ($testUser -notmatch '^C6TEST_[A-F0-9]{12}$') { throw 'Unsafe cleanup identifier.' }
        $cleanupScript = @"
WHENEVER SQLERROR EXIT SQL.SQLCODE
ALTER SESSION SET CONTAINER=FREEPDB1;
DROP USER $testUser CASCADE;
EXIT
"@
        $cleanupOutput = $cleanupScript | & $sqlplusPath -L -S '/ as sysdba' 2>&1
        $cleanupCode = $LASTEXITCODE
        $cleanupOutput | Set-Content -LiteralPath 'validation_admin_cleanup.log'
        if ($cleanupCode -ne 0) { Write-Warning "Temporary schema $testUser was not removed; see cleanup log." }
        else { Write-Output 'Temporary validation schema removed.' }
    }
    $testPassword = $null
    Pop-Location
}
