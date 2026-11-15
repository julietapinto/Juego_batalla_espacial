param([string]$Port='COM8',[int]$Seconds=20)
$ErrorActionPreference='Stop'
$serial=New-Object System.IO.Ports.SerialPort
$serial.PortName=$Port
$serial.BaudRate=115200
$serial.DataBits=8
$serial.Parity=[System.IO.Ports.Parity]::None
$serial.StopBits=[System.IO.Ports.StopBits]::One
$serial.DtrEnable=$false
$serial.RtsEnable=$false
$log=Join-Path $PSScriptRoot 'diagnostico-serie.txt'
$buffer=New-Object System.Text.StringBuilder
try {
 $serial.Open()
 Write-Host 'Escuchando 20 segundos. Pulsa RESET una vez en el Due (no ERASE).'
 $watch=[System.Diagnostics.Stopwatch]::StartNew()
 while($watch.Elapsed.TotalSeconds -lt $Seconds){
  $part=$serial.ReadExisting()
  if($part){[Console]::Write($part); [void]$buffer.Append($part)}
  Start-Sleep -Milliseconds 50
 }
} finally {
 if($serial.IsOpen){$serial.Close()}
 $serial.Dispose()
 $buffer.ToString() | Set-Content -Encoding utf8 $log
}
Write-Host "`nResultado guardado en $log"
