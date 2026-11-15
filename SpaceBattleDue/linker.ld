ENTRY(Reset_Handler)
MEMORY {
 FLASH (rx) : ORIGIN = 0x00080000, LENGTH = 512K
 RAM (rwx) : ORIGIN = 0x20070000, LENGTH = 96K
}
_stack = ORIGIN(RAM) + LENGTH(RAM);
SECTIONS {
 .text : { KEEP(*(.vectors)) *(.text*) *(.rodata*) . = ALIGN(4); } > FLASH
 .bss (NOLOAD) : { . = ALIGN(4); _sbss = .; *(.bss*) *(COMMON) . = ALIGN(4); _ebss = .; } > RAM
 /DISCARD/ : { *(.comment*) *(.ARM.attributes*) }
}
ASSERT(_ebss < _stack - 4096, "Insufficient stack")
