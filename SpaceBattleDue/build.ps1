param([string]$Toolchain = '')
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
if (!$Toolchain) {
 $pattern = Join-Path $env:USERPROFILE 'AppData\Local\Arduino15\packages\arduino\tools\arm-none-eabi-gcc\*\bin\arm-none-eabi-gcc.exe'
 $gcc = Get-ChildItem $pattern -ErrorAction SilentlyContinue | Sort-Object FullName -Descending | Select-Object -First 1
 if (!$gcc) { throw 'No se encontro ARM GCC. Instala Arduino SAM Boards o indica -Toolchain con la carpeta bin.' }
 $Toolchain = $gcc.DirectoryName
}
function Run-Tool([string]$Name, [string[]]$Arguments) {
 & (Join-Path $Toolchain "arm-none-eabi-$Name.exe") @Arguments
 if ($LASTEXITCODE -ne 0) { throw "$Name fallo con codigo $LASTEXITCODE" }
}
New-Item -ItemType Directory -Force build | Out-Null
Run-Tool 'as' @('-mcpu=cortex-m3','-mthumb','-g','space_battle.s','-o','build\space_battle.o')
Run-Tool 'ld' @('-T','linker.ld','--fatal-warnings','-Map=build\space_battle.map','build\space_battle.o','-o','build\space_battle.elf')
Run-Tool 'objcopy' @('-O','binary','build\space_battle.elf','build\space_battle.bin')
Run-Tool 'size' @('build\space_battle.elf')
$undefined = & (Join-Path $Toolchain 'arm-none-eabi-nm.exe') -u build\space_battle.elf
if ($LASTEXITCODE -ne 0) { throw 'No se pudo inspeccionar el ELF.' }
if ($undefined) { throw "Simbolos sin resolver: $undefined" }
$disassembly = & (Join-Path $Toolchain 'arm-none-eabi-objdump.exe') -d -h build\space_battle.elf
if ($LASTEXITCODE -ne 0) { throw 'No se pudo generar el desensamblado.' }
$disassembly | Set-Content build\disassembly.txt
Write-Host 'Ensamblado y enlace correctos. build\space_battle.bin listo.'
