# MOD — Muevete o duermete
Firmware ARM Thumb-2 para Due. Misma pantalla, conexiones y orientación del joystick.
Intro de seis segundos saltable con A2 o D7. Observa la secuencia y repítela en
el mismo ritmo. Arriba, abajo, izquierda, derecha y PUSH (A2 o D7).
Volver al centro entre movimientos repetidos. Cinco vidas. Fallar o no responder
en un pulso resta una vida y repite la demostración. Cada ronda añade un elemento
hasta doce y acelera el pulso de 32 a 12 cuadros. Game Over animado y reinicio
con PUSH después de tres segundos. Ritmo visual; sin buzzer conectado.
Se conserva el firmware anterior en SpaceBattle-original.respaldo.
Compilar y cargar desde esta carpeta:
 powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\upload.ps1 -Port COM8
No se ha verificado aún este firmware en hardware. Los controladores reutilizados
funcionaban con Space Battle; la nueva lógica requiere compilar y probar.

Cambio: las figuras se contraen como flechas. El quinto simbolo es QUIETO: mantener el joystick centrado y no pulsar durante ese pulso. A2/D7 siguen saltando intro y reiniciando tras perder.


Animacion de error: 18 cuadros de sacudida, onda expansiva y particulas. Final: OH tembloroso, dispersion, cara dormida y ZZZ; reinicio habilitado tras cuatro segundos. Efectos sin destellos de pantalla completa. Pendiente comprobar en hardware.


Senales: cuatro direcciones, QUIETO (cuadrado, no tocar), PULSA (circulo, A2 o D7). Texto y figura usan ahora la misma senal. Intro con flechas en movimiento y final con persona en cama, manta que respira y ZZZ. Pendiente validar en hardware.


Nueva presentacion: maquina encendiendose y acercamiento, titulo con dos figuras bailando, PUSH inicia tutorial con las seis opciones simultaneas; otro PUSH lo salta. PERFECTO al completar cada pulso. Error congela demostracion mientras dura el impacto. Puntos: 10 por acierto. Record de sesion RAM. Final: nuevo record con figuras saltando; CASIII desde 80% del record si obtuvo al menos30 puntos; QUE HUMILLACION por debajo de30; resto cama con ZZZ. Pendiente verificar compilacion y hardware.


Respuesta: plazo por ticks TC0, una accion nueva y correcta por pulso. Al expirar sin accion se pierde vida y aparece MUY LENTO. La fase OBSERVA no penaliza inactividad; RESPONDE AHORA si. QUIETO sigue siendo la unica senal sin movimiento.


Regla actual: tres fallos acumulados quitan una vida; cinco vidas, derrota en el fallo15. Los aciertos no borran fallos acumulados. FALLO aparece brevemente sobre la escena de respuesta y avanza al siguiente pulso, sin repetir demostracion. Cama con almohada, pelo, brazo y manta con costuras. Pendiente verificar en hardware.


HUD de partida limpio: puntos arriba izquierda, V:vidas arriba derecha, figura al centro y mensajes abajo. Se eliminan nombres de direcciones y record del HUD de partida; record permanece en el final. Pendiente comprobar en placa.


## Revision de entradas y fallos
El adjudicador mod_judge usa un solo plazo TC0. Se comprueban direccion nueva,
PULSA por flanco, respuesta almacenada del pulso actual y vencimiento sin respuesta.
QUIETO exige centro y ambos botones liberados; mantener un boton ya no se ignora.
Los puntos se asignan al cerrar correctamente el pulso. Tres fallos restan una vida.
Se ejecutaron 70 escenarios sobre las instrucciones del adjudicador mediante un
interprete limitado: seis senales, inactividad, respuesta incorrecta, direccion
sostenida sin evento y respuesta al cierre. Todos pasaron. Esto no ensambla el
firmware ni simula el ADC, los rebotes fisicos o el OLED; falta validacion en placa.
