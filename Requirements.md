# TP Final — Digital 2
## Sistema de Seguridad para Sierra de Banco
**PIC16F887 — Assembly | Cristal externo 4 MHz**

---

## 1. Descripción general

Sistema embebido que detecta la proximidad de una mano a la hoja de sierra mediante un sensor ultrasónico. Si la distancia cae por debajo de un umbral configurable, detiene el motor DC seteando el PWM a 0% vía CCP1. El umbral se ajusta con un potenciómetro (ADC) y se muestra en dos displays de 7 segmentos. Un botón de emergencia actúa por INT0. El estado se reporta por UART a la PC, que también puede enviar comandos de control.



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
| RU-07 | Dos displays de 7 segmentos deben mostrar el umbral de corte actual en centímetros. |

---

## 3. Requisitos del sistema

### 3.1 Funcionales

| ID | Requisito |
|----|-----------|
| RS-F01 | El PIC mide la distancia con HC-SR04 vía pulso TRIG/ECHO. |
| RS-F02 | Timer1 mide el ancho del pulso ECHO por polling. |
| RS-F03 | Timer0 genera ciclos periódicos de ~10 ms para el multiplexado; cada 10 ciclos dispara una medición. |
| RS-F04 | El módulo ADC lee el canal AN0 (potenciómetro) para obtener el umbral de distancia. |
| RS-F05 | Si `distancia_medida < umbral`, el módulo CCP1 setea duty cycle = 0% (motor OFF). |
| RS-F06 | INT0 (RB0) atiende el botón de emergencia con máxima prioridad. |
| RS-F07 | La USART envía por TX el estado del sistema (distancia, umbral, estado motor) en ASCII. |
| RS-F08 | La USART recibe por RX comandos desde PC: `'R'` = reanudar, `'P'` = parar. |
| RS-F09 | El LED verde (RA1) indica motor activo; el LED rojo (RA2) indica motor detenido/emergencia. |
| RS-F10 | El sistema arranca con el motor apagado (estado seguro por defecto). |
| RS-F11 | El umbral de corte se muestra en dos displays de 7 segmentos multiplexados (decenas/unidades). |
| RS-F12 | Los displays se refrescan desde la ISR del Timer0 mediante multiplexado por software. |

### 3.2 No funcionales

| ID | Requisito |
|----|-----------|
| RS-NF01 | El tiempo de respuesta desde detección hasta corte del motor debe ser ≤ 50 ms. |
| RS-NF02 | El código debe estar en Assembly para PIC16F887. |
| RS-NF03 | La comunicación UART debe ser a 9600 bps, 8N1. |
| RS-NF04 | El sistema debe operar con 5 V de alimentación. |
| RS-NF05 | El control del motor se realiza por PWM vía CCP1 (RC2) y transistor NPN. |
| RS-NF06 | Toda la lógica de seguridad (corte) debe ejecutarse dentro de ISRs, no en el bucle principal. |
| RS-NF07 | La frecuencia de refresco de los displays debe ser ≥ 50 Hz total (≥ 25 Hz por dígito). |

---

## 4. Historias de usuario

---

### HU-01 — Detección de proximidad (COMPLETADA)
**Como** sistema de seguridad,  
**quiero** medir la distancia con el HC-SR04 cada 100 ms,  
**para** detectar si una mano se acerca a la hoja.

**Criterios de aceptación:**
- Timer0 genera una interrupción cada ~10 ms; la medición ocurre cada 10 interrupciones.
- En cada ciclo de 100 ms se envía un pulso TRIG de 10 µs al sensor.
- Timer1 mide el ancho del pulso ECHO en µs por polling.
- La distancia en cm se calcula como `ECHO_us / 58`.

---

### HU-02 — Corte automático del motor
**Como** operario,  
**quiero** que el motor se detenga solo cuando mi mano esté cerca,  
**para** no depender de reaccionar a tiempo.

**Criterios de aceptación:**
- Si `distancia < umbral`, `CCPR1L = 0x00` (PWM duty = 0%, motor OFF).
- El corte ocurre dentro de la ISR o inmediatamente al salir de ella.
- El LED rojo enciende y el verde apaga.

---

### HU-03 — Umbral ajustable por ADC (TESTING)
**Como** operario,  
**quiero** configurar a qué distancia se activa el corte,  
**para** adaptarlo al tipo de trabajo.

**Criterios de aceptación:**
- AN0 se lee cada ciclo de 100 ms.
- El valor del ADC (0–255) se mapea al rango 5–25 cm.
- El umbral activo se usa en la comparación con la distancia medida.
- El umbral actualizado se refleja en los displays en el mismo ciclo.

---

### HU-04 — Botón de emergencia
**Como** operario,  
**quiero** poder detener el motor de forma inmediata con un botón físico,  
**para** reaccionar ante cualquier situación inesperada.

**Criterios de aceptación:**
- INT0 (RB0) configurada por flanco descendente.
- La ISR de INT0 setea `CCPR1L = 0x00`, activa LED rojo y marca `FLAG_EMERGENCY`.
- Mientras `FLAG_EMERGENCY` esté activa, el motor no puede reiniciarse localmente.

---

### HU-05 — Monitoreo desde PC
**Como** desarrollador/supervisor,  
**quiero** ver el estado del sistema en la PC en tiempo real,  
**para** verificar su funcionamiento.

**Criterios de aceptación:**
- Cada 100 ms el PIC envía: `D:12cm U:08cm M:ON\r\n`
- Legible en cualquier terminal serie (9600 8N1).

---

### HU-06 — Control desde PC
**Como** desarrollador,  
**quiero** poder reanudar o parar el motor desde la PC,  
**para** probar el sistema sin intervención física.

**Criterios de aceptación:**
- `'R'` reanuda el motor si no hay obstrucción activa ni emergencia.
- `'P'` para el motor y activa `FLAG_EMERGENCY`.
- Cualquier otro carácter es ignorado.

---

### HU-07 — Indicación visual de estado
**Como** operario,  
**quiero** saber de un vistazo si el sistema está operando o detenido,  
**para** no necesitar mirar la PC.

**Criterios de aceptación:**
- LED verde (RA1): motor activo.
- LED rojo (RA2): motor detenido por proximidad o emergencia.
- Mutuamente excluyentes.

---

### HU-08 — Display del umbral de corte
**Como** operario,  
**quiero** ver en los displays el umbral de distancia configurado,  
**para** saber a qué distancia se activará el corte sin mirar la PC.

**Criterios de aceptación:**
- Displays muestran umbral en cm (00–25), decenas a la izquierda.
- Se actualiza cada ciclo de 100 ms.
- Sin parpadeo visible (refresco ≥ 25 Hz por dígito).

---

### HU-09 — Rutina de multiplexado de displays
**Como** desarrollador,  
**quiero** una rutina de refresco llamada desde la ISR del Timer0,  
**para** mantener los displays activos sin bloquear el programa principal.

**Criterios de aceptación:**
- Cada llamada alterna el dígito activo con flag `DISP_SEL`.
- Apaga ambos selectores antes de cambiar el bus (anti-ghosting).
- Usa tabla lookup `BCD_7SEG` en program memory.
- El umbral se convierte a BCD antes de llamar a la rutina.

---

### HU-10 — Control PWM del motor
**Como** desarrollador,  
**quiero** controlar el motor por PWM vía CCP1,  
**para** usar el hardware del PIC y dejar infraestructura para control de velocidad futuro.

**Criterios de aceptación:**
- CCP1 configurado en modo PWM con Timer2.
- Motor ON: `CCPR1L = 0xFF` (100% duty).
- Motor OFF: `CCPR1L = 0x00` (0% duty).
- RC2 configurado como salida antes de habilitar CCP1.

---

## Anexo A — Diagrama de flujo del programa principal

```
INICIO
  └─► Configurar puertos, ADC, UART, PWM/CCP1, Timer0, Timer1, INT0
  └─► CCPR1L = 0x00 (motor OFF), LED rojo ON, displays en "00"
  └─► Habilitar interrupciones globales
  └─► LOOP PRINCIPAL
        └─► ¿FLAG_TX? → Enviar trama UART
        └─► GOTO LOOP
```

---

## Anexo B — Diagrama de flujo de las ISRs

```
ISR DESPACHADOR
  ├─► ¿INT0 flag? → ISR_EMERGENCIA
  └─► ¿TMR0 flag? → ISR_CICLO

ISR_EMERGENCIA
  └─► CCPR1L=0 → LED rojo ON → Set FLAG_EMERGENCY → Retornar

ISR_CICLO (cada ~10 ms)
  └─► Relanzar Timer0
  └─► RUTINA_DISPLAY (alternar dígito)
  └─► Incrementar CICLO_CNT
  └─► ¿CICLO_CNT == 10?
        └─► Reset CICLO_CNT
        └─► Leer ADC → calcular umbral → BCD
        └─► TRIG 10 µs → polling ECHO → calcular distancia
        └─► ¿distancia < umbral?
              ├── SÍ → CCPR1L=0x00, LED rojo ON, LED verde OFF
              └── NO → CCPR1L=0xFF, LED verde ON, LED rojo OFF
        └─► Set FLAG_TX
  └─► Retornar

RUTINA_DISPLAY
  └─► Apagar RE0 y RE1
  └─► ¿DISP_SEL==0? → cargar decenas → PORTD → RE0 ON → DISP_SEL=1
                    → cargar unidades → PORTD → RE1 ON → DISP_SEL=0
  └─► Retornar
```

---

## Anexo C — Asignación de pines

| Pin PIC | Función | Componente |
|---------|---------|------------|
| RA0/AN0 | ADC input | Potenciómetro |
| RA1 | LED verde | Estado OK |
| RA2 | LED rojo | Estado alarma |
| RB0/INT0 | INT externa | Botón emergencia |
| RC0 | TRIG output | HC-SR04 |
| RC1 | ECHO input | HC-SR04 |
| RC2/CCP1 | PWM output | Base TIP31C → Motor DC |
| RC6/TX | UART TX | PC (RX) |
| RC7/RX | UART RX | PC (TX) |
| RD0–RD6 | Segmentos a–g | Ambos displays (bus compartido) |
| RE0 | Selector decenas | BC547 → cátodo display |
| RE1 | Selector unidades | BC547 → cátodo display |

---

## Anexo D — Conexión hardware (esquema simplificado)

```
                             PIC16F887
                    ┌──────────────────────┐
    POT ────────────►│RA0/AN0               │
                     │                      │
    TRIG ◄───────────│RC0               RA1 │──── LED Verde
    ECHO ────────────►│RC1               RA2 │──── LED Rojo
                     │                      │
    BTN_EMG ─────────►│RB0/INT0    RC2/CCP1 │──[1kΩ]── Base TIP31C
                     │                      │          Colector → Motor DC
    PC_RX ◄───────────│RC6/TX       RD0–RD6 │──┐       Emisor → GND
    PC_TX ────────────►│RC7/RX            RE0│──┤── BC547 sel decenas
                     │                  RE1 │──┘── BC547 sel unidades
                    └──────────────────────┘

Motor DC:   5V entre VCC y colector TIP31C. Diodo 1N4007 en paralelo (flyback).
Displays:   Cátodo común. 330Ω en serie con cada segmento.
HC-SR04:    VCC=5V, GND, TRIG=RC0, ECHO=RC1.
UART:       Adaptador USB-TTL, 9600 8N1.
```

---

## Anexo E — Tabla BCD a 7 segmentos

Orden `gfedcba`, cátodo común, activo en alto.

| Dígito | Hex  |
|--------|------|
| 0 | 0x3F |
| 1 | 0x06 |
| 2 | 0x5B |
| 3 | 0x4F |
| 4 | 0x66 |
| 5 | 0x6D |
| 6 | 0x7D |
| 7 | 0x07 |
| 8 | 0x7F |
| 9 | 0x6F |

```asm
BCD_7SEG:
    ADDWF   PCL, F
    RETLW   0x3F    ; 0
    RETLW   0x06    ; 1
    RETLW   0x5B    ; 2
    RETLW   0x4F    ; 3
    RETLW   0x66    ; 4
    RETLW   0x6D    ; 5
    RETLW   0x7D    ; 6
    RETLW   0x07    ; 7
    RETLW   0x7F    ; 8
    RETLW   0x6F    ; 9
```

---

## Anexo F — Configuración de registros clave

| Registro | Valor | Descripción |
|----------|-------|-------------|
| ADCON0 | `0x01` | Canal AN0, ADC ON |
| ADCON1 | `0x80` | Justificado a derecha, Vref=VDD |
| OPTION_REG | `0x05` | Timer0, prescaler 1:64 (~10 ms) |
| T1CON | `0x01` | Timer1 ON, prescaler 1:1 (1 tick = 1 µs) |
| T2CON | `0x04` | Timer2 ON, prescaler 1:1 (base PWM) |
| PR2 | `0xFF` | Periodo PWM (~3.9 kHz a 4 MHz) |
| CCP1CON | `0x0C` | Modo PWM |
| CCPR1L | `0x00`/`0xFF` | Duty 0% / 100% |
| TXSTA | `0x24` | UART TX, async, BRGH=1 |
| RCSTA | `0x90` | UART RX, serial port ON |
| SPBRG | `0x19` | 9600 bps a 4 MHz |
| INTCON | `0xB0` | GIE=1, TMR0IE=1, INTE=1 |
| TRISC | `0xB2` | RC0 salida (TRIG), RC1 entrada (ECHO), RC2 salida (CCP1), RC6 salida (TX), RC7 entrada (RX) |
| TRISD | `0x00` | RD0–RD6 salidas (segmentos a–g) |
| TRISE | `0x00` | RE0, RE1 salidas (selectores display) |
