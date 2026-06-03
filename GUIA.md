# Guía de implementación — Proyecto Sierra Segura

> Pasos, registros y lógica para cada HU. **Las HUs 01/02/03 se conservan abajo marcadas como OBSOLETAS** porque su código terminó integrado en `tpFinal.asm`. Las HUs 04/05/06 se entregan como esqueletos standalone que luego se fusionan en `tpFinal.asm` siguiendo las notas de integración de cada archivo.

> **Reglas de estilo** (aplican a todas las HUs nuevas y al integrado):
> - UPPERCASE para labels, registros y constantes.
> - `BANKSEL` antes de cualquier acceso cross-bank.
> - Comentarios en español, una línea por bloque lógico.
> - Guardar W y STATUS al entrar a ISR (`MOVWF W_TEMP` / `SWAPF STATUS,W` / `MOVWF STATUS_TEMP`) y restaurar antes de `RETFIE`.
> - Subrutinas terminan en `RETURN`, ISRs en `RETFIE`.
> - Flag `__CONFIG` y `CBLOCK` viven una sola vez (en `tpFinal.asm`). Al integrar, borrar los de la HU.

---

## Índice

- [HU-04 — Botón de emergencia (INT0)](#hu-04--botón-de-emergencia-int0) — **NUEVO**
- [HU-05 — Monitoreo desde PC (UART TX)](#hu-05--monitoreo-desde-pc-uart-tx) — **NUEVO**
- [HU-06 — Control desde PC (UART RX)](#hu-06--control-desde-pc-uart-rx) — **NUEVO**
- [HU-03 — ADC + Display](#hu-03--adc--display) — *OBSOLETA (integrada en `tpFinal.asm`)*
- [HU-01 — Medición HC-SR04](#hu-01--medición-hc-sr04) — *OBSOLETA (integrada en `tpFinal.asm`)*
- [HU-02 — Corte automático](#hu-02--corte-automático) — *OBSOLETA (integrada en `tpFinal.asm`)*

---

## HU-04 — Botón de emergencia (INT0)

**Archivo:** `HU04-EMERGENCIA.asm` (esqueleto standalone).

**Propósito:** atender el pulsador físico de emergencia con la latencia más corta posible, cortar el motor, encender el LED rojo y marcar `FLAG_EMERGENCY`. La liberación es responsabilidad de HU-06 (vía `'R'` desde la PC).

### Paso 1 — Configurar el pin

- `TRISB, 0 = 1` → RB0 como entrada.
- `OPTION_REG, INTEDG = 0` → flanco descendente (el pulsador normalmente está en alto y va a bajo al presionar).
  - **Ojo:** el resto de `OPTION_REG` lo maneja HU-03 (prescaler de Timer0). Usar `BCF OPTION_REG, INTEDG` para no pisar el valor.

### Paso 2 — Habilitar INT0

- `INTCON = 0xD0` (GIE + PEIE + T0IE + INTE). **Importante:** el valor viejo era `0xB0`; el cambio agrega `PEIE=1` (bit 6), obligatorio para que las interrupciones de periféricos lleguen. Ver `CONTRATO.md`.

### Paso 3 — Dispatcher de ISR con prioridad

Orden de chequeo en el vector 0x04 (mientras `IPEN=0`, la prioridad es solo lógica, definida por el orden de los `BTFSS`):

1. `INT0IF` (emergencia) — atender primero
2. `RCIF` (UART RX) — atender segundo (HU-06)
3. `T0IF` (Timer0) — flujo normal al final

Pseudocódigo del dispatcher:

```
ISR_DISPATCHER:
    guardar W y STATUS
    recargar TMR0 con .100
    BCF INTCON, T0IF

    BTFSS INTCON, INT0IF
    GOTO  CHECK_RCIF
    CALL ISR_EMERGENCIA
    GOTO  RECUPERAR_CONTEXTO

CHECK_RCIF:
    BTFSS PIR1, RCIF
    GOTO  T0_NORMAL
    CALL ISR_UART_RX          ; viene de HU-06
    GOTO  RECUPERAR_CONTEXTO

T0_NORMAL:
    ; flujo de RUTINA_DISPLAY + ciclo 100ms (HU-01/02/03)
    GOTO  RECUPERAR_CONTEXTO
```

### Paso 4 — `ISR_EMERGENCIA`

Pasos obligatorios:

1. `BCF INTCON, INT0IF` — limpiar flag (por si quedó pendiente).
2. `CLRF CCPR1L` (con `BANKSEL` previo) → PWM 0%, motor OFF.
3. `BCF PORTD, 0` / `BSF PORTD, 1` → LED verde OFF, rojo ON.
4. `BSF FLAGS, 1` → `FLAG_EMERGENCY = 1`.
5. `RETURN` (vuelve al dispatcher, que hace `RETFIE`).

> **Detalle:** no es toggle. Si la mano sigue apretando el botón, el flag queda set y el motor sigue cortado. La liberación es **únicamente** por `'R'` desde la PC (HU-06), no por hardware.

### Paso 5 — Integración en `tpFinal.asm`

1. Borrar `__CONFIG` y `CBLOCK` de `HU04-EMERGENCIA.asm`.
2. En `MAIN` de `tpFinal.asm`, agregar (en el bloque de Bank 1):
   - `BSF TRISB, 0`
   - `BCF OPTION_REG, INTEDG`
3. Reemplazar el `INTCON = 0xB0` por `INTCON = 0xD0`.
4. En el dispatcher (línea ~94 de `tpFinal.asm`, donde dice "Atender rutina de emergencia"), insertar el bloque de chequeo de INT0IF.
5. Pegar `ISR_EMERGENCIA` al final del archivo, antes del `END`.

### Prueba en simulador

1. Cargar `HU04-EMERGENCIA.asm` standalone en MPLABX.
2. Agregar un *pin stimulus* en RB0 con un pulso descendente de 100 µs.
3. Poner breakpoint en la primera instrucción de `ISR_EMERGENCIA`.
4. Verificar al detenerse:
   - `INTCON, INT0IF = 0` (limpio)
   - `CCPR1L = 0x00`
   - `PORTD` bit 1 = 1, bit 0 = 0
   - `FLAGS` bit 1 = 1
5. Repetir el stim: el estado debe **permanecer** (es latch, no toggle).
6. Limpiar manualmente `FLAGS, 1` + restaurar LEDs + `CCPR1L = 0xFF` para "liberar" en el test (en producción lo hace HU-06).

---

## HU-05 — Monitoreo desde PC (UART TX)

**Archivo:** `HU05-UART-TX.asm` (esqueleto standalone).

**Propósito:** emitir por UART, cada 100 ms, una trama ASCII con el estado del sistema para visualizar desde la PC.

**Formato de trama (18 bytes):** `D:XXcm U:XXcm M:XX\r\n`

- `D:XXcm` → distancia medida (`DIST_CM`, 0–99)
- `U:XXcm` → umbral de corte (`UMBRAL_CM`, 5–25)
- `M:XX` → estado del motor: `ON` (verde) o `OFF` (rojo)
- `\r\n` → terminador CRLF (portable a cualquier terminal serie)

### Paso 1 — Configurar UART

```
TRISC, 6 = 0   ; TX salida
TRISC, 7 = 1   ; RX entrada (lo necesita HU-06 también)

TXSTA  = 0x24  ; TXEN, BRGH=1, async, 8 bits
SPBRG  = 0x19  ; 9600 bps @ 4 MHz con BRGH=1
RCSTA  = 0x90  ; SPEN + CREN
```

> Verificación de timing: con Fosc = 4 MHz, BRGH = 1, SPBRG = 25 (`0x19`):
> `Baud = Fosc / (16 × (SPBRG + 1)) = 4_000_000 / (16 × 26) ≈ 9615 bps`
> Error: ~0.16 %, aceptable.

### Paso 2 — Handshake con la ISR

La ISR setea `FLAGS, 0` (`FLAG_TX = 1`) **una vez cada 100 ms** (no en cada interrupción de T0, sino cuando `CICLO_CNT == 10`). El main loop lo lee y llama a `ENVIAR_TRAMA`.

```
ISR (cada 100ms, al final del flujo de T0):
    BSF FLAGS, 0      ; hay trama para enviar

LOOP:
    BTFSS FLAGS, 0
    GOTO  LOOP
    BCF   FLAGS, 0
    CALL  ENVIAR_TRAMA
    GOTO  LOOP
```

### Paso 3 — Subrutinas

- **`TX_BYTE(W)`**: espera `TXSTA, TRMT = 1` y escribe `TXREG`. Destruye W si no se guarda antes (en el caller: `MOVWF TEMP`).
- **`BIN_TO_ASCII_DECUNI(W)`**: convierte byte 0–99 a decenas en W y unidades en `TEMP`. Método: resta sucesiva de 10. Hay dos versiones en el archivo: una "simple" (que tiene un bug marcado de pisado de variable) y una "corregida" abajo. Usar la corregida.
- **`ENVIAR_TRAMA`**: emite los 18 bytes en orden. Manda `'D'`, `':'`, `dist_dec`, `dist_uni`, `'c'`, `'m'`, `' '`, `'U'`, `':'`, `umb_dec`, `umb_uni`, `'c'`, `'m'`, `' '`, `'M'`, `':'`, `'O'`/`'F'`, `'N'`/`'F'`, `'\r'`, `'\n'`.

### Paso 4 — Integración en `tpFinal.asm`

1. Borrar `__CONFIG` y `CBLOCK` de `HU05-UART-TX.asm`.
2. En `MAIN` de `tpFinal.asm`, agregar la configuración UART de la HU.
3. En el `LOOP` actual (que hoy es un `GOTO LOOP` puro), insertar el chequeo de `FLAG_TX`.
4. En la ISR, después de `CALL COMPARAR_Y_ACTUAR`, agregar `BSF FLAGS, 0`.
5. Pegar `ENVIAR_TRAMA`, `TX_BYTE` y `BIN_TO_ASCII_DECUNI` al final del archivo.

### Prueba en simulador

1. Cargar `HU05-UART-TX.asm` standalone.
2. Setear manualmente en RAM:
   - `DIST_CM = .12`
   - `UMBRAL_CM = .08`
   - `FLAGS` bit 2 = 1 (motor ON)
3. Abrir *Simulator > UART1 IO* (o el output de la UART en Proteus si se usa esa plataforma).
4. Verificar que la trama `D:12cm U:08cm M:ON\r\n` sale byte por byte.
5. Probar variantes:
   - `DIST_CM=5, UMBRAL_CM=25, FLAGS bit 2=0` → `D:05cm U:25cm M:OFF\r\n`
   - `DIST_CM=0` → `D:00cm U:08cm M:ON\r\n` (borde inferior)
6. Si la trama sale mal, revisar primero `BIN_TO_ASCII_DECUNI` (el esqueleto tiene una versión con bug marcada).

---

## HU-06 — Control desde PC (UART RX)

**Archivo:** `HU06-UART-RX.asm` (esqueleto standalone).

**Propósito:** recibir comandos ASCII desde la PC y traducirlos a acciones sobre el sistema. Comandos soportados:

| Byte | Acción |
|------|--------|
| `'R'` (`0x52`) | Limpia `FLAG_EMERGENCY`. Por decisión de diseño (los sensores actuales no permiten saber si hay obstrucción al momento de recibir el comando), `'R'` siempre limpia. El próximo ciclo de 100 ms re-evalúa `DIST_CM < UMBRAL_CM` y, si la mano sigue cerca, vuelve a cortar. |
| `'P'` (`0x50`) | Ejecuta la lógica de `ISR_EMERGENCIA`: motor OFF, LED rojo, `FLAG_EMERGENCY = 1`. |
| Otro | Ignorado. |

### Paso 1 — Configurar UART (mismos registros que HU-05)

El archivo standalone reescribe la config para poder probarse solo. En el integrado, **HU-05 ya deja todo listo** y esta HU no repite la config.

### Paso 2 — Habilitar la interrupción de RX

Dos requisitos que no son obvios:

1. `PIE1, RCIE = 1` (bit 5) — habilita localmente la IRQ de RCIF.
2. `INTCON, PEIE = 1` (bit 6) — habilita globalmente las IRQs de periféricos. Sin esto, `RCIE` prendido no hace nada.

Ambos son obligatorios. Si solo se hace uno, no funciona.

### Paso 3 — Dispatcher

Insertar el chequeo de `RCIF` entre `INT0IF` y `T0IF` (ver diagrama en HU-04 paso 3).

```
CHECK_RCIF:
    BTFSS PIR1, RCIF
    GOTO  T0_NORMAL
    CALL ISR_UART_RX
    GOTO  RECUPERAR_CONTEXTO
```

### Paso 4 — `ISR_UART_RX`

Pasos:

1. Chequear `RCSTA, OERR` (overrun). Si está en 1, hacer `BCF RCSTA, CREN` / `BSF RCSTA, CREN` para limpiar.
2. `MOVF RCREG, W` — leer el byte (esto limpia `RCIF` automáticamente).
3. Comparar con `'R'` y con `'P'`. Para comparar:
   - Guardar W en `TEMP`
   - `MOVLW 'R'`, `SUBWF TEMP, W`, `BTFSC STATUS, Z` → es `'R'`
   - Repetir para `'P'`
4. Si es `'R'`: `BCF FLAGS, 1`.
5. Si es `'P'`: `CALL ISR_EMERGENCIA`.
6. Si es otro: `RETURN` (ignorar).

### Paso 5 — Integración en `tpFinal.asm`

1. Borrar `__CONFIG` y `CBLOCK` de `HU06-UART-RX.asm`.
2. En `MAIN` de `tpFinal.asm`, agregar `BSF PIE1, RCIE` en el bloque de Bank 1 (después de la config de UART). El cambio de `INTCON` a `0xD0` ya queda hecho por HU-04.
3. En el dispatcher de la ISR, insertar el bloque `CHECK_RCIF` entre el chequeo de INT0 y el flujo de T0.
4. Pegar `ISR_UART_RX` al final del archivo. **No** pegar la `ISR_EMERGENCIA` duplicada de este archivo — en el integrado se usa la original de HU-04.

### Prueba en simulador

1. Cargar `HU06-UART-RX.asm` standalone.
2. Setear manualmente `BSF FLAGS, 1` (emergencia activa).
3. Abrir *Simulator > UART1 IO*.
4. Enviar `'R'` → verificar `FLAGS` bit 1 = 0.
5. Enviar `'P'` → verificar `FLAGS` bit 1 = 1, `PORTD` bit 1 = 1, `CCPR1L = 0x00`.
6. Enviar `'X'` o cualquier otro byte → no debe cambiar nada.
7. Probar recovery de overrun: forzar `BSF RCSTA, OERR` y enviar varios bytes seguidos sin atender la ISR; al atenderla, debe limpiarse automáticamente.

---

## HU-03 — ADC + Display

> **⚠️ OBSOLETA** — La implementación operativa vive en `tpFinal.asm`. Esta sección se conserva como referencia histórica de las decisiones de diseño (rango 5–25 cm, multiplexado por software, justificación derecha del ADC).

**Archivo histórico:** `HU03-ADC-DISPLAY.asm`

### Paso 1 — Configurar puertos

- TRISA: bit 0 como entrada (RA0/AN0, potenciómetro)
- TRISD: bits 2-7 como salidas (segmentos a-f), bits 0-1 como salidas (LEDs, opcional ahora)
- TRISE: bits 0-1 como salidas (selectores displays)
- Inicializar PORTD = 0, PORTE = 0

### Paso 2 — Configurar ADC

- `ADCON1 = 0x80`: Vref = VDD, justificado a derecha (ADRESH contiene el valor alto de 8 bits)
- `ADCON0 = 0x41`: canal AN0, ADC ON, sin iniciar conversión
- Para leer: `BSF ADCON0, GO_DONE` → esperar que se limpie → leer `ADRESH`

### Paso 3 — Configurar Timer0 para ~10ms

Cristal 4 MHz → ciclo de instrucción = 1 µs (Fosc/4).

- `OPTION_REG = 0x05`: prescaler 1:64 asignado a Timer0
- Timer0 cuenta de 0 a 255, cada tick = 64 µs
- (256 - 100) × 64 µs = 156 × 64 µs = 9.984 µs ≈ 10 ms
- Cargar TMR0 con 100 al inicio y en cada ISR

### Paso 4 — Implementar ISR Timer0

En cada interrupción (~10ms):

1. **Relanzar Timer0**: cargar TMR0 con valor base, limpiar TMR0IF
2. **RUTINA_DISPLAY**: alternar dígito (ver paso 5)
3. **Contador**: incrementar, cuando llegue a 10 (~100ms):
   - Iniciar ADC (`BSF ADCON0, GO`)
   - Esperar que termine (`BTFSC ADCON0, GO`)
   - Leer `ADRESH` → `ADC_RES`
   - Mapear 0-255 a 5-25 cm: `UMBRAL_CM = 5 + (ADC_RES * 20 / 256)`
     - Aproximación sin división: `ADC_RES / 13` → suma 5
     - O usar resta sucesiva: restar 13 hasta que dé negativo, contar iteraciones
   - Convertir a BCD: `UMBRAL_DEC = UMBRAL_CM / 10`, `UMBRAL_UNI = UMBRAL_CM % 10`
     - División por resta sucesiva para decenas, el resto son unidades

### Paso 5 — Implementar RUTINA_DISPLAY

Multiplexado por software:

1. **Anti-ghosting**: apagar RE0 y RE1 (ambos selectores OFF)
2. Si `DISP_SEL = 0` (mostrar decenas):
   - Cargar `UMBRAL_DEC`, llamar `BCD_7SEG`, escribir `PORTD`
   - Encender `RE0`, toggle `DISP_SEL` a 1
3. Si `DISP_SEL = 1` (mostrar unidades):
   - Cargar `UMBRAL_UNI`, llamar `BCD_7SEG`, escribir `PORTD`
   - Encender `RE1`, toggle `DISP_SEL` a 0

La tabla `BCD_7SEG` ya está en el esqueleto.

### Prueba en simulador

1. Cargar `HU03-ADC-DISPLAY.asm` en MPLABX como proyecto standalone
2. Poner breakpoint en ISR, verificar que salta cada ~10ms
3. Poner breakpoint en la lectura ADC, verificar que se ejecuta cada 10 interrupciones
4. Abrir ventana `SFR` → ver `ADRESH` cambiar al simular el potenciómetro
5. Verificar que `PORTD` y `PORTE` cambian alternando dígitos
6. Probar que `UMBRAL_CM` queda entre 5 y 25 al variar ADC

---

## HU-01 — Medición HC-SR04

> **⚠️ OBSOLETA** — La implementación operativa vive en `tpFinal.asm`. Esta sección se conserva como referencia histórica de la fórmula de conversión (`ticks × 9 / 512`) y los timeouts.

**Archivo histórico:** `HU01-HCSR04.asm`

### Paso 1 — Configurar puertos

- TRISC: RC0 como salida (TRIG), RC1 como entrada (ECHO)
- RC0 inicialmente LOW

### Paso 2 — Configurar Timer0 para ciclo de 100ms

Misma base que HU-03: Timer0 con prescaler 1:64.
La ISR incrementa `CICLO_CNT`. Cuando llega a 10 (100ms), dispara medición.

### Paso 3 — Configurar Timer1 para medir ECHO

- `T1CON = 0x01`: Timer1 ON, prescaler 1:1
- A 4 MHz, 1 tick = 1 µs
- Rango máximo: 65535 µs ≈ 65 ms (suficiente, HC-SR04 mide hasta ~25 ms)

### Paso 4 — Implementar `MEDIR_HCSR04`

Secuencia:

1. **Pulso TRIG (10 µs)**:
   - BSF RC0
   - Delay de 10 µs (~10 NOPs o un loop pequeño)
   - BCF RC0

2. **Esperar ECHO = 1 (con timeout corto, ~1ms)**:
   - Polling de RC1 en un loop con contador
   - Si pasa ~1ms sin que suba, abortar (sensor desconectado)
   - Setear `DIST_CM = 0xFF` (error)

3. **Medir ancho ECHO con Timer1**:
   - Cuando RC1 = 1: resetear Timer1 (`TMR1H = 0, TMR1L = 0`)
   - Timer1 ya está corriendo (T1CON configurado en init)
   - Polling de RC1 hasta que baje a 0, o hasta que `TMR1IF = 1` (timeout ~65 ms)
   - Al bajar RC1: detener Timer1 (`BCF T1CON, TMR1ON`)
   - Leer `TMR1H:TMR1L`

4. **Calcular distancia**:
   - `dist_cm = (ticks × 9) / 512` — división por shift (±1 cm error)
   - Multiplicar ticks × 9 (3 shifts + resta), luego dividir por 512 (9 shifts a la derecha)
   - O usar una tabla lookup si alcanza en memoria de programa
   - Si timeout (TMR1IF): `DIST_CM = 0xFF`

5. **Reiniciar Timer1** para la próxima: volver a encenderlo

### Prueba en simulador

1. Cargar `HU01-HCSR04.asm` standalone
2. Poner estímulo en RC1 (ECHO) — usar un pin stim en MPLABX
3. Verificar que TRIG (RC0) pulsa por 10µs cada 100ms
4. Simular ECHO con diferentes anchos de pulso:
   - 580 µs → 10 cm
   - 1160 µs → 20 cm
   - 2900 µs → 50 cm
5. Verificar que `DIST_CM` se actualiza correctamente
6. Probar timeout: no poner ECHO → `DIST_CM = 0xFF`

---

## HU-02 — Corte automático

> **⚠️ OBSOLETA** — La implementación operativa vive en `tpFinal.asm`. Esta sección se conserva como referencia histórica del contrato con `FLAG_EMERGENCY` (hoy dueña compartida con HU-04 y HU-06).

**Archivo histórico:** `HU02-CORTE.asm`

### Paso 1 — Configurar puertos

- TRISC: RC2 como salida (CCP1/PWM)
- TRISD: RD0, RD1 como salidas (LEDs)
- LEDs apagados inicialmente

### Paso 2 — Configurar PWM con CCP1

- `T2CON = 0x04`: Timer2 ON, prescaler 1:1
- `PR2 = 0xFF`: periodo máximo → ~3.9 kHz
- `CCP1CON = 0x0C`: modo PWM
- `CCPR1L = 0x00`: duty 0% (motor OFF)
- Verificar que TRISC2 = 0 antes de habilitar CCP1

### Paso 3 — Implementar `COMPARAR_Y_ACTUAR`

Lógica:

```
¿DIST_CM < UMBRAL_CM?
  SÍ → MOTOR_OFF
  NO → ¿FLAG_EMERGENCY = 1?
         SÍ → MOTOR_OFF
         NO → MOTOR_ON
```

- **MOTOR_ON**: `CCPR1L = 0xFF`, LED verde ON, LED rojo OFF, FLAG_MOTOR = 1
- **MOTOR_OFF**: `CCPR1L = 0x00`, LED verde OFF, LED rojo ON, FLAG_MOTOR = 0

### Paso 4 — Probar standalone con valores hardcodeados

El esqueleto ya tiene un bloque TEST comentado en el LOOP.
- Descomentar, asignar valores fijos a `DIST_CM` y `UMBRAL_CM`
- Verificar que los LEDs cambian según la comparación
- Verificar que `CCPR1L` cambia entre 0x00 y 0xFF
- Agregar un delay visible (~0.5s) entre iteraciones para ver los LEDs en simulador

### Prueba en simulador

1. Cargar `HU02-CORTE.asm` standalone
2. Activar TEST con valores hardcodeados
3. Verificar en SFR:
   - `CCPR1L = 0xFF` cuando DIST_CM > UMBRAL_CM
   - `CCPR1L = 0x00` cuando DIST_CM < UMBRAL_CM
4. Verificar LEDs en PORTD (RD0 verde, RD1 rojo)
5. Probar casos borde: UMBRAL_CM = DIST_CM (igual), emergencia activa
