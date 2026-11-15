# Space Battle para Arduino Due — versión para validar

## Estado real
Se reemplaza el prototipo C++/Arduino por un firmware ARM Thumb-2 independiente.
Incluye arranque, vectores, acceso a registros, ADC, GPIO, TWI1, TC0/NVIC,
framebuffer de 1024 bytes, fuente, sprites, menú, movimiento X/Y, disparo,
cinco enemigos, colisiones, marcador de puntos/vidas, Game Over y reinicio.
No necesita SpaceBattle.ino, game.S, Arduino API, Wire ni U8g2.

La revisión de código está realizada. NO se ha completado el ensamblado/enlace:
el ejecutable ARM instalado no pudo iniciarse en el entorno disponible.
NO hay binario validado ni prueba física. No presentar como firmware probado.

## Archivos
- space_battle.s: programa completo, incluido startup y tabla de vectores.
- linker.ld: Flash desde 0x00080000 y SRAM desde 0x20070000.
- build.ps1: ensamblar, enlazar, crear BIN, inspeccionar símbolos y desensamblar.
- upload.ps1: compilar y cargar mediante bossac con verificación de Flash.

## Conexiones
| Elemento | Due |
|---|---|
| Joystick VRx | A0 / PA16 / AD7 |
| Joystick VRy | A1 / PA24 / AD6 |
| Joystick SW | A2 / PA23 |
| Joystick VCC y GND | 3V3 y GND |
| Botón disparo | D7 / PC23 y GND |
| OLED SDA | SDA20 / PB12 |
| OLED SCL | SCL21 / PB13 |
| OLED GND | GND |
| OLED VCC | Alimentación compatible con el módulo y lógica de 3,3 V |

A2 y D7 son entradas activas en bajo con pull-up interno.
No aplicar 5 V a las entradas del Due. Las resistencias pull-up I2C deben ir
hacia 3,3 V; si el módulo no las tiene, añadir aproximadamente 4,7 kΩ.
OLED SH1106 128x64 I2C, dirección 0x3C. Para 0x3D cambiar OLED_ADDR.
Se asume un módulo con circuito de reset propio y bomba interna DC/DC.

## Preparar
1. Extraer esta carpeta completa en Documentos u otra carpeta propia.
2. Instalar Arduino SAM Boards desde el gestor de placas de Arduino IDE,
   si no estuviera instalado. No se necesitan bibliotecas gráficas.
3. Abrir PowerShell dentro de la carpeta extraída.
4. No combinar estos archivos con los del prototipo anterior.

## Compilar primero
```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\build.ps1
```
Debe terminar con «Ensamblado y enlace correctos».
Se generan build\space_battle.elf, .bin, .o, .map y disassembly.txt.
Si aparece un error, conservar el texto completo; no intentar cargar un binario antiguo.

Si no detecta el toolchain:
```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\build.ps1 -Toolchain "C:\ruta\arm-none-eabi-gcc\4.8.3-2014q1\bin"
```

## Cargar
Usar exclusivamente el USB Programming Port del Due y cerrar el monitor serie.
Consultar el puerto COM en el Administrador de dispositivos.
Sustituir COM5 por el puerto real:
```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\upload.ps1 -Port COM5
```
Este paso reemplaza el programa anterior de la placa. El script compila,
abre el puerto a 1200 baudios para activar el borrado del Programming Port,
y ejecuta bossac con borrado, escritura, verificación, boot desde Flash y reset.
La verificación de bossac comprueba bytes escritos, no el comportamiento del juego.

Para indicar bossac manualmente:
```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\upload.ps1 -Port COM5 -Bossac "C:\ruta\bossac.exe"
```
Si no entra al cargador: mantener ERASE unos dos segundos, soltarlo, pulsar RESET
y repetir. Native USB no está implementado en este firmware.

## Controles
A2 o D7 inicia desde el menú. Joystick mueve X/Y. Mantener D7 repite disparos,
con un proyectil simultáneo. Destruir un enemigo suma diez puntos; el marcador
vuelve a cero por encima de 9999. Colisión o enemigo que llega abajo resta una
vida. Se empieza con tres vidas. Soltar y pulsar A2 o D7 reinicia tras Game Over.

## Comprobaciones obligatorias pendientes
- Compilar y enlazar sin errores con build.ps1.
- Confirmar SPACE BATTLE al arrancar.
- Probar inicio, X/Y, límites, disparos, colisiones, puntos y vidas.
- Llegar a Game Over y reiniciar.
- Medir al menos 30 actualizaciones completas por segundo con analizador lógico.
- Confirmar que no se acumulan errores I2C; i2c_errors es un contador en SRAM.

## Temporización prevista, no medida
Cristal 12 MHz, PLLA 168 MHz y MCK 84 MHz.
TC0 recibe MCK/2 = 42 MHz. RC=1 400 000 produce interrupciones nominales de 30 Hz.
TWI1 funciona nominalmente a 400 kHz. Se transmiten 1096 bytes por cuadro,
contando direcciones y controles, equivalentes a unos 24,66 ms más condiciones
de bus y tiempo de software, dentro del presupuesto nominal de 33,33 ms.
Esto no garantiza 30 FPS físicos: debe medirse con el módulo conectado.
Si una actualización se retrasa, el bucle descarta los ticks acumulados;
no hay una garantía de tiempo real ante fallos I2C o hardware defectuoso.

## Diagnóstico DIAG 1
Se conservó el fuente anterior en space_battle.antes-diagnostico.txt.
El menú incluye DIAG 1 y una línea T:000 A:0 D:0 E:0:
- T: contador de interrupciones TC0, módulo 1000. Debe cambiar continuamente.
- A: entrada A2 sin antirrebote; 1 significa pulsada.
- D: entrada D7 sin antirrebote; 1 significa pulsada.
- E: 1 indica que se ha registrado algún NACK/timeout I2C.
El LED L de la placa cambia cada 16 interrupciones de TC0.
Si T cambia y A/D no, investigar entradas/conexiones.
Si LED parpadea pero T permanece fijo, investigar bucle principal o pantalla.
Si DIAG 1 no aparece, no asumir que el nuevo firmware está ejecutándose.
Esta instrumentación no es todavía una corrección confirmada del fallo físico.

## Diagnóstico DIAG 3: encendido del OLED
El registro DIAG2 confirmó avance del bucle e I2C_ERRORS=0 en la prueba del usuario.
Se añade 0x8D/0x14 (bomba SSD1306) junto con 0xAD/0x8B (SH1106), se ajustan
precharge/VCOM a los valores del constructor NONAME anteriormente utilizado
y se fija modo de direccionamiento por páginas. No se enlaza U8g2.
Al arrancar se ordena A5 durante aproximadamente tres segundos, y luego A4
para mostrar el framebuffer. Observar si toda el área se ilumina antes del menú.
La copia anterior se conserva como space_battle.diag2.txt.
Esta modificación es una hipótesis de compatibilidad, no una solución probada.

## Ajuste de dificultad
Nave: 1 pixel por cuadro (30 px/s nominales). Enemigos: 1 pixel cada 6 cuadros (5 px/s nominales). Se mantiene TC0 a 30 Hz. Pendiente de prueba del usuario.


## Mejoras recogibles
La nave vuelve a 2 px/cuadro; recoger S aumenta a 3 px/cuadro.
Se generan cápsulas alternando S, D y R. La primera aparece a los tres segundos
de juego; las siguientes, tres segundos después de recoger o perder la anterior.
Acercarse y tocar la cápsula con la nave para recogerla.
- S: mayor velocidad de movimiento.
- D: dos proyectiles por disparo.
- R: reduce el intervalo de disparo de 10 cuadros a 3 cuadros.
Cada mejora dura 450 cuadros (15 segundos nominales). Pueden coexistir.
Mantener D7 para disparar. Pool de 16 proyectiles simultáneos; no se espera
que salga de pantalla un proyectil para disparar otro. Los enemigos conservan
la velocidad fácil de 5 px/s. El HUD muestra S/D/R mientras estén activos.
Al reiniciar se eliminan todas las mejoras y proyectiles.
Pendiente ensamblar/cargar desde PowerShell y validar en el Due.

## Rafaga especial con barra de recarga
Durante la partida, pulsar A2 (botón del joystick) dispara cuatro proyectiles
simultáneos separados ocho píxeles horizontalmente. Cerca de los bordes se
desplaza el grupo completo para mantener los cuatro disparos dentro de pantalla.
La barra del HUD, entre S/D/R y V, muestra la carga. Al iniciar está llena.
Después de usarla tarda 150 cuadros (cinco segundos nominales a 30 Hz) en recargar.
Se necesita una nueva pulsación: mantener A2 no repite automáticamente la ráfaga.
D7 conserva el disparo normal y sus mejoras. La ráfaga siempre tiene cuatro tiros.
Si no hay cuatro huecos libres en el pool, conserva la carga; soltar y volver a
pulsar cuando haya espacio. La recarga avanza solo durante la partida.
Pendiente de compilación desde PowerShell y comprobación en la placa.

## Joystick girado físicamente 90 grados a la izquierda
Se intercambian los ejes y se invierte uno: X=4095-ADC(A1), Y=ADC(A0). Las conexiones siguen siendo VRx=A0 y VRy=A1; SW=A2. Comprobar orientación en la placa porque las polaridades originales dependen del módulo.


## Ajustes: enemigos, rafaga perforante y explosiones
- Enemigos: 1 pixel cada 8 cuadros, nominalmente 3,75 px/s (25 % mas lentos).
- Rafaga A2: cuatro proyectiles perforantes; siguen viajando tras destruir enemigos.
  Los disparos normales siguen desapareciendo al impactar. Los especiales se dibujan
  como trazos mas largos. Se conserva recarga de cinco segundos.
- Cada enemigo destruido genera una explosion de tres etapas durante 12 cuadros.
- Mejoras: X entre 16 y 104, dejando margen a ambos lados para el sprite de 8 pixeles.
  Caen un pixel cada dos cuadros: 15 px/s, cuatro veces mas rapido que los enemigos.
Pendiente de ensamblar desde PowerShell y validar comportamiento en el Due.

## Duracion actual de las mejoras
S, D y R duran individualmente 150 cuadros (cinco segundos a 30 Hz). Se combinan y expiran de forma independiente. Recoger otra capsula del mismo tipo renueva sus cinco segundos. Se mantiene la velocidad actual de enemigos y capsulas, asi como la rafaga perforante y las explosiones. Esta seccion sustituye las duraciones de quince segundos indicadas arriba.


## Ajuste del borde de pantalla
La nave ya esta limitada a X=0..120 para su ancho de ocho pixeles y el dibujado recorta fuera de 128x64. Se cambia OLED_COLUMN_OFFSET de 2 a 0 para comprobar si el fragmento que aparece al otro lado se debe al retorno de columna de un controlador de 128 columnas. Esta es una hipotesis pendiente de comprobar en el modulo actual. Si se recortan dos columnas a la izquierda, revisar si el modulo requiere offset 2 como SH1106 de 132 columnas. Se conserva el fuente anterior en space_battle.antes-borde.txt.


## Punteo final
Game Over muestra PUNTOS: seguido del marcador de cuatro digitos. El marcador se convierte directamente del estado final, y permanece visible hasta reiniciar.


## Mejor puntaje TOP
El menu y Game Over muestran TOP con el mejor puntaje de la sesion. Se actualiza cuando el marcador supera el record. Reiniciar una partida con A2/D7 lo conserva. Apagar o reiniciar la placa lo borra: se almacena solo en SRAM, no se escribe la Flash. Pendiente comprobar esta version en la placa.

