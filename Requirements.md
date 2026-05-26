# TP Final — Digital 2
## Sistema de Seguridad para Sierra de Banco
**PIC16F887 — Assembly**

---

## 1. Descripción general

Sistema embebido que detecta la proximidad de una mano a la hoja de sierra mediante un sensor ultrasónico. Si la distancia cae por debajo de un umbral configurable, corta la alimentación del motor. El umbral se ajusta con un potenciómetro (ADC). Un botón de parada de emergencia actúa por interrupción de alta prioridad. El estado del sistema se reporta por UART al PC, y el PC puede enviar comandos de control.

---

## 2. Requisitos de usuario

| ID | Requisito |
|----|-----------|
| RU-01 | El sistema debe detener el motor automáticamente cuando se detecte una mano a menos de X cm. |
| RU-02 | El usuario puede ajustar el umbral de distancia con un potenciómetro. |
| RU-03 | Debe haber un botón de parada de emergencia que detenga el motor de forma inmediata. |
| RU-04 | El estado actual (distancia, motor ON/OFF) debe visualizarse desde la PC. |
| RU-05 | Desde la PC se debe poder reanudar el motor luego de un paro de emergencia. |
| RU-06 | Dos LEDs deben indicar visualmente si el sistema está en modo seguro o en operación. |

---

## 3. Requisitos del sistema

### 3.1 Funcionales

| ID | Requisito |
|----|-----------|
| RS-F01 | El PIC mide la distancia con HC-SR04 vía pulso TRIG/ECHO. |
| RS-F02 | Timer1 mide el ancho del pulso ECHO por overflow/captura. |
| RS-F03 | Timer0 genera ciclos periódicos (~100 ms) para disparar una nueva medición. |
| RS-F04 | El módulo ADC lee el canal AN0 (potenciómetro) para obtener el umbral de distancia. |
| RS-F05 | Si `distancia_medida < umbral_ADC`, el pin de control del relay se pone en bajo (motor OFF). |
| RS-F06 | INT0 (RB0) atiende el botón de emergencia con máxima prioridad. |
| RS-F07 | La USART envía por TX el estado del sistema (distancia, umbral, estado motor) en ASCII. |
| RS-F08 | La USART recibe por RX comandos desde PC: `'R'` = reanudar, `'P'` = parar. |
| RS-F09 | El LED verde (RD0) indica motor activo; el LED rojo (RD1) indica motor detenido/emergencia. |
| RS-F10 | El sistema arranca con el motor apagado (estado seguro por defecto). |

### 3.2 No funcionales

| ID | Requisito |
|----|-----------|
| RS-NF01 | El tiempo de respuesta desde detección hasta corte del motor debe ser ≤ 50 ms. |
| RS-NF02 | El código debe estar en Assembly para PIC16F887. |
| RS-NF03 | La comunicación UART debe ser a 9600 bps, 8N1. |
| RS-NF04 | El sistema debe operar con 5 V de alimentación. |
| RS-NF05 | El relay debe ser el único actuador que interactúa con la línea de alimentación del motor (aislación). |
| RS-NF06 | Toda la lógica de seguridad (corte) debe ejecutarse dentro de ISRs, no en el bucle principal. |

---

## 4. Historias de usuario

---

### HU-01 — Detección de proximidad
**Como** sistema de seguridad,  
**quiero** medir la distancia con el HC-SR04 cada 100 ms,  
**para** detectar si una mano se acerca a la hoja.

**Criterios de aceptación:**
- Timer0 genera una interrupción cada ~100 ms.
- En cada interrupción se envía un pulso TRIG de 10 µs al sensor.
- Timer1 mide el ancho del pulso ECHO en µs.
- La distancia en cm se calcula como `ECHO_us / 58`.

---

### HU-02 — Corte automático del motor
**Como** operario,  
**quiero** que el motor se detenga solo cuando mi mano esté cerca,  
**para** no depender de reaccionar a tiempo.

**Criterios de aceptación:**
- Si `distancia < umbral`, el pin RC2 (relay) se pone en bajo.
- El corte ocurre dentro de la ISR o inmediatamente al salir de ella.
- El LED rojo enciende y el verde apaga.

---

### HU-03 — Umbral ajustable por ADC
**Como** operario,  
**quiero** configurar a qué distancia se activa el corte,  
**para** adaptarlo al tipo de trabajo.

**Criterios de aceptación:**
- AN0 se lee cada ciclo junto con la medición del HC-SR04.
- El valor del ADC (0–255) se mapea a un rango de distancia (ej: 5–25 cm).
- El umbral activo se usa en la comparación con la distancia medida.

---

### HU-04 — Botón de emergencia
**Como** operario,  
**quiero** poder detener el motor de forma inmediata con un botón físico,  
**para** reaccionar ante cualquier situación inesperada.

**Criterios de aceptación:**
- INT0 (RB0) está configurada como interrupción por flanco descendente.
- La ISR de INT0 apaga el relay, activa el LED rojo y marca una bandera `EMERGENCY`.
- Mientras `EMERGENCY` esté activa, el motor no puede reiniciarse desde el hardware local.

---

### HU-05 — Monitoreo desde PC
**Como** desarrollador/supervisor,  
**quiero** ver el estado del sistema en la PC en tiempo real,  
**para** verificar su funcionamiento.

**Criterios de aceptación:**
- Cada ciclo (~100 ms) el PIC envía por UART una línea como: `D:12cm U:08cm M:ON\r\n`
- El envío usa la USART en modo polling o por interrupción TX.
- Los datos son legibles en cualquier terminal serie (9600 8N1).

---

### HU-06 — Control desde PC
**Como** desarrollador,  
**quiero** poder reanudar o parar el motor desde la PC,  
**para** probar el sistema sin intervención física.

**Criterios de aceptación:**
- El PIC recibe caracteres por RX: `'R'` reanuda el motor (si no hay obstrucción), `'P'` lo detiene.
- La recepción UART limpia la bandera `EMERGENCY` solo si el comando es `'R'` y no hay proximidad activa.
- Cualquier otro carácter es ignorado.

---

### HU-07 — Indicación visual de estado
**Como** operario,  
**quiero** saber de un vistazo si el sistema está en modo operación o detenido,  
**para** no necesitar mirar la PC.

**Criterios de aceptación:**
- LED verde (RD0): motor activo y sin alarma.
- LED rojo (RD1): motor detenido por proximidad o emergencia.
- Los LEDs son mutuamente excluyentes (nunca ambos activos).

---

## Anexo A — Diagrama de flujo del programa principal

```
INICIO
  └─► Configurar oscilador, puertos, UART, ADC, Timer0, Timer1, INT0
  └─► Motor OFF, LED rojo ON
  └─► Habilitar interrupciones globales
  └─► LOOP PRINCIPAL
        └─► ¿Bandera TX lista? → Enviar trama UART
        └─► GOTO LOOP
```

---

## Anexo B — Diagrama de flujo de las ISRs

```
ISR DESPACHADOR
  ├─► ¿INT0 flag? → ISR_EMERGENCIA
  ├─► ¿TMR0 flag? → ISR_CICLO
  └─► ¿TMR1 flag? → ISR_ECHO

ISR_EMERGENCIA
  └─► Relay OFF → LED rojo ON → Set EMERGENCY → Retornar

ISR_CICLO (cada ~100 ms)
  └─► Relanzar Timer0
  └─► Leer ADC (AN0) → calcular umbral
  └─► Enviar pulso TRIG 10 µs al HC-SR04
  └─► Arrancar Timer1
  └─► Set bandera TX → Retornar

ISR_ECHO (overflow/captura Timer1)
  └─► Capturar tiempo ECHO
  └─► Calcular distancia = ECHO_us / 58
  └─► ¿distancia < umbral? → Relay OFF, LED rojo
                            → Relay ON, LED verde
  └─► Retornar
```

---

## Anexo C — Asignación de pines

| Pin PIC | Función | Componente |
|---------|---------|------------|
| RB0/INT0 | Interrupción externa | Botón de emergencia |
| RC0 | TRIG output | HC-SR04 |
| RC1 | ECHO input | HC-SR04 |
| RC2 | Relay control | Relay → Motor |
| RC6/TX | UART TX | PC (RX) |
| RC7/RX | UART RX | PC (TX) |
| RA0/AN0 | ADC input | Potenciómetro |
| RD0 | LED verde | Estado OK |
| RD1 | LED rojo | Estado alarma |

---

## Anexo D — Conexión hardware (esquema simplificado)

```
                          PIC16F887
                    ┌─────────────────┐
   POT ────────────►│RA0/AN0          │
                    │                 │
   TRIG ◄───────────│RC0           RD0│──── LED Verde
   ECHO ────────────►│RC1           RD1│──── LED Rojo
                    │                 │
   BTN_EMG ─────────►│RB0/INT0      RC2│──── Relay ──► Motor
                    │                 │
   PC_RX ◄───────────│RC6/TX          │
   PC_TX ────────────►│RC7/RX          │
                    └─────────────────┘

HC-SR04:  VCC=5V, GND, TRIG=RC0, ECHO=RC1
Relay:    IN=RC2, VCC=5V, GND (carga separada)
UART:     Adaptador USB-TTL a 9600 8N1
```

---

## Anexo E — Configuración de registros clave

| Registro | Valor | Descripción |
|----------|-------|-------------|
| OSCCON |  | No usamos osc interno |
| ADCON0 | `0x01` | Canal AN0, ADC ON |
| ADCON1 | `0x80` | Justificado a derecha, Vref=VDD |
| OPTION_REG | `0x07` | Timer0, prescaler 1:256 |
| T1CON | `0x01` | Timer1 ON, prescaler 1:1 |
| TXSTA | `0x24` | UART TX habilitado, async, alta vel. |
| RCSTA | `0x90` | UART RX habilitado, serial port ON |
| SPBRG | `0x19` | 9600 bps a 4 MHz con BRGH=1 |
| INTCON | `0xA0` | GIE=1, PEIE=0, TMR0IE=1 |
| INTCON2 | `0x40` | INT0 por flanco descendente |
