param([Parameter(Mandatory=$true)][string]$Port, [string]$Bossac = '', [switch]$SkipBuild)
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
if ($Port -notmatch '^COM\d+$') { throw 'Usa un puerto como COM5.' }
if (!$SkipBuild) { & "$PSScriptRoot\build.ps1" }
if (!(Test-Path build\space_battle.bin)) { throw 'Falta build\space_battle.bin' }
if (!$Bossac) {
 $tool = Get-ChildItem "${env:USERPROFILE}\AppData\Local\Arduino15\packages\arduino\tools\bossac\*\bossac.exe" | Sort-Object FullName -Descending | Select-Object -First 1
 if (!$tool) { throw 'No se encontro bossac. Instala Arduino SAM Boards.' }
 $Bossac = $tool.FullName
}
# Programming Port only: ATmega16U2 implements erase/reset at 1200 baud.
$serial = New-Object System.IO.Ports.SerialPort $Port,1200,None,8,one
try { $serial.Open(); $serial.DtrEnable = $true; Start-Sleep -Milliseconds 100; $serial.DtrEnable = $false }
finally { if ($serial.IsOpen) { $serial.Close() }; $serial.Dispose() }
Start-Sleep -Seconds 2
& $Bossac "--port=$Port" '-U' 'false' '-e' '-w' '-v' '-b' 'build\space_battle.bin' '-R'
if ($LASTEXITCODE -ne 0) { throw "bossac fallo: $LASTEXITCODE" }

