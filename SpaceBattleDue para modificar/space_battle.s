.syntax unified
.cpu cortex-m3
.thumb
.equ PMC,0x400e0600
.equ PIOA,0x400e0e00
.equ PIOB,0x400e1000
.equ PIOC,0x400e1200
.equ ADC,0x400c0000
.equ TWI,0x40090000
.equ TC,0x40080000
.equ OLED_ADDR,0x3c
// Columna 0 para el modulo actual; algunos SH1106 requieren 2.
.equ OLED_COLUMN_OFFSET,0
.equ UART,0x400e0800
.macro WRITE addr,val
 ldr r0,=\addr
 ldr r1,=\val
 str r1,[r0]
.endm
.section .vectors,"a",%progbits
.global vectors
vectors:
.word _stack,Reset_Handler
.rept 14
.word Default_Handler
.endr
.rept 27
.word Default_Handler
.endr
.word TC0_Handler
.rept 17
.word Default_Handler
.endr
.section .text
.thumb_func
.global Reset_Handler
Reset_Handler:
 cpsid i
 WRITE 0xe000ed08,vectors
 ldr r0,=_sbss
 ldr r1,=_ebss
 movs r2,#0
1: cmp r0,r1
 itt lo
 strlo r2,[r0],#4
 blo 1b
 WRITE 0x400e1a54,0x8000 // watchdog disable
 // Five flash wait states before raising master clock.
 WRITE 0x400e0a00,0x500
 WRITE 0x400e0c00,0x500
 WRITE PMC+0x20,0x00370809
 ldr r0,=PMC
1: ldr r1,[r0,#0x68]
 tst r1,#1
 beq 1b
 WRITE PMC+0x20,0x01370809
 ldr r0,=PMC
1: ldr r1,[r0,#0x68]
 tst r1,#0x10000
 beq 1b
 WRITE PMC+0x28,0x200d3f01 // 12 MHz *14 =168 MHz
 ldr r0,=PMC
1: ldr r1,[r0,#0x68]
 tst r1,#2
 beq 1b
 WRITE PMC+0x30,0x11 // MAIN /2, then PLLA /2
 bl mck_wait
 WRITE PMC+0x30,0x12
 bl mck_wait
 WRITE PMC+0x10,0x08803900 // PIO A/B/C, TWI1, TC0
 WRITE PMC+0x100,0x20 // ADC ID37
 // UART hacia Programming Port, PA8/PA9, 115200 8N1.
 ldr r0,=PIOA
 ldr r1,[r0,#0x70]
 bic r1,r1,#0x300
 str r1,[r0,#0x70]
 WRITE PIOA+4,0x300
 WRITE UART,0xac
 WRITE UART+4,0x800
 WRITE UART+0x20,46
 WRITE UART,0x50
 WRITE PIOB,0x08000000
 WRITE PIOB+0x10,0x08000000
 WRITE PIOB+0x34,0x08000000
 WRITE PIOA,0x00800000
 WRITE PIOA+0x14,0x00800000
 WRITE PIOA+0x64,0x00800000
 WRITE PIOC,0x00800000
 WRITE PIOC+0x14,0x00800000
 WRITE PIOC+0x64,0x00800000
 WRITE PIOA+0x04,0x01010000 // analog A0/A1
 WRITE PIOA+0x60,0x01010000
 // Peripheral A on PB12/PB13.
 ldr r0,=PIOB
 ldr r1,[r0,#0x70]
 bic r1,r1,#0x3000
 str r1,[r0,#0x70]
 WRITE PIOB+4,0x3000
 WRITE ADC,1
 WRITE ADC+4,0x13380100 // ADC 21 MHz, startup 512 clocks, tracking 4
 WRITE ADC+0x10,0xc0
 WRITE TWI,0x80
 WRITE TWI,0x24
 WRITE TWI+0x10,0x6565 // 84MHz/(2*(101+4)) =400 kHz
 ldr r0,=page_cmd
 movs r1,#OLED_COLUMN_OFFSET
 strb r1,[r0,#1]
 movs r1,#0x10
 strb r1,[r0,#2]
 bl oled_init
 WRITE TC+4,0x0000c000 // TIMER_CLOCK1 MCK/2, waveform UP_RC
 WRITE TC+0x1c,1400000 // 42 MHz / 30
 WRITE TC+0x24,0x10
 WRITE 0xe000e280,0x08000000
 WRITE 0xe000e100,0x08000000
 WRITE TC,5
 cpsie i
main:
 // Atomic check plus WFI prevents a lost wakeup.
 cpsid i
 ldr r0,=ticks
 ldr r1,[r0]
 ldr r2,=consumed
 ldr r3,[r2]
 cmp r1,r3
 bne 2f
 dsb
 wfi
 cpsie i
 b main
2: str r1,[r2]
 cpsie i
 movs r0,#1
 bl trace_stage
 bl input
 movs r0,#2
 bl trace_stage
 bl mod_update
 movs r0,#3
 bl trace_stage
 bl mod_render
 movs r0,#4
 bl trace_stage
 bl oled_flush
 movs r0,#5
 bl trace_stage
 bl serial_report
 b main
.thumb_func
mck_wait:
 ldr r0,=PMC
1: ldr r1,[r0,#0x68]
 tst r1,#8
 beq 1b
 bx lr
.thumb_func
Default_Handler:
 cpsid i
 movs r0,#70
 bl uart_putc
 movs r0,#65
 bl uart_putc
 movs r0,#85
 bl uart_putc
 movs r0,#76
 bl uart_putc
 movs r0,#84
 bl uart_putc
 movs r0,#10
 bl uart_putc
 b Default_Handler
.thumb_func
TC0_Handler:
 ldr r0,=TC
 ldr r1,[r0,#0x20]
 ldr r0,=ticks
 ldr r1,[r0]
 adds r1,#1
 str r1,[r0]
 // LED L: PB27, cambiar cada 16 ticks.
 tst r1,#15
 bne irq_done
 ldr r0,=PIOB
 ldr r2,[r0,#0x38]
 tst r2,#0x08000000
 ldr r2,=0x08000000
 ite eq
 streq r2,[r0,#0x30]
 strne r2,[r0,#0x34]
irq_done:
 bx lr
.ltorg
// I2C writes, bounded waits. A failed OLED stays recoverable.
// r0 mask; returns r0=0 success,1 error.
.thumb_func
wait_twi:
 ldr r1,=TWI
 ldr r2,=100000
1: ldr r3,[r1,#0x20]
 ldr r12,=last_twi_sr
 str r3,[r12]
 tst r3,#0x100
 bne 3f
 tst r3,r0
 bne 2f
 subs r2,#1
 bne 1b
3: movs r0,#1
 bx lr
2: movs r0,#0
 bx lr
// r0 buffer, r1 length, r2 control byte. Returns success/error.
.thumb_func
twi_send:
 push {r4-r8,lr}
 mov r4,r0
 mov r5,r1
 mov r6,r2
 ldr r7,=TWI
 ldr r0,=(OLED_ADDR<<16)
 str r0,[r7,#4]
 str r6,[r7,#0x34]
1: movs r0,#4
 bl wait_twi
 cmp r0,#0
 bne 3f
 cmp r5,#0
 beq 2f
 ldrb r0,[r4],#1
 str r0,[r7,#0x34]
 subs r5,#1
 b 1b
2: movs r0,#2
 str r0,[r7]
 movs r0,#1
 bl wait_twi
 cmp r0,#0
 bne 3f
 pop {r4-r8,pc}
3: ldr r1,=i2c_errors
 ldr r2,[r1]
 adds r2,#1
 str r2,[r1]
 movs r0,#0x80
 str r0,[r7]
 movs r0,#0x24
 str r0,[r7]
 ldr r0,=0x6565
 str r0,[r7,#0x10]
 movs r0,#1
 pop {r4-r8,pc}
.thumb_func
oled_init:
 push {r4,lr}
 ldr r4,=8000000
1: subs r4,#1
 bne 1b
 ldr r0,=init_cmd
 movs r1,#28 // Longitud de init_cmd, compatible con binutils 2.24
 movs r2,#0
 bl twi_send
 // Prueba A5: todos los puntos encendidos, independiente del framebuffer.
 ldr r0,=panel_test_on
 movs r1,#2
 movs r2,#0
 bl twi_send
 ldr r4,=84000000
panel_test_wait:
 subs r4,#1
 bne panel_test_wait
 ldr r0,=panel_test_off
 movs r1,#1
 movs r2,#0
 bl twi_send
 pop {r4,pc}
.thumb_func
oled_flush:
 push {r4-r6,lr}
 movs r4,#0
 ldr r5,=framebuffer
1: ldr r0,=page_cmd
 orr r1,r4,#0xb0
 strb r1,[r0]
 movs r1,#3
 movs r2,#0
 bl twi_send
 cmp r0,#0
 bne 2f
 mov r0,r5
 movs r1,#128
 movs r2,#0x40
 bl twi_send
 cmp r0,#0
 bne 2f
 adds r5,#128
 adds r4,#1
 cmp r4,#8
 bne 1b
2: pop {r4-r6,pc}
.ltorg
.thumb_func
input:
 push {r4,lr}
 ldr r4,=ADC
 movs r0,#2
 str r0,[r4]
 ldr r2,=100000
1: ldr r0,[r4,#0x30]
 and r0,r0,#0xc0
 cmp r0,#0xc0
 beq 2f
 subs r2,#1
 bne 1b
 b 3f
2: // Compensar joystick montado 90 grados a la izquierda.
 // Nuevo X = -Y original; nuevo Y = X original.
 ldr r0,[r4,#0x68] // CDR6, eje original Y
 movw r2,#4095
 subs r0,r2,r0
 ldr r1,=ax
 str r0,[r1]
 ldr r0,[r4,#0x6c] // CDR7, eje original X
 str r0,[r1,#4]
3: ldr r0,=PIOA
 ldr r0,[r0,#0x3c]
 tst r0,#0x800000
 ite eq
 moveq r0,#1
 movne r0,#0
 ldr r1,=PIOC
 ldr r1,[r1,#0x3c]
 tst r1,#0x800000
 it eq
 orreq r0,r0,#2
 // Two consecutive equal samples debounce both buttons.
 ldr r1,=raw_buttons
 ldr r2,[r1]
 str r0,[r1]
 cmp r0,r2
 bne 4f
 ldr r1,=buttons
 ldr r2,[r1]
 str r0,[r1]
 bic r0,r0,r2
 ldr r1,=pressed
 str r0,[r1]
 pop {r4,pc}
4: movs r0,#0
 ldr r1,=pressed
 str r0,[r1]
 pop {r4,pc}
.thumb_func
new_game:
 ldr r0,=game
 movs r1,#1
 str r1,[r0] // state
 movs r1,#60
 str r1,[r0,#4]
 movs r1,#52
 str r1,[r0,#8]
 movs r1,#0
 str r1,[r0,#12] // score
 str r1,[r0,#20] // bullet active
 str r1,[r0,#32] // frame
 movs r1,#3
 str r1,[r0,#16] // lives
 ldr r0,=enemies
 movs r1,#0
1: lsls r2,r1,#4
 adds r2,#12
 str r2,[r0],#4
 movs r2,#12
 str r2,[r0],#4
 adds r1,#1
 cmp r1,#5
 bne 1b
 // Reinicio de proyectiles y mejoras.
 ldr r0,=extra_state_start
 ldr r2,=extra_state_end
 movs r1,#0
reset_extras:
 cmp r0,r2
 bhs reset_extras_done
 str r1,[r0],#4
 b reset_extras
reset_extras_done:
 ldr r0,=pickup_countdown
 movs r1,#90
 str r1,[r0]
 ldr r0,=special_charge
 movs r1,#150
 str r1,[r0]
 bx lr
.thumb_func
update:
 push {r4-r8,lr}
 ldr r4,=game
 ldr r0,[r4]
 cmp r0,#1
 beq 1f
 ldr r0,=pressed
 ldr r0,[r0]
 cmp r0,#0
 beq 9f
 bl new_game
 b 9f
1: ldr r0,[r4,#32]
 adds r0,#1
 str r0,[r4,#32]
 bl explosions_update
 bl upgrades_update
 // Nave: 2 pixeles/cuadro, 3 con mejora S.
 ldr r1,=ax
 ldr r2,[r1]
 ldr r0,[r4,#4]
 bl axis
 cmp r0,#120
 it hi
 movhi r0,#120
 str r0,[r4,#4]
 ldr r1,=ay
 ldr r2,[r1]
 ldr r0,[r4,#8]
 bl axis
 cmp r0,#10
 it lo
 movlo r0,#10
 cmp r0,#56
 it hi
 movhi r0,#56
 str r0,[r4,#8]
 bl weapons_update
 bl special_update
3: ldr r5,=enemies
 movs r6,#5
4: ldr r7,[r5] // enemy X
 ldr r8,[r5,#4] // Y
 // Enemigos: 1 pixel cada ocho cuadros (3.75 px/s).
 ldr r0,[r4,#32]
 movs r2,#8
 udiv r1,r0,r2
 mls r1,r1,r2,r0
 cmp r1,#0
 it eq
 addeq r8,#1
 cmp r8,#57
 bge 7f
 mov r0,r7
 mov r1,r8
 bl projectile_hit
 cmp r0,#0
 beq 5f
 mov r0,r7
 mov r1,r8
 bl explosion_spawn
 ldr r0,[r4,#12]
 adds r0,#10
 ldr r1,=9999
 cmp r0,r1
 it hi
 movhi r0,#0
 str r0,[r4,#12]
 b 8f
5: // rectangle overlap ship (8x8) and enemy (8x8)
 ldr r0,[r4,#4]
 subs r0,r0,r7
 adds r0,#7
 cmp r0,#14
 bhi 6f
 ldr r0,[r4,#8]
 subs r0,r0,r8
 adds r0,#7
 cmp r0,#14
 bhi 6f
7: ldr r0,[r4,#16]
 cmp r0,#0
 beq 8f
 subs r0,#1
 str r0,[r4,#16]
 bne 8f
 movs r0,#2
 str r0,[r4]
8: movs r8,#10
 // Deterministic changing spawn positions, no runtime library.
 ldr r0,[r4,#32]
 adds r7,r7,r0
 adds r7,#29
 movs r1,#120
 udiv r2,r7,r1
 mls r7,r2,r1,r7
6: str r7,[r5]
 str r8,[r5,#4]
 adds r5,#8
 subs r6,#1
 bne 4b
9: // El record no se borra al empezar otra partida.
 ldr r0,[r4,#12]
 ldr r1,=high_score
 ldr r2,[r1]
 cmp r0,r2
 it hi
 strhi r0,[r1]
 pop {r4-r8,pc}
.thumb_func
axis:
 movs r1,#2
 ldr r3,=speed_timer
 ldr r3,[r3]
 cmp r3,#0
 it ne
 movne r1,#3
 ldr r3,=1400
 cmp r2,r3
 bhs axis_positive
 subs r0,r0,r1
 it mi
 movmi r0,#0
 bx lr
axis_positive:
 ldr r3,=2700
 cmp r2,r3
 it hi
 addhi r0,r0,r1
 bx lr
.ltorg
// Pixel OR, clips in both axes. r0=x r1=y.
.thumb_func
pixel:
 cmp r0,#128
 bhs 1f
 cmp r1,#64
 bhs 1f
 lsrs r2,r1,#3
 add r0,r0,r2,lsl #7
 and r1,r1,#7
 movs r2,#1
 lsl r2,r2,r1
 ldr r3,=framebuffer
 ldrb r1,[r3,r0]
 orrs r1,r2
 strb r1,[r3,r0]
1: bx lr
// Sprite: r0=x r1=y r2=8 columns, bit0 at top.
.thumb_func
sprite:
 push {r4-r10,lr}
 mov r4,r0
 mov r5,r1
 mov r6,r2
 movs r7,#0
1: ldrb r8,[r6,r7]
 movs r9,#0
2: tst r8,#1
 beq 3f
 add r0,r4,r7
 add r1,r5,r9
 bl pixel
3: lsr r8,r8,#1
 adds r9,#1
 cmp r9,#8
 bne 2b
 adds r7,#1
 cmp r7,#8
 bne 1b
 pop {r4-r10,pc}
// Font consists of ASCII space..Z, 5 columns, 7 rows.
.thumb_func
text:
 push {r4-r10,lr}
 mov r4,r0
 mov r5,r1
 mov r6,r2
1: ldrb r0,[r6],#1
 cmp r0,#0
 beq 5f
 subs r0,#32
 movs r1,#5
 mul r0,r0,r1
 ldr r10,=font
 add r10,r0
 movs r7,#0
2: ldrb r8,[r10,r7]
 movs r9,#0
3: tst r8,#1
 beq 4f
 add r0,r4,r7
 add r1,r5,r9
 bl pixel
4: lsr r8,r8,#1
 adds r9,#1
 cmp r9,#7
 bne 3b
 adds r7,#1
 cmp r7,#5
 bne 2b
 adds r4,#6
 b 1b
5: pop {r4-r10,pc}
.thumb_func
render:
 push {r4-r8,lr}
 ldr r0,=framebuffer
 movs r1,#0
 movw r2,#256
1: str r1,[r0],#4
 subs r2,#1
 bne 1b
 ldr r4,=game
 ldr r0,[r4]
 cmp r0,#0
 beq menu
 cmp r0,#2
 beq over
 movs r0,#0
 movs r1,#0
 ldr r2,=hud
 bl text
 // Four decimal digits, hardware division.
 ldr r0,[r4,#12]
 ldr r1,=digits+3
 movs r2,#10
 movs r3,#4
2: udiv r5,r0,r2
 mls r6,r5,r2,r0
 adds r6,#48
 strb r6,[r1],#-1
 mov r0,r5
 subs r3,#1
 bne 2b
 movs r0,#12
 movs r1,#0
 ldr r2,=digits
 bl text
 ldr r0,[r4,#16]
 adds r0,#48
 ldr r1,=life_digit
 strb r0,[r1]
 movs r0,#102
 movs r1,#0
 ldr r2,=life_digit
 bl text
 ldr r0,[r4,#4]
 ldr r1,[r4,#8]
 ldr r2,=ship_sprite
 bl sprite
 bl render_projectiles
 bl render_powerups
 bl render_chargebar
3: ldr r5,=enemies
 movs r6,#5
4: ldr r0,[r5],#4
 ldr r1,[r5],#4
 ldr r2,=enemy_sprite
 bl sprite
 subs r6,#1
 bne 4b
 bl render_explosions
 pop {r4-r8,pc}
menu:
 movs r0,#28
 movs r1,#16
 ldr r2,=title
 bl text
 movs r0,#10
 movs r1,#40
 ldr r2,=start_text
 bl text
 movs r0,#28
 bl render_best_score
 bl diagnostic_line
 pop {r4-r8,pc}
over:
 movs r0,#37
 movs r1,#16
 ldr r2,=over_text
 bl text
 // Convertir el punteo aqui, incluso si se perdio la ultima vida este cuadro.
 ldr r0,[r4,#12]
 ldr r1,=digits+3
 movs r2,#10
 movs r3,#4
over_score_digits:
 udiv r5,r0,r2
 mls r6,r5,r2,r0
 adds r6,#48
 strb r6,[r1],#-1
 mov r0,r5
 subs r3,#1
 bne over_score_digits
 movs r0,#28
 movs r1,#29
 ldr r2,=final_score_text
 bl text
 movs r0,#76
 movs r1,#29
 ldr r2,=digits
 bl text
 movs r0,#39
 bl render_best_score
 movs r0,#10
 movs r1,#54
 ldr r2,=restart_text
 bl text
 pop {r4-r8,pc}
.ltorg
// Diagnostico: contador TC0, entradas y error I2C.
.thumb_func
diagnostic_line:
 push {r4-r8,lr}
 ldr r4,=diag_buffer
 ldr r0,=diag_template
 movs r1,#18
1: ldrb r2,[r0],#1
 strb r2,[r4],#1
 subs r1,#1
 bne 1b
 ldr r4,=diag_buffer
 ldr r0,=ticks
 ldr r0,[r0]
 movw r1,#1000
 udiv r2,r0,r1
 mls r0,r2,r1,r0
 add r1,r4,#4
 movs r2,#10
 movs r3,#3
2: udiv r5,r0,r2
 mls r6,r5,r2,r0
 adds r6,#48
 strb r6,[r1],#-1
 mov r0,r5
 subs r3,#1
 bne 2b
 ldr r0,=raw_buttons
 ldr r0,[r0]
 and r1,r0,#1
 adds r1,#48
 strb r1,[r4,#8]
 lsr r0,r0,#1
 and r0,r0,#1
 adds r0,#48
 strb r0,[r4,#12]
 ldr r0,=i2c_errors
 ldr r0,[r0]
 cmp r0,#0
 ite eq
 moveq r0,#48
 movne r0,#49
 strb r0,[r4,#16]
 movs r0,#0
 movs r1,#54
 mov r2,r4
 bl text
 pop {r4-r8,pc}
.ltorg
.section .rodata
diag_title: .asciz "DIAG 3"
diag_template: .asciz "T:000 A:0 D:0 E:0"
.section .bss
.balign 4
diag_buffer: .space 20
.section .rodata
init_cmd:
 // Configuracion compatible con el constructor SH1106 NONAME usado antes.
 // Bombas de carga SSD1306 y SH1106, luego modo pagina explicito.
 .byte 0xae,0xd5,0x80,0xa8,0x3f,0xd3,0x00,0x40
 .byte 0x8d,0x14,0xad,0x8b,0x20,0x02
 .byte 0xa1,0xc8,0xda,0x12,0x81,0xcf,0xd9,0xf1,0xdb,0x40
 .byte 0x2e,0xa4,0xa6,0xaf
init_cmd_end:
panel_test_on: .byte 0xaf,0xa5
panel_test_off: .byte 0xa4
ship_sprite: .byte 0x60,0x30,0x1c,0x7f,0x7f,0x1c,0x30,0x60
enemy_sprite: .byte 0x18,0x5c,0x36,0x1f,0x1f,0x36,0x5c,0x18
title: .asciz "SPACE BATTLE"
start_text: .asciz "A2 O D7: INICIAR"
restart_text: .asciz "A2 O D7: REINICIO"
over_text: .asciz "GAME OVER"
final_score_text: .asciz "PUNTOS: "
hud: .asciz "P:             V:"
.section .bss
.balign 4
.global framebuffer
framebuffer: .space 1024
ticks: .space 4
consumed: .space 4
ax: .space 4
ay: .space 4
raw_buttons: .space 4
buttons: .space 4
pressed: .space 4
.global game
game: .space 36
enemies: .space 40
.global i2c_errors
i2c_errors: .space 4
page_cmd: .space 4
digits: .space 8
life_digit: .space 4


.section .rodata
font:
 .byte 0x00,0x00,0x00,0x00,0x00 // ASCII 32
 .byte 0x00,0x00,0x00,0x00,0x00 // ASCII 33
 .byte 0x00,0x00,0x00,0x00,0x00 // ASCII 34
 .byte 0x00,0x00,0x00,0x00,0x00 // ASCII 35
 .byte 0x00,0x00,0x00,0x00,0x00 // ASCII 36
 .byte 0x00,0x00,0x00,0x00,0x00 // ASCII 37
 .byte 0x00,0x00,0x00,0x00,0x00 // ASCII 38
 .byte 0x00,0x00,0x00,0x00,0x00 // ASCII 39
 .byte 0x00,0x00,0x00,0x00,0x00 // ASCII 40
 .byte 0x00,0x00,0x00,0x00,0x00 // ASCII 41
 .byte 0x00,0x00,0x00,0x00,0x00 // ASCII 42
 .byte 0x00,0x00,0x00,0x00,0x00 // ASCII 43
 .byte 0x00,0x00,0x00,0x00,0x00 // ASCII 44
 .byte 0x00,0x00,0x00,0x00,0x00 // ASCII 45
 .byte 0x00,0x00,0x00,0x00,0x00 // ASCII 46
 .byte 0x00,0x00,0x00,0x00,0x00 // ASCII 47
 .byte 0x3e,0x51,0x49,0x45,0x3e // ASCII 48
 .byte 0x00,0x42,0x7f,0x40,0x00 // ASCII 49
 .byte 0x42,0x61,0x51,0x49,0x46 // ASCII 50
 .byte 0x21,0x41,0x45,0x4b,0x31 // ASCII 51
 .byte 0x18,0x14,0x12,0x7f,0x10 // ASCII 52
 .byte 0x27,0x45,0x45,0x45,0x39 // ASCII 53
 .byte 0x3c,0x4a,0x49,0x49,0x30 // ASCII 54
 .byte 0x01,0x71,0x09,0x05,0x03 // ASCII 55
 .byte 0x36,0x49,0x49,0x49,0x36 // ASCII 56
 .byte 0x06,0x49,0x49,0x29,0x1e // ASCII 57
 .byte 0x00,0x36,0x36,0x00,0x00 // ASCII 58
 .byte 0x00,0x00,0x00,0x00,0x00 // ASCII 59
 .byte 0x00,0x00,0x00,0x00,0x00 // ASCII 60
 .byte 0x00,0x00,0x00,0x00,0x00 // ASCII 61
 .byte 0x00,0x00,0x00,0x00,0x00 // ASCII 62
 .byte 0x00,0x00,0x00,0x00,0x00 // ASCII 63
 .byte 0x00,0x00,0x00,0x00,0x00 // ASCII 64
 .byte 0x7e,0x11,0x11,0x11,0x7e // ASCII 65
 .byte 0x7f,0x49,0x49,0x49,0x36 // ASCII 66
 .byte 0x3e,0x41,0x41,0x41,0x22 // ASCII 67
 .byte 0x7f,0x41,0x41,0x22,0x1c // ASCII 68
 .byte 0x7f,0x49,0x49,0x49,0x41 // ASCII 69
 .byte 0x7f,0x09,0x09,0x09,0x01 // ASCII 70
 .byte 0x3e,0x41,0x49,0x49,0x7a // ASCII 71
 .byte 0x7f,0x08,0x08,0x08,0x7f // ASCII 72
 .byte 0x00,0x41,0x7f,0x41,0x00 // ASCII 73
 .byte 0x20,0x40,0x41,0x3f,0x01 // ASCII 74
 .byte 0x7f,0x08,0x14,0x22,0x41 // ASCII 75
 .byte 0x7f,0x40,0x40,0x40,0x40 // ASCII 76
 .byte 0x7f,0x02,0x0c,0x02,0x7f // ASCII 77
 .byte 0x7f,0x04,0x08,0x10,0x7f // ASCII 78
 .byte 0x3e,0x41,0x41,0x41,0x3e // ASCII 79
 .byte 0x7f,0x09,0x09,0x09,0x06 // ASCII 80
 .byte 0x3e,0x41,0x51,0x21,0x5e // ASCII 81
 .byte 0x7f,0x09,0x19,0x29,0x46 // ASCII 82
 .byte 0x46,0x49,0x49,0x49,0x31 // ASCII 83
 .byte 0x01,0x01,0x7f,0x01,0x01 // ASCII 84
 .byte 0x3f,0x40,0x40,0x40,0x3f // ASCII 85
 .byte 0x1f,0x20,0x40,0x20,0x1f // ASCII 86
 .byte 0x3f,0x40,0x38,0x40,0x3f // ASCII 87
 .byte 0x63,0x14,0x08,0x14,0x63 // ASCII 88
 .byte 0x07,0x08,0x70,0x08,0x07 // ASCII 89
 .byte 0x61,0x51,0x49,0x45,0x43 // ASCII 90



// UART de diagnostico. No usa Arduino API ni pila USB.
.section .text
.thumb_func
uart_putc:
 ldr r1,=UART
 ldr r3,=100000
1: ldr r2,[r1,#0x14]
 tst r2,#2
 bne 2f
 subs r3,#1
 bne 1b
 bx lr
2: str r0,[r1,#0x1c]
 bx lr
.thumb_func
uart_string:
 push {r4,lr}
 mov r4,r0
1: ldrb r0,[r4],#1
 cmp r0,#0
 beq 2f
 bl uart_putc
 b 1b
2: pop {r4,pc}
.thumb_func
uart_hex:
 push {r4-r6,lr}
 mov r4,r0
 movs r5,#8
1: lsr r0,r4,#28
 cmp r0,#9
 ite ls
 addls r0,#48
 addhi r0,#55
 bl uart_putc
 lsl r4,r4,#4
 subs r5,#1
 bne 1b
 pop {r4-r6,pc}
// Etapas solo durante los primeros dos cuadros.
.thumb_func
trace_stage:
 push {r4,lr}
 ldr r1,=serial_frames
 ldr r1,[r1]
 cmp r1,#2
 bhs 1f
 adds r0,#48
 bl uart_putc
 movs r0,#32
 bl uart_putc
1: pop {r4,pc}
.thumb_func
serial_report:
 push {r4,lr}
 ldr r0,=serial_frames
 ldr r1,[r0]
 adds r1,#1
 str r1,[r0]
 cmp r1,#1
 beq 1f
 ldr r0,=ticks
 ldr r1,[r0]
 ldr r0,=serial_last_tick
 ldr r2,[r0]
 subs r2,r1,r2
 cmp r2,#30
 blo 2f
1: ldr r0,=ticks
 ldr r1,[r0]
 ldr r0,=serial_last_tick
 str r1,[r0]
 ldr r0,=msg_t
 bl uart_string
 ldr r0,=ticks
 ldr r0,[r0]
 bl uart_hex
 ldr r0,=msg_f
 bl uart_string
 ldr r0,=serial_frames
 ldr r0,[r0]
 bl uart_hex
 ldr r0,=msg_e
 bl uart_string
 ldr r0,=i2c_errors
 ldr r0,[r0]
 bl uart_hex
 ldr r0,=msg_sr
 bl uart_string
 ldr r0,=last_twi_sr
 ldr r0,[r0]
 bl uart_hex
 ldr r0,=msg_b
 bl uart_string
 ldr r0,=raw_buttons
 ldr r0,[r0]
 bl uart_hex
 movs r0,#13
 bl uart_putc
 movs r0,#10
 bl uart_putc
2: pop {r4,pc}
.ltorg
.section .rodata
msg_t: .asciz "\r\nDIAG3 T="
msg_f: .asciz " F="
msg_e: .asciz " I2C_ERRORS="
msg_sr: .asciz " TWI_SR="
msg_b: .asciz " BUTTONS="
.section .bss
.balign 4
serial_frames: .space 4
serial_last_tick: .space 4
last_twi_sr: .space 4





/* ============================================================
   MEJORAS Y MULTIPLES PROYECTILES - ARM THUMB-2
   S: velocidad, D: doble disparo, R: cadencia rapida.
   Duracion individual: 150 cuadros, 5 segundos nominales.
   ============================================================ */
.section .text
.thumb_func
weapons_update:
 push {r4-r8,lr}
 ldr r4,=projectiles
 movs r5,#16
weapons_move:
 ldr r0,[r4]
 cmp r0,#0
 beq weapons_next
 ldr r0,[r4,#8]
 subs r0,#4
 str r0,[r4,#8]
 cmp r0,#9
 bge weapons_next
 movs r0,#0
 str r0,[r4]
weapons_next:
 adds r4,#12
 subs r5,#1
 bne weapons_move
 ldr r4,=shot_cooldown
 ldr r0,[r4]
 cmp r0,#0
 beq weapons_check
 subs r0,#1
 str r0,[r4]
 cmp r0,#0
 bne weapons_done
weapons_check:
 ldr r0,=buttons
 ldr r0,[r0]
 tst r0,#2
 beq weapons_done
 movs r0,#10
 ldr r1,=rapid_timer
 ldr r1,[r1]
 cmp r1,#0
 it ne
 movne r0,#3
 str r0,[r4]
 ldr r5,=game
 ldr r6,[r5,#4]
 ldr r7,[r5,#8]
 subs r7,#2
 ldr r0,=double_timer
 ldr r0,[r0]
 cmp r0,#0
 beq weapons_single
 adds r0,r6,#1
 mov r1,r7
 bl projectile_spawn
 adds r0,r6,#6
 mov r1,r7
 bl projectile_spawn
 b weapons_done
weapons_single:
 adds r0,r6,#3
 mov r1,r7
 bl projectile_spawn
weapons_done:
 pop {r4-r8,pc}

// r0=x, r1=y. Buscar hueco en un pool de 16 proyectiles.
.thumb_func
projectile_spawn:
 ldr r2,=projectiles
 movs r3,#16
spawn_slot:
 ldr r12,[r2]
 cmp r12,#0
 beq spawn_found
 adds r2,#12
 subs r3,#1
 bne spawn_slot
 bx lr
spawn_found:
 str r0,[r2,#4]
 str r1,[r2,#8]
 movs r0,#1
 str r0,[r2]
 bx lr

// r0=x enemigo, r1=y enemigo. Devuelve 1 si recibe un impacto.
.thumb_func
projectile_hit:
 push {r4-r8,lr}
 mov r4,r0
 mov r5,r1
 ldr r6,=projectiles
 movs r7,#16
hit_scan:
 ldr r0,[r6]
 cmp r0,#0
 beq hit_next
 ldr r0,[r6,#4]
 subs r0,r0,r4
 cmp r0,#7
 bhi hit_next
 ldr r0,[r6,#8]
 subs r0,r0,r5
 adds r0,#2
 cmp r0,#9
 bhi hit_next
 ldr r0,[r6]
 cmp r0,#2
 beq hit_piercing
 movs r0,#0
 str r0,[r6]
hit_piercing:
 movs r0,#1
 pop {r4-r8,pc}
hit_next:
 adds r6,#12
 subs r7,#1
 bne hit_scan
 movs r0,#0
 pop {r4-r8,pc}
.ltorg

.thumb_func
upgrades_update:
 push {r4-r8,lr}
 // Los tres efectos pueden coexistir y expiran por separado.
 ldr r4,=speed_timer
 movs r5,#3
upgrade_decay:
 ldr r0,[r4]
 cmp r0,#0
 it ne
 subne r0,#1
 str r0,[r4],#4
 subs r5,#1
 bne upgrade_decay
 ldr r4,=pickup_type
 ldr r5,[r4]
 cmp r5,#0
 bne pickup_fall
 ldr r0,=pickup_countdown
 ldr r1,[r0]
 cmp r1,#0
 beq pickup_create
 subs r1,#1
 str r1,[r0]
 b upgrades_done
pickup_create:
 movs r1,#90
 str r1,[r0]
 ldr r0,=pickup_cycle
 ldr r1,[r0]
 adds r1,#1
 cmp r1,#3
 it hi
 movhi r1,#1
 str r1,[r0]
 str r1,[r4]
 ldr r0,=game
 ldr r1,[r0,#4]
 adds r1,#24
 cmp r1,#16
 it lo
 movlo r1,#16
 cmp r1,#104
 it hi
 movhi r1,#104
 ldr r0,=pickup_x
 str r1,[r0]
 movs r1,#10
 str r1,[r0,#4]
 b upgrades_done
pickup_fall:
 ldr r6,=pickup_x
 ldr r7,[r6]
 ldr r8,[r6,#4]
 ldr r0,=game
 ldr r0,[r0,#32]
 movs r1,#2
 udiv r2,r0,r1
 mls r2,r2,r1,r0
 cmp r2,#0
 it eq
 addeq r8,#1
 str r8,[r6,#4]
 cmp r8,#56
 bgt pickup_remove
 ldr r0,=game
 ldr r1,[r0,#4]
 subs r1,r1,r7
 adds r1,#7
 cmp r1,#14
 bhi upgrades_done
 ldr r1,[r0,#8]
 subs r1,r1,r8
 adds r1,#7
 cmp r1,#14
 bhi upgrades_done
 // Tipo 1,2,3 corresponde a los tres temporizadores contiguos.
 subs r0,r5,#1
 ldr r1,=speed_timer
 add r1,r1,r0,lsl #2
 movw r0,#150
 str r0,[r1]
pickup_remove:
 movs r0,#0
 str r0,[r4]
upgrades_done:
 pop {r4-r8,pc}
.ltorg

.thumb_func
render_projectiles:
 push {r4-r6,lr}
 ldr r4,=projectiles
 movs r5,#16
projectile_draw_loop:
 ldr r0,[r4]
 cmp r0,#0
 beq projectile_draw_next
 ldr r0,[r4,#4]
 ldr r1,[r4,#8]
 bl pixel
 ldr r0,[r4,#4]
 ldr r1,[r4,#8]
 adds r1,#1
 bl pixel
 ldr r0,[r4]
 cmp r0,#2
 bne projectile_draw_next
 ldr r0,[r4,#4]
 ldr r1,[r4,#8]
 adds r1,#2
 bl pixel
 ldr r0,[r4,#4]
 ldr r1,[r4,#8]
 adds r1,#3
 bl pixel
projectile_draw_next:
 adds r4,#12
 subs r5,#1
 bne projectile_draw_loop
 pop {r4-r6,pc}

.thumb_func
render_powerups:
 push {r4-r8,lr}
 // HUD: letras visibles solo mientras el efecto esta activo.
 ldr r4,=upgrade_hud
 ldr r5,=speed_timer
 ldr r6,=upgrade_letters
 movs r7,#0
upgrade_hud_loop:
 ldr r0,[r5,r7,lsl #2]
 cmp r0,#0
 ite eq
 moveq r0,#32
 ldrbne r0,[r6,r7]
 strb r0,[r4,r7]
 adds r7,#1
 cmp r7,#3
 bne upgrade_hud_loop
 movs r0,#48
 movs r1,#0
 mov r2,r4
 bl text
 ldr r0,=pickup_type
 ldr r0,[r0]
 cmp r0,#0
 beq powerup_draw_done
 subs r0,#1
 ldr r1,=upgrade_letters
 ldrb r0,[r1,r0]
 ldr r1,=pickup_label
 strb r0,[r1]
 ldr r4,=pickup_x
 ldr r0,[r4]
 ldr r1,[r4,#4]
 ldr r2,=pickup_sprite
 bl sprite
 ldr r0,[r4]
 adds r0,#1
 ldr r1,[r4,#4]
 adds r1,#1
 ldr r2,=pickup_label
 bl text
powerup_draw_done:
 pop {r4-r8,pc}
.ltorg
.section .rodata
upgrade_letters: .ascii "SDR"
pickup_sprite: .byte 0xff,0x81,0x81,0x81,0x81,0x81,0x81,0xff
.section .bss
.balign 4
extra_state_start:
speed_timer: .space 4
double_timer: .space 4
rapid_timer: .space 4
shot_cooldown: .space 4
pickup_type: .space 4
pickup_x: .space 4
pickup_y: .space 4
pickup_countdown: .space 4
pickup_cycle: .space 4
upgrade_hud: .space 4
pickup_label: .space 4
projectiles: .space 192
special_charge: .space 4
explosions: .space 60
extra_state_end:


/* Rafaga lateral: cuatro proyectiles, A2 por flanco, recarga 150 cuadros. */
.section .text
.thumb_func
special_update:
 push {r4-r8,lr}
 ldr r4,=special_charge
 ldr r0,[r4]
 cmp r0,#150
 bhs special_check
 adds r0,#1
 str r0,[r4]
special_check:
 cmp r0,#150
 blo special_done
 ldr r0,=pressed
 ldr r0,[r0]
 tst r0,#1
 beq special_done
 // No consumir carga si el pool no permite los cuatro disparos.
 ldr r0,=projectiles
 movs r1,#16
 movs r2,#0
special_count_slots:
 ldr r3,[r0],#12
 cmp r3,#0
 it eq
 addeq r2,#1
 subs r1,#1
 bne special_count_slots
 cmp r2,#4
 blo special_done
 ldr r5,=game
 ldr r6,[r5,#4]
 subs r6,#9
 it mi
 movmi r6,#0
 cmp r6,#103
 it hi
 movhi r6,#103
 ldr r7,[r5,#8]
 subs r7,#2
 movs r8,#4
special_fire_loop:
 mov r0,r6
 mov r1,r7
 bl projectile_spawn_special
 adds r6,#8
 subs r8,#1
 bne special_fire_loop
 movs r0,#0
 str r0,[r4]
special_done:
 pop {r4-r8,pc}
.ltorg

// Barra de 20x7 pixeles entre las mejoras y el indicador de vidas.
.thumb_func
render_chargebar:
 push {r4-r8,lr}
 ldr r0,=special_charge
 ldr r0,[r0]
 movs r1,#18
 mul r0,r0,r1
 movs r1,#150
 udiv r6,r0,r1
 movs r4,#0
chargebar_column:
 movs r5,#0
chargebar_row:
 cmp r4,#0
 beq chargebar_plot
 cmp r4,#19
 beq chargebar_plot
 cmp r5,#0
 beq chargebar_plot
 cmp r5,#6
 beq chargebar_plot
 cmp r4,r6
 bhi chargebar_skip
chargebar_plot:
 add r0,r4,#68
 mov r1,r5
 bl pixel
chargebar_skip:
 adds r5,#1
 cmp r5,#7
 bne chargebar_row
 adds r4,#1
 cmp r4,#20
 bne chargebar_column
 pop {r4-r8,pc}
.ltorg



/* Proyectil especial: estado 2 significa perforante. */
.section .text
.thumb_func
projectile_spawn_special:
 ldr r2,=projectiles
 movs r3,#16
special_spawn_slot:
 ldr r12,[r2]
 cmp r12,#0
 beq special_spawn_found
 adds r2,#12
 subs r3,#1
 bne special_spawn_slot
 bx lr
special_spawn_found:
 str r0,[r2,#4]
 str r1,[r2,#8]
 movs r0,#2
 str r0,[r2]
 bx lr

// Cinco explosiones simultaneas. Registro: tiempo restante, X, Y.
.thumb_func
explosion_spawn:
 ldr r2,=explosions
 movs r3,#5
explosion_find:
 ldr r12,[r2]
 cmp r12,#0
 beq explosion_store
 adds r2,#12
 subs r3,#1
 bne explosion_find
 // Si todos estan ocupados, reutilizar el primero.
 ldr r2,=explosions
explosion_store:
 str r0,[r2,#4]
 str r1,[r2,#8]
 movs r0,#12
 str r0,[r2]
 bx lr

.thumb_func
explosions_update:
 ldr r0,=explosions
 movs r1,#5
explosion_decay:
 ldr r2,[r0]
 cmp r2,#0
 it ne
 subne r2,#1
 str r2,[r0],#12
 subs r1,#1
 bne explosion_decay
 bx lr
.ltorg

.thumb_func
render_explosions:
 push {r4-r6,lr}
 ldr r4,=explosions
 movs r5,#5
explosion_draw_loop:
 ldr r0,[r4]
 cmp r0,#0
 beq explosion_draw_next
 ldr r2,=explosion_small
 cmp r0,#8
 bgt explosion_draw
 ldr r2,=explosion_large
 cmp r0,#4
 bgt explosion_draw
 ldr r2,=explosion_sparks
explosion_draw:
 ldr r0,[r4,#4]
 ldr r1,[r4,#8]
 bl sprite
explosion_draw_next:
 adds r4,#12
 subs r5,#1
 bne explosion_draw_loop
 pop {r4-r6,pc}
.ltorg
.section .rodata
explosion_small: .byte 0x00,0x00,0x18,0x3c,0x3c,0x18,0x00,0x00
explosion_large: .byte 0x24,0x18,0x7e,0x3c,0x3c,0x7e,0x18,0x24
explosion_sparks: .byte 0x81,0x24,0x00,0x42,0x42,0x00,0x24,0x81





/* Record de la sesion: RAM separada del estado que reinicia new_game. */
.section .text
.thumb_func
render_best_score:
 push {r4-r8,lr}
 mov r4,r0 // fila de la linea TOP
 ldr r0,=high_score
 ldr r0,[r0]
 ldr r1,=best_digits+3
 movs r2,#10
 movs r3,#4
best_score_digits:
 udiv r5,r0,r2
 mls r6,r5,r2,r0
 adds r6,#48
 strb r6,[r1],#-1
 mov r0,r5
 subs r3,#1
 bne best_score_digits
 movs r0,#37
 mov r1,r4
 ldr r2,=best_score_label
 bl text
 movs r0,#67
 mov r1,r4
 ldr r2,=best_digits
 bl text
 pop {r4-r8,pc}
.ltorg
.section .rodata
best_score_label: .asciz "TOP:"
.section .bss
.balign 4
high_score: .space 4
best_digits: .space 8


/* MOD: MUEVETE O DUERMETE. Simon ritmico, cinco vidas. */
.section .text
.thumb_func
mod_update:
 push {r4-r8,lr}
 ldr r0,=mod_fx
 ldr r1,[r0]
 cmp r1,#0
 it ne
 subne r1,#1
 str r1,[r0]
 ldr r0,=mod_perfect
 ldr r1,[r0]
 cmp r1,#0
 it ne
 subne r1,#1
 str r1,[r0]
 ldr r4,=mod_state
 ldr r0,[r4,#4]
 adds r0,#1
 str r0,[r4,#4]
 // Evento: 1 arriba, 2 abajo, 3 izquierda, 4 derecha, 5 push.
 movs r5,#0
 ldr r0,=ax
 ldr r1,[r0]
 ldr r2,[r0,#4]
 ldr r3,=1400
 cmp r1,r3
 it lo
 movlo r5,#3
 cmp r2,r3
 it lo
 movlo r5,#1
 ldr r3,=2700
 cmp r1,r3
 it hi
 movhi r5,#4
 cmp r2,r3
 it hi
 movhi r5,#2
 ldr r0,=pressed
 ldr r0,[r0]
 cmp r0,#0
 it ne
 movne r5,#6
 str r5,[r4,#32]
 mov r0,r5
 bl mod_filtered_event
 mov r5,r0
 ldr r0,[r4]
 cmp r0,#8
 beq mod_countdown_update
 cmp r0,#7
 beq mod_tutorial_update
 cmp r0,#1
 bne mod_dispatch
 ldr r1,=mod_fx
 ldr r1,[r1]
 cmp r1,#0
 bne mod_done
mod_dispatch:
 cmp r0,#0
 beq mod_intro
 cmp r0,#3
 beq mod_dead
 cmp r0,#4
 beq mod_feedback
 ldr r6,[r4,#8]
 adds r6,#1
 str r6,[r4,#8]
 ldr r7,[r4,#12]
 cmp r0,#1
 beq mod_demo
 // Una sola decision por pulso. Plazo exclusivamente en ticks TC0.
 ldr r0,=ticks
 ldr r0,[r0]
 ldr r1,=mod_response_deadline
 ldr r1,[r1]
 subs r0,r0,r1
 movs r3,#0
 cmp r0,#0
 blt mod_judge_not_expired
 movs r3,#1
mod_judge_not_expired:
 // Tiempo visual sincronizado con el mismo plazo, sin otro reloj.
 ldr r2,[r4,#12]
 adds r0,r0,r2
 cmp r0,r2
 ble mod_progress_clamped
 mov r0,r2
mod_progress_clamped:
 str r0,[r4,#8]
 ldr r0,=mod_sequence
 ldr r1,[r4,#16]
 ldrb r0,[r0,r1]
 mov r1,r5
 ldr r2,[r4,#36]
 ldr r12,[r4,#32]
 ldr r6,=buttons
 ldr r6,[r6]
 orr r12,r12,r6
 bl mod_judge
 str r1,[r4,#36]
 cmp r0,#1
 beq mod_beat_success
 cmp r0,#2
 beq mod_miss
 cmp r0,#3
 beq mod_timeout
 b mod_done
mod_beat_success:
 ldr r0,[r4,#28]
 adds r0,#10
 str r0,[r4,#28]
 bl mod_reset_deadline
 ldr r0,=mod_perfect
 movs r1,#8
 str r1,[r0]
 movs r0,#0
 str r0,[r4,#8]
 str r0,[r4,#36]
 ldr r0,[r4,#16]
 adds r0,#1
 str r0,[r4,#16]
 ldr r1,[r4,#20]
 cmp r0,r1
 blo mod_done
 movs r0,#4
 str r0,[r4]
 movs r0,#0
 str r0,[r4,#8]
 b mod_done
mod_demo:
 cmp r6,r7
 blo mod_done
 movs r0,#0
 str r0,[r4,#8]
 ldr r0,[r4,#16]
 adds r0,#1
 str r0,[r4,#16]
 ldr r1,[r4,#20]
 cmp r0,r1
 blo mod_done
 movs r0,#2
 str r0,[r4]
 bl mod_reset_deadline
 movs r0,#0
 str r0,[r4,#16]
 str r0,[r4,#36]
 b mod_done
mod_timeout:
 ldr r0,=mod_failure_reason
 movs r1,#1
 str r1,[r0]
 b mod_miss_effect
mod_miss:
 ldr r0,=mod_failure_reason
 movs r1,#0
 str r1,[r0]
mod_miss_effect:
 ldr r0,=mod_fx
 movs r1,#12
 str r1,[r0]
 ldr r0,=mod_perfect
 movs r1,#0
 str r1,[r0]
 ldr r0,=mod_three_misses
 ldr r1,[r0]
 adds r1,#1
 cmp r1,#3
 blo mod_store_misses
 movs r1,#0
 ldr r2,[r4,#24]
 subs r2,#1
 str r2,[r4,#24]
 cmp r2,#0
 beq mod_all_lives_lost
mod_store_misses:
 str r1,[r0]
 bl mod_reset_deadline
 movs r0,#0
 str r0,[r4,#8]
 str r0,[r4,#36]
 ldr r0,[r4,#16]
 adds r0,#1
 str r0,[r4,#16]
 ldr r1,[r4,#20]
 cmp r0,r1
 blo mod_done
 movs r0,#4
 str r0,[r4]
 b mod_done
mod_all_lives_lost:
 str r1,[r0]
 movs r0,#3
 str r0,[r4]
 movs r0,#0
 str r0,[r4,#8]
 b mod_done
mod_intro:
 cmp r5,#6
 bne mod_done
 ldr r0,[r4,#4]
 cmp r0,#120
 bhs mod_open_tutorial
 movs r0,#120
 str r0,[r4,#4]
 b mod_done
mod_open_tutorial:
 movs r0,#7
 str r0,[r4]
 movs r0,#0
 str r0,[r4,#8]
 b mod_done
mod_tutorial_update:
 ldr r0,[r4,#8]
 adds r0,#1
 str r0,[r4,#8]
 cmp r5,#6
 beq mod_start_countdown
 cmp r0,#180
 blo mod_done
mod_start_countdown:
 movs r0,#8
 str r0,[r4]
 movs r0,#0
 str r0,[r4,#8]
 b mod_done
mod_countdown_update:
 ldr r0,[r4,#8]
 adds r0,#1
 str r0,[r4,#8]
 cmp r0,#120
 blo mod_done
mod_begin:
 ldr r0,=mod_three_misses
 movs r1,#0
 str r1,[r0]
 ldr r0,=mod_new_record
 movs r1,#0
 str r1,[r0]
 ldr r0,=mod_fx
 str r1,[r0]
 ldr r0,=mod_perfect
 str r1,[r0]
 movs r0,#5
 str r0,[r4,#24]
 movs r0,#0
 str r0,[r4,#28]
 movs r0,#3
 str r0,[r4,#20]
 movs r0,#32
 str r0,[r4,#12]
 b mod_round
mod_dead:
 ldr r0,[r4,#8]
 adds r0,#1
 str r0,[r4,#8]
 cmp r0,#120
 blo mod_done
 cmp r5,#6
 beq mod_begin
 b mod_done
mod_feedback:
 ldr r0,[r4,#8]
 adds r0,#1
 str r0,[r4,#8]
 cmp r0,#45
 blo mod_done
 ldr r0,[r4,#20]
 cmp r0,#12
 it lo
 addlo r0,#1
 str r0,[r4,#20]
 ldr r0,[r4,#12]
 cmp r0,#12
 it hi
 subhi r0,#2
 str r0,[r4,#12]
mod_round:
 movs r0,#1
 str r0,[r4]
 movs r0,#0
 str r0,[r4,#8]
 str r0,[r4,#16]
 str r0,[r4,#36]
 ldr r6,=mod_sequence
 ldr r7,[r4,#20]
 ldr r0,[r4,#4]
mod_generate:
 movs r1,#17
 mul r0,r0,r1
 adds r0,#23
 movs r1,#6
 udiv r2,r0,r1
 mls r2,r2,r1,r0
 adds r2,#1
 strb r2,[r6],#1
 subs r7,#1
 bne mod_generate
mod_done:
 ldr r0,[r4,#28]
 ldr r1,=high_score
 ldr r2,[r1]
 cmp r0,r2
 bls mod_record_done
 str r0,[r1]
 ldr r1,=mod_new_record
 movs r0,#1
 str r0,[r1]
mod_record_done:
 pop {r4-r8,pc}
.ltorg

.thumb_func
mod_render:
 push {r4-r8,lr}
 ldr r0,=framebuffer
 movs r1,#0
 movw r2,#256
mod_clear:
 str r1,[r0],#4
 subs r2,#1
 bne mod_clear
 ldr r4,=mod_state
 ldr r0,[r4]
 cmp r0,#3
 beq mod_draw_dead
 ldr r0,=mod_fx
 ldr r0,[r0]
 // FALLO se dibuja sobre la escena, sin cambiar de pantalla.
 ldr r0,[r4]
 cmp r0,#8
 beq mod_draw_countdown
 cmp r0,#7
 beq mod_draw_tutorial
 cmp r0,#0
 beq mod_draw_intro
 cmp r0,#3
 beq mod_draw_dead
 cmp r0,#4
 beq mod_draw_feedback
mod_draw_pulse:
 bl mod_score_panel
 ldr r0,=mod_sequence
 ldr r1,[r4,#16]
 ldrb r0,[r0,r1]
 ldr r1,[r4,#12]
 ldr r2,[r4,#8]
 subs r1,r1,r2
 adds r1,#4
 cmp r1,#18
 it hi
 movhi r1,#18
 bl mod_shape
 pop {r4-r8,pc}
mod_draw_intro:
 bl mod_machine_intro
 pop {r4-r8,pc}
mod_draw_countdown:
 bl mod_countdown_scene
 pop {r4-r8,pc}
mod_draw_tutorial:
 bl mod_tutorial_scene
 pop {r4-r8,pc}
mod_draw_dead:
 ldr r6,[r4,#8]
 cmp r6,#35
 bhs cinema_break
 and r0,r6,#7
 adds r0,#5
 movs r1,#20
 ldr r2,=mod_oh
 bl text
 mov r0,r6
 bl mod_particles
 b cinema_return
cinema_break:
 cmp r6,#85
 bhs cinema_sleep
 mov r0,r6
 bl mod_particles
 bl mod_sleeping_person
 movs r0,#35
 mov r1,r6
 subs r1,#35
 lsrs r1,#1
 ldr r2,=happy_person
 bl sprite
 b cinema_return
cinema_sleep:
 bl mod_result_scene
 pop {r4-r8,pc}
 // Persona y cama dibujadas por mod_sleeping_person.
 mov r0,r6
 lsrs r0,#3
 and r0,#7
 adds r0,#83
 movs r1,#5
 ldr r2,=mod_zzz
 bl text
 movs r0,#16
 movs r1,#42
 ldr r2,=mod_rest
 bl text
 cmp r6,#120
 blo cinema_return
 movs r0,#7
 movs r1,#54
 ldr r2,=mod_retry
 bl text
cinema_return:
 pop {r4-r8,pc}
mod_draw_error:
 mov r6,r0
 // Impacto expansivo y letras con sacudida horizontal.
 movs r0,#5
 rsb r1,r6,#22
 bl mod_shape
 and r0,r6,#3
 adds r0,#29
 movs r1,#26
 ldr r2,=mod_fail_text
 ldr r0,=mod_failure_reason
 ldr r0,[r0]
 cmp r0,#0
 it ne
 ldrne r2,=mod_slow_text
 and r0,r6,#3
 adds r0,#29
 bl text
 mov r0,r6
 bl mod_particles
 pop {r4-r8,pc}
mod_draw_feedback:
 movs r0,#13
 movs r1,#22
 ldr r2,=mod_success
 bl text
 movs r0,#22
 movs r1,#40
 ldr r2,=mod_faster
 bl text
 pop {r4-r8,pc}
.ltorg
.section .rodata
mod_title: .asciz "MOD"
mod_subtitle: .asciz "MUEVETE O DUERMETE"
mod_taunt: .asciz "TUS REFLEJOS... JA"
mod_skip: .asciz "PUSH PARA SALTAR"
mod_watch: .asciz "OBSERVA, NO JUEGUES"
mod_repeat: .asciz "RESPONDE AHORA"
mod_oh: .asciz "OHHHHHHHHHHHHHHHHH"
mod_rest: .asciz "VE A DESCANSAR"
mod_retry: .asciz "PUSH: REINTENTAR"
mod_success: .asciz "SIGUES VIVO"
mod_faster: .asciz "AHORA MAS RAPIDO"
mod_neutral: .asciz "CENTRO"
mod_up: .asciz "ARRIBA"
mod_down: .asciz "ABAJO"
mod_left: .asciz "IZQUIERDA"
mod_right: .asciz "DERECHA"
mod_push: .asciz "QUIETO"
mod_press: .asciz "PULSA"
.balign 4
mod_cues: .word mod_neutral,mod_up,mod_down,mod_left,mod_right,mod_push,mod_press
.section .bss
.balign 4
mod_state: .space 40
mod_sequence: .space 16
mod_digit: .space 4


// Flecha de contorno que se contrae; centro = boton cuadrado sin pulsar.
.section .text
.thumb_func
mod_shape:
 push {r4-r10,lr}
 mov r4,r0
 mov r5,r1
 movs r0,#3
 udiv r8,r5,r0
 neg r7,r5
shape_y:
 neg r6,r5
shape_x:
 mov r9,r6
 cmp r9,#0
 it mi
 rsbmi r9,r9,#0
 cmp r4,#6
 beq shape_button
 cmp r4,#5
 beq shape_center
 cmp r7,#0
 bgt shape_stem
 add r0,r7,r5
 cmp r9,r0
 beq shape_plot
 cmp r7,#0
 bne shape_next
 cmp r9,r8
 bhs shape_plot
 b shape_next
shape_stem:
 cmp r9,r8
 bhi shape_next
 cmp r9,r8
 beq shape_plot
 cmp r7,r5
 beq shape_plot
 b shape_next
shape_button:
 mul r0,r6,r6
 mla r0,r7,r7,r0
 mul r1,r5,r5
 cmp r0,r1
 bhi shape_next
 subs r2,r5,#2
 mul r2,r2,r2
 cmp r0,r2
 bhs shape_plot
 cmp r9,#1
 bhi shape_next
 adds r0,r7,#1
 cmp r0,#0
 blt shape_next
 cmp r7,#1
 ble shape_plot
 b shape_next
shape_center:
 cmp r9,r5
 beq shape_plot
 mov r0,r7
 cmp r0,#0
 it mi
 rsbmi r0,r0,#0
 cmp r0,r5
 bne shape_next
shape_plot:
 mov r0,r6
 mov r1,r7
 cmp r4,#2
 bne shape_not_down
 neg r1,r1
 b shape_translate
shape_not_down:
 cmp r4,#3
 bne shape_not_left
 mov r0,r7
 mov r1,r6
 b shape_translate
shape_not_left:
 cmp r4,#4
 bne shape_translate
 neg r0,r7
 mov r1,r6
shape_translate:
 adds r0,#64
 adds r1,#33
 bl pixel
shape_next:
 adds r6,#1
 cmp r6,r5
 ble shape_x
 adds r7,#1
 cmp r7,r5
 ble shape_y
 pop {r4-r10,pc}
.ltorg


// Particulas geometricas animadas, recortadas por pixel().
.section .text
.thumb_func
mod_particles:
 push {r4-r8,lr}
 mov r4,r0
 movs r5,#0
particle_loop:
 movs r0,#19
 mul r6,r5,r0
 add r6,r6,r4
 and r6,#127
 movs r0,#7
 mul r7,r5,r0
 add r7,r7,r4,lsl #1
 and r7,#63
 mov r0,r6
 mov r1,r7
 bl pixel
 add r0,r6,#1
 mov r1,r7
 bl pixel
 mov r0,r6
 add r1,r7,#1
 bl pixel
 adds r5,#1
 cmp r5,#24
 bne particle_loop
 pop {r4-r8,pc}
.ltorg
.section .rodata
mod_fail_text: .asciz "ERA EL OTRO"
mod_crash: .asciz "REFLEJOS: RIP"
mod_sleep_face: .asciz "-_-"
mod_zzz: .asciz "ZZZ"
.section .bss
.balign 4
mod_fx: .space 4


.section .text
.thumb_func
mod_intro_arrows:
 push {r4-r8,lr}
 ldr r0,=mod_state
 ldr r4,[r0,#4]
 movs r5,#0
intro_arrow_loop:
 movs r0,#23
 mul r6,r5,r0
 add r6,r6,r4
 and r6,#127
 movs r0,#13
 mul r7,r5,r0
 add r7,r7,r4
 and r7,#63
 movs r8,#0
intro_arrow_line:
 add r0,r6,r8
 mov r1,r7
 bl pixel
 add r0,r6,r8
 add r1,r7,r8
 bl pixel
 add r0,r6,r8
 sub r1,r7,r8
 bl pixel
 adds r8,#1
 cmp r8,#5
 bne intro_arrow_line
 adds r5,#1
 cmp r5,#10
 bne intro_arrow_loop
 pop {r4-r8,pc}
.ltorg

.thumb_func
mod_sleeping_person:
 push {r4-r8,lr}
 // Cama con cabecera, colchon, manta y patas.
 movs r4,#26
bed_rail:
 mov r0,r4
 movs r1,#32
 bl pixel
 mov r0,r4
 movs r1,#34
 bl pixel
 adds r4,#1
 cmp r4,#103
 bne bed_rail
 movs r4,#17
bed_head:
 movs r0,#25
 mov r1,r4
 bl pixel
 adds r4,#1
 cmp r4,#39
 bne bed_head
 movs r4,#34
bed_legs:
 movs r0,#29
 mov r1,r4
 bl pixel
 movs r0,#100
 mov r1,r4
 bl pixel
 adds r4,#1
 cmp r4,#39
 bne bed_legs
 // Cabeza dormida sobre almohada.
 movs r0,#31
 movs r1,#22
 ldr r2,=mod_head_sprite
 bl sprite
 // Manta sube y baja un pixel con la respiracion.
 ldr r0,=mod_state
 ldr r0,[r0,#8]
 lsrs r0,#4
 and r0,#1
 add r5,r0,#23
 movs r4,#44
blanket_top:
 mov r0,r4
 mov r1,r5
 bl pixel
 adds r4,#1
 cmp r4,#98
 bne blanket_top
 mov r4,r5
blanket_sides:
 movs r0,#44
 mov r1,r4
 bl pixel
 movs r0,#98
 mov r1,r4
 bl pixel
 adds r4,#1
 cmp r4,#32
 bne blanket_sides
 bl mod_bed_details
 pop {r4-r8,pc}
.ltorg
.section .rodata
mod_head_sprite: .byte 0x3c,0x42,0x52,0x52,0x42,0x52,0x42,0x3c



.section .text
.thumb_func
mod_number:
 push {r4-r8,lr}
 mov r7,r1
 mov r8,r2
 ldr r1,=mod_number_buffer+3
 movs r2,#10
 movs r3,#4
mod_number_loop:
 udiv r5,r0,r2
 mls r6,r5,r2,r0
 adds r6,#48
 strb r6,[r1],#-1
 mov r0,r5
 subs r3,#1
 bne mod_number_loop
 mov r0,r7
 mov r1,r8
 ldr r2,=mod_number_buffer
 bl text
 pop {r4-r8,pc}
.thumb_func
mod_score_panel:
 push {r4,lr}
 ldr r4,=mod_state
 ldr r0,[r4,#28]
 movs r1,#0
 movs r2,#0
 bl mod_number
 ldr r0,[r4,#24]
 adds r0,#48
 ldr r2,=mod_digit
 strb r0,[r2]
 movs r0,#120
 movs r1,#0
 bl text
 movs r0,#108
 movs r1,#0
 ldr r2,=mod_life_label
 bl text
 ldr r0,=mod_fx
 ldr r0,[r0]
 cmp r0,#0
 bne score_panel_failure
 ldr r0,=mod_perfect
 ldr r0,[r0]
 cmp r0,#0
 bne score_panel_perfect
 ldr r0,[r4]
 cmp r0,#1
 ite eq
 ldreq r2,=mod_observe_short
 ldrne r2,=mod_respond_short
 movs r0,#40
 movs r1,#55
 bl text
 b score_panel_end
score_panel_perfect:
 movs r0,#40
 movs r1,#55
 ldr r2,=perfect_label
 bl text
 b score_panel_end
score_panel_failure:
 movs r0,#49
 movs r1,#55
 ldr r2,=mod_fail_overlay
 bl text
score_panel_end:
 pop {r4,pc}
.thumb_func
mod_machine_intro:
 push {r4-r8,lr}
 ldr r4,=mod_state
 ldr r6,[r4,#4]
 cmp r6,#120
 bhs machine_title
 movs r0,#5
 lsr r1,r6,#2
 adds r1,#3
 bl mod_shape
 movs r0,#22
 movs r1,#27
 ldr r2,=machine_loading
 bl text
 movs r7,#0
machine_bar:
 add r0,r7,#4
 movs r1,#60
 bl pixel
 adds r7,#1
 cmp r7,r6
 blo machine_bar
 b machine_end
machine_title:
 bl mod_intro_arrows
 movs r0,#55
 movs r1,#3
 ldr r2,=mod_title
 bl text
 movs r0,#7
 movs r1,#15
 ldr r2,=mod_subtitle
 bl text
 bl mod_dancers
 movs r0,#19
 movs r1,#54
 ldr r2,=start_mod_label
 bl text
machine_end:
 pop {r4-r8,pc}
.thumb_func
mod_dancers:
 push {r4-r6,lr}
 ldr r0,=mod_state
 ldr r0,[r0,#4]
 lsrs r0,#2
 and r0,#3
 rsb r4,r0,#38
 movs r0,#39
 mov r1,r4
 ldr r2,=happy_person
 bl sprite
 movs r0,#81
 add r1,r4,#2
 ldr r2,=happy_person
 bl sprite
 pop {r4-r6,pc}
.thumb_func
mod_tutorial_scene:
 push {r4,lr}
 ldr r0,=mod_state
 ldr r0,[r0,#8]
 lsls r0,#1
 rsb r0,r0,#128
 movs r1,#0
 ldr r2,=mod_lives_scroll
 bl text
 movs r0,#7
 movs r1,#14
 ldr r2,=tutorial_row1
 bl text
 movs r0,#7
 movs r1,#25
 ldr r2,=tutorial_row2
 bl text
 movs r0,#7
 movs r1,#36
 ldr r2,=tutorial_row3
 bl text
 movs r0,#7
 movs r1,#53
 ldr r2,=tutorial_skip
 bl text
 pop {r4,pc}
.thumb_func
mod_result_scene:
 push {r4-r8,lr}
 ldr r4,=mod_state
 ldr r0,=mod_new_record
 ldr r0,[r0]
 cmp r0,#0
 beq result_not_record
 movs r0,#22
 movs r1,#3
 ldr r2,=record_label
 bl text
 bl mod_dancers
 b result_points
result_not_record:
 ldr r0,=high_score
 ldr r0,[r0]
 ldr r1,[r4,#28]
 cmp r1,#30
 blo result_humiliation
 // CASIII si llega al 80 por ciento del record previo.
 movs r2,#5
 mul r1,r1,r2
 lsls r0,r0,#2
 cmp r1,r0
 blo result_sleep
 movs r0,#43
 movs r1,#3
 ldr r2,=almost_label
 bl text
 b result_bed
result_humiliation:
 movs r0,#16
 movs r1,#3
 ldr r2,=humiliation_label
 bl text
 b result_bed
result_sleep:
 movs r0,#16
 movs r1,#3
 ldr r2,=mod_rest
 bl text
result_bed:
 bl mod_sleeping_person
 movs r0,#86
 movs r1,#13
 ldr r2,=mod_zzz
 bl text
result_points:
 ldr r0,[r4,#28]
 movs r1,#20
 movs r2,#44
 bl mod_number
 ldr r0,=high_score
 ldr r0,[r0]
 movs r1,#84
 movs r2,#44
 bl mod_number
 movs r0,#7
 movs r1,#55
 ldr r2,=mod_retry
 bl text
 pop {r4-r8,pc}
.ltorg
.section .rodata
perfect_label: .asciz "PERFECTO"
machine_loading: .asciz "ENCENDIENDO..."
start_mod_label: .asciz "PULSA PARA INICIAR"
tutorial_title: .asciz "SIGUE EL RITMO"
tutorial_row1: .asciz "ARRIBA    ABAJO"
tutorial_row2: .asciz "IZQUIERDA DERECHA"
tutorial_row3: .asciz "QUIETO    PULSA"
tutorial_skip: .asciz "PUSH: SALTAR CLASE"
record_label: .asciz "NUEVO RECORD"
almost_label: .asciz "CASIII"
humiliation_label: .asciz "VOLVER A INTENTAR"
happy_person: .byte 0x24,0x14,0x7a,0x1f,0x1f,0x7a,0x14,0x24
.section .bss
.balign 4
mod_perfect: .space 4
mod_new_record: .space 4
mod_number_buffer: .space 8


.section .text
.thumb_func
mod_countdown_scene:
 push {r4,lr}
 ldr r0,=mod_state
 ldr r0,[r0,#8]
 cmp r0,#90
 bhs countdown_go
 movs r1,#30
 udiv r0,r0,r1
 adds r0,#49
 movs r1,#54
 movs r2,#18
 bl mod_big_character
 pop {r4,pc}
countdown_go:
 movs r0,#71
 movs r1,#38
 movs r2,#18
 bl mod_big_character
 movs r0,#79
 movs r1,#66
 movs r2,#18
 bl mod_big_character
 pop {r4,pc}
.ltorg
// Caracter 5x7 ampliado cuatro veces: 20x28 pixeles.
.thumb_func
mod_big_character:
 push {r4-r10,lr}
 mov r4,r1
 mov r5,r2
 subs r0,#32
 movs r1,#5
 mul r0,r0,r1
 ldr r6,=font
 add r6,r0
 movs r7,#0
big_column:
 movs r8,#0
big_row:
 ldrb r0,[r6,r7]
 lsr r0,r0,r8
 tst r0,#1
 beq big_next
 movs r9,#0
big_fill:
 and r0,r9,#3
 add r0,r0,r7,lsl #2
 add r0,r4
 lsr r1,r9,#2
 add r1,r1,r8,lsl #2
 add r1,r5
 bl pixel
 adds r9,#1
 cmp r9,#16
 bne big_fill
big_next:
 adds r8,#1
 cmp r8,#7
 bne big_row
 adds r7,#1
 cmp r7,#5
 bne big_column
 pop {r4-r10,pc}
.ltorg
.section .rodata
mod_lives_scroll: .asciz "TIENES 5 VIDAS. SIGUE EL RITMO."
mod_slow_text: .asciz "MUY LENTO"
.section .bss
.balign 4
mod_failure_reason: .space 4


.section .text
.thumb_func
mod_reset_deadline:
 ldr r0,=ticks
 ldr r0,[r0]
 ldr r1,=mod_state
 ldr r1,[r1,#12]
 adds r0,r0,r1
 ldr r1,=mod_response_deadline
 str r0,[r1]
 bx lr
.ltorg
.section .bss
.balign 4
mod_response_deadline: .space 4


// Una direccion necesita centro previo y dos muestras estables.
.section .text
.thumb_func
mod_filtered_event:
 ldr r1,=mod_input_filter
 cmp r0,#6
 beq filter_push
 cmp r0,#0
 beq filter_neutral
 movs r2,#0
 str r2,[r1,#8]
 ldr r2,[r1]
 cmp r2,r0
 beq filter_same
 str r0,[r1]
 movs r2,#1
 str r2,[r1,#4]
 b filter_none
filter_same:
 ldr r2,[r1,#4]
 cmp r2,#2
 bhs filter_check_arm
 adds r2,#1
 str r2,[r1,#4]
filter_check_arm:
 ldr r2,[r1,#12]
 cmp r2,#0
 beq filter_none
 movs r2,#0
 str r2,[r1,#12]
 bx lr
filter_neutral:
 movs r2,#0
 str r2,[r1]
 str r2,[r1,#4]
 ldr r2,[r1,#8]
 cmp r2,#3
 bhs filter_none
 adds r2,#1
 str r2,[r1,#8]
 cmp r2,#3
 bne filter_none
 movs r2,#1
 str r2,[r1,#12]
filter_none:
 movs r0,#0
 bx lr
filter_push:
 movs r2,#0
 str r2,[r1,#12]
 bx lr
.ltorg
.section .bss
.balign 4
mod_input_filter: .space 16


.section .text
.thumb_func
mod_bed_details:
 push {r4-r8,lr}
 // Almohada de 16 pixeles y cabeza con pelo y ojo cerrado.
 movs r0,#28
 movs r1,#26
 ldr r2,=pillow_left
 bl sprite
 movs r0,#36
 movs r1,#26
 ldr r2,=pillow_right
 bl sprite
 movs r0,#32
 movs r1,#18
 ldr r2,=sleep_head_detail
 bl sprite
 // Brazo por encima de la manta.
 movs r0,#40
 movs r1,#24
 ldr r2,=sleep_arm
 bl sprite
 // Costuras de la manta, separadas de los bordes.
 movs r4,#51
blanket_stitch_column:
 movs r5,#27
blanket_stitch_row:
 mov r0,r4
 mov r1,r5
 bl pixel
 adds r5,#2
 cmp r5,#32
 blo blanket_stitch_row
 adds r4,#9
 cmp r4,#94
 blo blanket_stitch_column
 pop {r4-r8,pc}
.ltorg
.section .rodata
mod_fail_overlay: .asciz "FALLO"
pillow_left: .byte 0x3c,0x42,0x42,0x42,0x42,0x42,0x42,0x42
pillow_right: .byte 0x42,0x42,0x42,0x42,0x42,0x42,0x42,0x3c
sleep_head_detail: .byte 0x1e,0x3f,0x61,0x51,0x51,0x41,0x22,0x1c
sleep_arm: .byte 0x04,0x0c,0x14,0x14,0x14,0x14,0x0c,0x04
.section .bss
.balign 4
mod_three_misses: .space 4

.section .rodata
mod_life_label: .asciz "V:"
mod_observe_short: .asciz "OBSERVA"
mod_respond_short: .asciz "TU TURNO"


// Decision comprobable sin perifericos.
// r0 esperado (1..6), r1 evento nuevo (0..6), r2 respuesta aceptada,
// r3 plazo vencido (0/1), r12 entradas sostenidas (0=centro y botones libres).
// Devuelve r0: 0 espera, 1 acierto, 2 error, 3 sin respuesta; r1: aceptada.
.section .text
.thumb_func
mod_judge:
 cmp r0,#5
 beq judge_quiet
 cmp r1,#0
 beq judge_deadline
 cmp r1,r0
 bne judge_wrong
 mov r2,r1
judge_deadline:
 cmp r3,#0
 beq judge_wait
 cmp r2,r0
 beq judge_success
 b judge_timeout
judge_quiet:
 cmp r12,#0
 bne judge_wrong
 cmp r3,#0
 beq judge_wait
 b judge_success
judge_wait:
 mov r1,r2
 movs r0,#0
 bx lr
judge_success:
 mov r1,r2
 movs r0,#1
 bx lr
judge_wrong:
 mov r1,r2
 movs r0,#2
 bx lr
judge_timeout:
 mov r1,r2
 movs r0,#3
 bx lr
.ltorg
