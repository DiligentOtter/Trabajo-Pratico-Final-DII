# Guía de implementación — Proyecto Sierra Segura

> Pasos, registros y lógica para cada HU. **Las HUs se conservan al final marcadas como OBSOLETAS** porque su código terminó integrado en `tpFinal.asm`.

> **Reglas de estilo** (aplican a todas las HUs nuevas y al integrado):
> - UPPERCASE para labels, registros y constantes.
> - `BANKSEL` antes de cualquier acceso cross-bank.
> - Comentarios en español, una línea por bloque lógico.
> - Guardar W y STATUS al entrar a ISR (`MOVWF W_TEMP` / `SWAPF STATUS,W` / `MOVWF STATUS_TEMP`) y restaurar antes de `RETFIE`.
> - Flag `__CONFIG` y `CBLOCK` viven una sola vez (en `tpFinal.asm`). Al integrar, borrar los de la HU.

---

## Índice
- [HU-09 — Rutina de multiplexado de displays](#hu-09--rutina-de-multiplexado-de-displays) — **NUEVO**
- [HU-08 — Display del umbral de corte](#hu-08--display-del-umbral-de-corte) — **NUEVO**
- [HU-07 — Indicación visual de estado (LEDs)](#hu-07--indicación-visual-de-estado-leds) — **NUEVO**
- [HU-06 — Control desde PC (UART RX)](#hu-06--control-desde-pc-uart-rx) — *OBSOLETA*
- [HU-05 — Monitoreo desde PC (UART TX)](#hu-05--monitoreo-desde-pc-uart-tx) — *OBSOLETA*
- [HU-04 — Botón de emergencia (INT0)](#hu-04--botón-de-emergencia-int0) — *OBSOLETA*
- [HU-03 — ADC + Display](#hu-03--adc--display) — *OBSOLETA (integrada en `tpFinal.asm`)*
- [HU-02 — Corte automático](#hu-02--corte-automático) — *OBSOLETA (integrada en `tpFinal.asm`)*
- [HU-01 — Medición HC-SR04](#hu-01--medición-hc-sr04) — *OBSOLETA (integrada en `tpFinal.asm`)*
---

## HU-07 — Indicación visual de estado (LEDs)

**Archivo:** `HU07-LEDS.asm` (esqueleto standalone).

**Propósito:** reflejar el estado del motor en los LEDs verde (RD0) y rojo (RD1) de forma mutuamente excluyente. La subrutina `ACTUALIZAR_LEDS` lee `FLAGS` bit 2 (`FLAG_MOTOR`) y setea los LEDs en consecuencia.

### Dependencias

- `FLAGS` bit 2 (`FLAG_MOTOR`) debe estar actualizado antes de llamar a `ACTUALIZAR_LEDS`. Lo escribe `COMPARAR_Y_ACTUAR` (HU-02) cada ciclo de 100 ms y también `ISR_EMERGENCIA` (HU-04) ante un paro.
- `PORTD` bits 0 y 1 configurados como salida (lo hace `tpFinal.asm` en el MAIN).

### Paso 1 — La subrutina `ACTUALIZAR_LEDS`

Lógica:

```
¿FLAGS bit 2 = 1? (FLAG_MOTOR)
  SÍ → LED verde ON (RD0=1), LED rojo OFF (RD1=0)
  NO → LED verde OFF (RD0=0), LED rojo ON (RD1=1)
```

En assembly:

```asm
ACTUALIZAR_LEDS
    BTFSS   FLAGS, 2       ; FLAG_MOTOR = 1?
    GOTO    LED_MOTOR_OFF

LED_MOTOR_ON
    BSF     PORTD, 0       ; verde ON
    BCF     PORTD, 1       ; rojo OFF
    RETURN

LED_MOTOR_OFF
    BCF     PORTD, 0       ; verde OFF
    BSF     PORTD, 1       ; rojo ON
    RETURN
```

### Paso 2 — Dónde llamarla

- **En `COMPARAR_Y_ACTUAR`** (HU-02): después de decidir si el motor se enciende o se apaga, llamar a `ACTUALIZAR_LEDS`.
- **En `ISR_EMERGENCIA`** (HU-04): después de cortar el motor, llamar a `ACTUALIZAR_LEDS`.

No hace falta llamarla desde el LOOP principal porque los LEDs solo cambian cuando cambia el estado del motor.

### Paso 3 — Integración en `tpFinal.asm`

1. Borrar `__CONFIG` y `CBLOCK` de `HU07-LEDS.asm`.
2. En `COMPARAR_Y_ACTUAR`, después de setear/limpiar `FLAG_MOTOR` y `CCPR1L`, agregar `CALL ACTUALIZAR_LEDS`.
3. En `ISR_EMERGENCIA`, después de `BSF FLAGS, 1`, agregar `CALL ACTUALIZAR_LEDS`.
4. Pegar la subrutina `ACTUALIZAR_LEDS` al final del archivo (o cerca de `COMPARAR_Y_ACTUAR`).

### Prueba en simulador

1. Cargar `HU07-LEDS.asm` standalone.
2. Verificar estado inicial: LED rojo ON (RD1=1), verde OFF (RD0=0).
3. Poner `BSF FLAGS, 2` y step over `CALL ACTUALIZAR_LEDS` → verde ON, rojo OFF.
4. Poner `BCF FLAGS, 2` y step over → rojo ON, verde OFF.
5. Verificar que nunca quedan ambos LEDs encendidos (exclusión mutua).

---

## HU-08 — Display del umbral de corte

**Archivo:** `HU08-DISPLAY-UMBRAL.asm` (esqueleto standalone).

**Propósito:** tomar el valor de `UMBRAL_CM` (0–25) y descomponerlo en decenas (`UMBRAL_DEC`) y unidades (`UMBRAL_UNI`) mediante resta sucesiva de 10. Esta conversión se hace cada 100 ms, justo después de leer el ADC y actualizar `UMBRAL_CM`.

### Dependencias

- `UMBRAL_CM` debe estar actualizado (lo escribe HU-03 desde `LEER_ADC`).
- `UMBRAL_DEC` y `UMBRAL_UNI` los consume HU-09 (`RUTINA_DISPLAY`).

### Paso 1 — La subrutina `CONVERTIR_UMBRAL_A_BCD`

Usa resta sucesiva de 10:

```asm
CONVERTIR_UMBRAL_A_BCD
    MOVF    UMBRAL_CM, W
    MOVWF   TEMP
    CLRF    UMBRAL_DEC

BCD_DEC_LOOP
    MOVLW   .10
    SUBWF   TEMP, W
    BTFSS   STATUS, C
    GOTO    BCD_DEC_DONE
    MOVWF   TEMP
    INCF    UMBRAL_DEC, F
    GOTO    BCD_DEC_LOOP

BCD_DEC_DONE
    MOVF    TEMP, W
    MOVWF   UMBRAL_UNI
    RETURN
```

### Paso 2 — Dónde llamarla

Cada 100 ms, después de `LEER_ADC` y de actualizar `UMBRAL_CM`, antes o después de `COMPARAR_Y_ACTUAR`. En el integrado de `tpFinal.asm`, se agrega en el bloque de "cada 100ms" de la ISR.

### Paso 3 — Integración en `tpFinal.asm`

1. Borrar `__CONFIG` y `CBLOCK` de `HU08-DISPLAY-UMBRAL.asm`.
2. En la ISR, dentro del bloque de cada 100 ms (cuando `CICLO_CNT == 10`), después de `CALL LEER_ADC`, agregar `CALL CONVERTIR_UMBRAL_A_BCD`.
3. Pegar la subrutina al final del archivo.

### Prueba en simulador

1. Cargar `HU08-DISPLAY-UMBRAL.asm` standalone.
2. Probar distintos valores de `UMBRAL_CM`:
   - `UMBRAL_CM = 15` → `UMBRAL_DEC = 1`, `UMBRAL_UNI = 5`
   - `UMBRAL_CM = 0`  → `UMBRAL_DEC = 0`, `UMBRAL_UNI = 0`
   - `UMBRAL_CM = 25` → `UMBRAL_DEC = 2`, `UMBRAL_UNI = 5`
   - `UMBRAL_CM = 7`  → `UMBRAL_DEC = 0`, `UMBRAL_UNI = 7`
3. Verificar que la conversión es correcta en todos los casos.

---

## HU-09 — Rutina de multiplexado de displays

**Archivo:** `HU09-MULTIPLEX.asm` (esqueleto standalone).

**Propósito:** implementar el multiplexado por software de los dos displays de 7 segmentos. Se llama desde la ISR del Timer0 (cada ~10 ms) y alterna entre mostrar el dígito de decenas y el de unidades. Aplica anti-ghosting apagando ambos selectores antes de cambiar el bus de segmentos.

### Dependencias

- `UMBRAL_DEC` y `UMBRAL_UNI` deben estar actualizados (HU-08 los escribe cada 100 ms).
- `DISP_SEL` almacena qué dígito mostrar (bit 0: 0 = decenas, 1 = unidades).
- `PORTD` (segmentos) y `PORTE` (selectores RE0, RE1) configurados como salidas.
- `BCD_7SEG` tabla lookup en program memory (0–9).

### Paso 1 — La subrutina `RUTINA_DISPLAY`

```asm
RUTINA_DISPLAY
    ; Anti-ghosting: apagar ambos selectores
    BCF     PORTE, 0       ; RE0 OFF
    BCF     PORTE, 1       ; RE1 OFF

    BTFSS   DISP_SEL, 0    ; DISP_SEL = 0 ?
    GOTO    SHOW_DECENAS

SHOW_UNIDADES
    MOVF    UMBRAL_UNI, W
    CALL    BCD_7SEG
    MOVWF   PORTD
    BSF     PORTE, 1       ; RE1 ON (unidades)
    BCF     DISP_SEL, 0    ; proxima vez: decenas
    RETURN

SHOW_DECENAS
    MOVF    UMBRAL_DEC, W
    CALL    BCD_7SEG
    MOVWF   PORTD
    BSF     PORTE, 0       ; RE0 ON (decenas)
    BSF     DISP_SEL, 0    ; proxima vez: unidades
    RETURN
```

### Paso 2 — Tabla `BCD_7SEG`

Orden `gfedcba`, cátodo común, activo en alto.

```asm
BCD_7SEG
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

### Paso 3 — Dónde llamarla

Al inicio de la ISR del Timer0, **siempre** (cada ~10 ms), antes del ciclo de 100 ms. Esto garantiza que los displays se refresquen continuamente y no se apaguen durante el ciclo largo de medición.

### Paso 4 — Integración en `tpFinal.asm`

1. Borrar `__CONFIG` y `CBLOCK` de `HU09-MULTIPLEX.asm`.
2. En la ISR de `tpFinal.asm`, justo después de recargar `TMR0` y antes del resto de la lógica, agregar `CALL RUTINA_DISPLAY`. Ya existe ese llamado en la línea ~97 del `tpFinal.asm` actual, pero está vacío. Reemplazar el label vacío por esta implementación.
3. Pegar `RUTINA_DISPLAY` y `BCD_7SEG` al final del archivo.
4. Asegurarse de que la tabla `BCD_7SEG` no esté duplicada si ya existe en `tpFinal.asm`.

### Prueba en simulador

1. Cargar `HU09-MULTIPLEX.asm` standalone.
2. Step over `CALL RUTINA_DISPLAY` varias veces.
3. Verificar que alterna:
   - Llamada 1 (DISP_SEL=0): RE0 ON, PORTD = patrón del dígito en UMBRAL_DEC, DISP_SEL pasa a 1.
   - Llamada 2 (DISP_SEL=1): RE1 ON, PORTD = patrón del dígito en UMBRAL_UNI, DISP_SEL pasa a 0.
4. Verificar anti-ghosting: al entrar a `RUTINA_DISPLAY`, antes de escribir PORTD, tanto RE0 como RE1 están en 0.
5. Cambiar valores de prueba: `UMBRAL_DEC = 0`, `UMBRAL_UNI = 8` → debe mostrar '0' y '8'.

---

## HU-04 — Botón de emergencia (INT0)

> **⚠️ OBSOLETA** — El esqueleto `HU04-EMERGENCIA.asm` está completado y listo para integrar. Esta sección se conserva como referencia para la integración final.

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
5. `CALL ACTUALIZAR_LEDS` (HU-07) — para centralizar la lógica de LEDs.
6. `RETURN` (vuelve al dispatcher, que hace `RETFIE`).

> **Detalle:** no es toggle. Si la mano sigue apretando el botón, el flag queda set y el motor sigue cortado. La liberación es **únicamente** por `'R'` desde la PC (HU-06), no por hardware.

### Paso 5 — Integración en `tpFinal.asm`

1. Borrar `__CONFIG` y `CBLOCK` de `HU04-EMERGENCIA.asm`.
2. En `MAIN` de `tpFinal.asm`, agregar (en el bloque de Bank 1):
   - `BSF TRISB, 0`
   - `BCF OPTION_REG, INTEDG`
3. Reemplazar el `INTCON = 0xB0` por `INTCON = 0xD0`.
4. En el dispatcher de la ISR, insertar el bloque de chequeo de INT0IF.
5. Pegar `ISR_EMERGENCIA` al final del archivo, antes del `END`.
6. Si HU-07 ya está integrada, agregar `CALL ACTUALIZAR_LEDS` dentro de `ISR_EMERGENCIA` (opcional, ya que HU-07 puede llamarse desde COMPARAR_Y_ACTUAR en el próximo ciclo).

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

> **⚠️ OBSOLETA** — El esqueleto `HU05-UART-TX.asm` está completado y listo para integrar. Esta sección se conserva como referencia para la integración final.

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
- **`BIN_TO_ASCII(W)`**: convierte byte 0–99 a ASCII decimal (decenas en `TX_DEC`, unidades en `TX_UNI`). Método: resta sucesiva de 10.
- **`ENVIAR_TRAMA`**: emite los 18 bytes en orden.

### Paso 4 — Integración en `tpFinal.asm`

1. Borrar `__CONFIG` y `CBLOCK` de `HU05-UART-TX.asm`.
2. En `MAIN` de `tpFinal.asm`, agregar la configuración UART de la HU.
3. En el `LOOP` actual, insertar el chequeo de `FLAG_TX`.
4. En la ISR, después de `CALL COMPARAR_Y_ACTUAR`, agregar `BSF FLAGS, 0`.
5. Pegar `ENVIAR_TRAMA`, `TX_BYTE` y `BIN_TO_ASCII` al final del archivo.

### Prueba en simulador

1. Cargar `HU05-UART-TX.asm` standalone.
2. Setear manualmente en RAM:
   - `DIST_CM = .12`
   - `UMBRAL_CM = .08`
   - `FLAGS` bit 2 = 1 (motor ON)
3. Abrir *Simulator > UART1 IO*.
4. Verificar que la trama `D:12cm U:08cm M:ON\r\n` sale byte por byte.
5. Probar variantes: `DIST_CM=5, UMBRAL_CM=25, motor OFF` → `D:05cm U:25cm M:OFF\r\n`.
6. Si la trama sale mal, revisar primero `BIN_TO_ASCII`.

---

## HU-06 — Control desde PC (UART RX)

> **⚠️ OBSOLETA** — El esqueleto `HU06-UART-RX.asm` está completado y listo para integrar. Esta sección se conserva como referencia para la integración final.

**Archivo:** `HU06-UART-RX.asm` (esqueleto standalone).

**Propósito:** recibir comandos ASCII desde la PC y traducirlos a acciones sobre el sistema. Comandos soportados:

| Byte | Acción |
|------|--------|
| `'R'` (`0x52`) | Limpia `FLAG_EMERGENCY`. El próximo ciclo de 100 ms re-evalúa `DIST_CM < UMBRAL_CM`. |
| `'P'` (`0x50`) | Ejecuta la lógica de `ISR_EMERGENCIA`: motor OFF, LED rojo, `FLAG_EMERGENCY = 1`. |
| Otro | Ignorado. |

### Paso 1 — Configurar UART (mismos registros que HU-05)

El archivo standalone reescribe la config para poder probarse solo. En el integrado, **HU-05 ya deja todo listo** y esta HU no repite la config.

### Paso 2 — Habilitar la interrupción de RX

1. `PIE1, RCIE = 1` (bit 5) — habilita localmente la IRQ de RCIF.
2. `INTCON, PEIE = 1` (bit 6) — habilita globalmente las IRQs de periféricos. Sin esto, `RCIE` prendido no hace nada.

### Paso 3 — Dispatcher

Insertar el chequeo de `RCIF` entre `INT0IF` y `T0IF` (ver diagrama en HU-04 paso 3).

### Paso 4 — `ISR_UART_RX`

Pasos:

1. Chequear `RCSTA, OERR` (overrun). Si está en 1, resetear: `BCF RCSTA, CREN` / `BSF RCSTA, CREN`.
2. `MOVF RCREG, W` — leer el byte (limpia `RCIF` automáticamente).
3. Comparar con `'R'` y con `'P'` (resta sucesiva + `BTFSC STATUS, Z`).
4. Si es `'R'`: `BCF FLAGS, 1`.
5. Si es `'P'`: `CALL ISR_EMERGENCIA`.
6. Si es otro: ignorar.

### Paso 5 — Integración en `tpFinal.asm`

1. Borrar `__CONFIG` y `CBLOCK` de `HU06-UART-RX.asm`.
2. En `MAIN`, agregar `BSF PIE1, RCIE` en Bank 1. `INTCON = 0xD0` ya lo deja HU-04.
3. En el dispatcher, insertar `CHECK_RCIF` entre INT0 y T0.
4. Pegar `ISR_UART_RX` al final. **No** pegar `ISR_EMERGENCIA` duplicada.

### Prueba en simulador

1. Cargar `HU06-UART-RX.asm` standalone.
2. Setear `BSF FLAGS, 1` (emergencia activa).
3. Abrir *Simulator > UART1 IO*.
4. Enviar `'R'` → `FLAGS` bit 1 = 0.
5. Enviar `'P'` → `FLAGS` bit 1 = 1, `PORTD` bit 1 = 1, `CCPR1L = 0x00`.
6. Enviar `'X'` → no debe cambiar nada.
7. Probar recovery de overrun: forzar `OERR` y enviar varios bytes.

---

## HU-03 — ADC + Display

> **⚠️ OBSOLETA** — La implementación operativa vive en `tpFinal.asm`. Esta sección se conserva como referencia histórica de las decisiones de diseño (rango 5–25 cm, multiplexado por software, justificación derecha del ADC). Las HUs 08 y 09 reemplazan la parte de display de esta HU.

**Archivo histórico:** `HU03-ADC-DISPLAY.asm`

### Paso 1 — Configurar puertos

- TRISA: bit 0 como entrada (RA0/AN0, potenciómetro)
- TRISD: bits 2-7 como salidas (segmentos a-f), bits 0-1 como salidas (LEDs)
- TRISE: bits 0-1 como salidas (selectores displays)
- Inicializar PORTD = 0, PORTE = 0

### Paso 2 — Configurar ADC

- `ADCON1 = 0x80`: Vref = VDD, justificado a derecha
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
2. **RUTINA_DISPLAY** (HU-09): alternar dígito
3. **Contador**: incrementar, cuando llegue a 10 (~100ms):
   - Iniciar ADC (`BSF ADCON0, GO`)
   - Esperar que termine (`BTFSC ADCON0, GO`)
   - Leer `ADRESH` → `ADC_RES`
   - Mapear 0-255 a 5-25 cm: `UMBRAL_CM = 5 + (ADC_RES / 13)`
   - Llamar `CONVERTIR_UMBRAL_A_BCD` (HU-08)

### Paso 5 — Implementar RUTINA_DISPLAY (ver HU-09)

El multiplexado se extrajo a HU-09. Acá solo queda el llamado.

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
   - Al bajar RC1: leer `TMR1H:TMR1L`

4. **Calcular distancia**:
   - `dist_cm = (ticks × 9) / 512` — división por shift (±1 cm error)
   - Multiplicar ticks × 9 (3 shifts + suma), luego dividir por 512 (9 shifts a la derecha)
   - Si timeout (TMR1IF): `DIST_CM = 0xFF`

5. **Reiniciar Timer1** para la próxima

### Prueba en simulador

1. Cargar `HU01-HCSR04.asm` standalone
2. Poner estímulo en RC1 (ECHO)
3. Verificar que TRIG (RC0) pulsa por 10µs cada 100ms
4. Simular ECHO con diferentes anchos:
   - 580 µs → 10 cm
   - 1160 µs → 20 cm
   - 2900 µs → 50 cm
5. Verificar que `DIST_CM` se actualiza correctamente
6. Probar timeout: no poner ECHO → `DIST_CM = 0xFF`

---

## HU-02 — Corte automático

> **⚠️ OBSOLETA** — La implementación operativa vive en `tpFinal.asm`. Esta sección se conserva como referencia histórica del contrato con `FLAG_EMERGENCY`.

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

```
¿DIST_CM < UMBRAL_CM?
  SÍ → MOTOR_OFF
  NO → ¿FLAG_EMERGENCY = 1?
         SÍ → MOTOR_OFF
         NO → MOTOR_ON
```

- **MOTOR_ON**: `CCPR1L = 0xFF`, LED verde ON, LED rojo OFF, FLAG_MOTOR = 1, luego `CALL ACTUALIZAR_LEDS` (HU-07)
- **MOTOR_OFF**: `CCPR1L = 0x00`, LED verde OFF, LED rojo ON, FLAG_MOTOR = 0, luego `CALL ACTUALIZAR_LEDS` (HU-07)

### Paso 4 — Probar standalone

El esqueleto ya tiene un bloque TEST comentado en el LOOP.

### Prueba en simulador

1. Cargar `HU02-CORTE.asm` standalone
2. Activar TEST con valores hardcodeados
3. Verificar en SFR:
   - `CCPR1L = 0xFF` cuando DIST_CM > UMBRAL_CM
   - `CCPR1L = 0x00` cuando DIST_CM < UMBRAL_CM
4. Verificar LEDs en PORTD (RD0 verde, RD1 rojo)
5. Probar casos borde: UMBRAL_CM = DIST_CM (igual), emergencia activa

---

*Fin del documento*
