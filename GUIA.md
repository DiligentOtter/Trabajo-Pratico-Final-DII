# Guia de implementacion - Proyecto Sierra Segura

> Pasos, registros y logica para cada HU. Las HUs 01/02/03 y 04/05/06 estan marcadas como OBSOLETAS porque su codigo esta completo en archivos standalone o integrado en `tpFinal.asm`. La HU activa es la 10 (PWM).

> **Reglas de estilo** (aplican a todas las HUs):
> - UPPERCASE para labels, registros y constantes.
> - `BANKSEL` antes de cualquier acceso cross-bank.
> - Comentarios en español, una linea por bloque logico.
> - Guardar W y STATUS al entrar a ISR (`MOVWF W_TEMP` / `SWAPF STATUS,W` / `MOVWF STATUS_TEMP`) y restaurar antes de `RETFIE`.
> - Subrutinas terminan en `RETURN`, ISRs en `RETFIE`.
> - `__CONFIG` y `CBLOCK` viven una sola vez (en `tpFinal.asm`). Al integrar, borrar los de la HU.

---

## Indice

- [HU-10 - Control PWM del motor](#hu-10--control-pwm-del-motor) -- **NUEVO**
- [HU-06 - Control desde PC (UART RX)](#hu-06--control-desde-pc-uart-rx) -- *OBSOLETA*
- [HU-05 - Monitoreo desde PC (UART TX)](#hu-05--monitoreo-desde-pc-uart-tx) -- *INTEGRADA*
- [HU-04 - Boton de emergencia (INT0)](#hu-04--boton-de-emergencia-int0) -- *INTEGRADA*
- [HU-03 - ADC + Display](#hu-03--adc--display) -- *INTEGRADA*
- [HU-02 - Corte automatico](#hu-02--corte-automatico) -- *OBSOLETA (integrada en `tpFinal.asm`)*
- [HU-01 - Medicion HC-SR04](#hu-01--medicion-hc-sr04) -- *INTEGRADA! 

---

## HU-10 - Control PWM del motor

**Archivo:** `HU10-PWM.asm` (esqueleto standalone).

**Proposito:** configurar el modulo CCP1 en modo PWM con Timer2 para controlar el motor DC via RC2. Provee las subrutinas `PWM_INIT` (configuracion unica al inicio), `PWM_ON` (100% duty) y `PWM_OFF` (0% duty).

### Dependencias

- Ninguna variable de RAM compartida (usa solo registros de perifericos).
- `TRISC` bit 2 debe configurarse como salida antes de habilitar CCP1.
- `COMPARAR_Y_ACTUAR` (HU-02) llama a `PWM_ON` / `PWM_OFF`.
- `ISR_EMERGENCIA` (HU-04) llama a `PWM_OFF`.

### Paso 1 - Subrutina `PWM_INIT`

Registros a configurar (todos en Bank x segun corresponda):

| Registro | Valor | Descripcion |
|----------|-------|-------------|
| `TRISC` bit 2 | 0 | RC2 como salida |
| `T2CON` | `0x04` | Timer2 ON, prescaler 1:1 |
| `PR2` | `0xFF` | Periodo maximo (~3.9 kHz a 4 MHz) |
| `CCP1CON` | `0x0C` | Modo PWM |
| `CCPR1L` | `0x00` | Duty 0% (motor OFF por defecto) |

Orden recomendado:

```asm
PWM_INIT
    BANKSEL TRISC
    BCF     TRISC, 2       ; RC2 como salida
    BANKSEL T2CON
    MOVLW   0x04
    MOVWF   T2CON
    BANKSEL PR2
    MOVLW   0xFF
    MOVWF   PR2
    BANKSEL CCP1CON
    MOVLW   0x0C
    MOVWF   CCP1CON
    BANKSEL CCPR1L
    CLRF    CCPR1L         ; motor OFF
    RETURN
```

### Paso 2 - Subrutinas `PWM_ON` y `PWM_OFF`

```asm
PWM_ON
    BANKSEL CCPR1L
    MOVLW   0xFF
    MOVWF   CCPR1L
    RETURN

PWM_OFF
    BANKSEL CCPR1L
    CLRF    CCPR1L
    RETURN
```

### Paso 3 - Donde llamarlas

- `PWM_INIT` en `MAIN` de `tpFinal.asm` (despues de configurar TRISC, antes de habilitar interrupciones).
- `PWM_ON` / `PWM_OFF` desde `COMPARAR_Y_ACTUAR` (HU-02) cuando decide motor ON u OFF.
- `PWM_OFF` desde `ISR_EMERGENCIA` (HU-04) ante un paro de emergencia.

### Paso 4 - Integracion en `tpFinal.asm`

1. Borrar `__CONFIG` y `CBLOCK` de `HU10-PWM.asm`.
2. En `MAIN`, agregar `CALL PWM_INIT` en el bloque de configuracion (Bank 1 o donde se configuren los perifericos).
3. En `COMPARAR_Y_ACTUAR` (HU-02), reemplazar `CLRF CCPR1L` / `MOVLW 0xFF` / `MOVWF CCPR1L` por `CALL PWM_OFF` / `CALL PWM_ON`.
4. En `ISR_EMERGENCIA` (HU-04), reemplazar `CLRF CCPR1L` por `CALL PWM_OFF`.
5. Pegar `PWM_INIT`, `PWM_ON` y `PWM_OFF` al final del archivo.

### Prueba en simulador

1. Cargar `HU10-PWM.asm` standalone.
2. Step over `CALL PWM_INIT` y verificar en SFR:
   - `T2CON` = 0x04
   - `PR2` = 0xFF
   - `CCP1CON` = 0x0C
   - `CCPR1L` = 0x00
   - `TRISC` bit 2 = 0
3. Llamar `CALL PWM_ON` -> `CCPR1L` = 0xFF.
4. Llamar `CALL PWM_OFF` -> `CCPR1L` = 0x00.

---

## HU-04 - Boton de emergencia (INT0)

> **OBSOLETA** - El esqueleto `HU04-EMERGENCIA.asm` esta completado y listo para integrar.

**Archivo:** `HU04-EMERGENCIA.asm` (esqueleto standalone).

**Proposito:** atender el pulsador fisico de emergencia con la latencia mas corta posible, cortar el motor, encender el LED rojo y marcar `FLAG_EMERGENCY`.

### Paso 1 - Configurar el pin

- `TRISB, 0 = 1` -> RB0 como entrada.
- `OPTION_REG, INTEDG = 0` -> flanco descendente.

### Paso 2 - Habilitar INT0

- `INTCON = 0xD0` (GIE + PEIE + T0IE + INTE).

### Paso 3 - Dispatcher de ISR con prioridad

Orden de chequeo en el vector 0x04:
1. `INT0IF` (emergencia)
2. `RCIF` (UART RX)
3. `T0IF` (Timer0)

### Paso 4 - `ISR_EMERGENCIA`

Pasos:
1. `BCF INTCON, INT0IF`
2. `CALL PWM_OFF` (HU-10) -> motor OFF
3. `BSF PORTD, 1` -> LED rojo ON
4. `BCF PORTD, 0` -> LED verde OFF
5. `BSF FLAGS, 1` -> `FLAG_EMERGENCY = 1`
6. `RETURN`

> La liberacion es unicamente por `'R'` desde la PC (HU-06).

### Paso 5 - Integracion en `tpFinal.asm`

1. Borrar `__CONFIG` y `CBLOCK` de `HU04-EMERGENCIA.asm`.
2. En `MAIN`: `BSF TRISB, 0` + `BCF OPTION_REG, INTEDG`.
3. `INTCON = 0xD0`.
4. En el dispatcher, insertar chequeo de INT0IF.
5. Pegar `ISR_EMERGENCIA` al final.

---

## HU-05 - Monitoreo desde PC (UART TX)

> **OBSOLETA** - El esqueleto `HU05-UART-TX.asm` esta completado.

**Archivo:** `HU05-UART-TX.asm`.

**Proposito:** emitir por UART cada 100 ms: `D:XXcm U:XXcm M:XX\r\n`.

### Configuracion UART

```
TRISC,6 = 0, TRISC,7 = 1
TXSTA = 0x24, SPBRG = 0x19, RCSTA = 0x90
```

### Handshake con ISR

- ISR setea `FLAGS,0` cada 100 ms.
- Loop principal chequea `FLAG_TX`, llama a `ENVIAR_TRAMA`.

### Subrutinas

- `TX_BYTE(W)`: espera TRMT, escribe TXREG.
- `BIN_TO_ASCII(W)`: convierte byte 0-99 a ASCII (decenas en TX_DEC, unidades en TX_UNI).
- `ENVIAR_TRAMA`: emite los 18 bytes.

### Integracion

1. Borrar `__CONFIG` y `CBLOCK`.
2. Agregar config UART en MAIN.
3. Loop con chequeo de `FLAG_TX`.
4. ISR: `BSF FLAGS, 0` al final del ciclo de 100 ms.

---

## HU-06 - Control desde PC (UART RX)

> **OBSOLETA** - El esqueleto `HU06-UART-RX.asm` esta completado.

**Archivo:** `HU06-UART-RX.asm`.

**Proposito:** recibir comandos `'R'` (reanudar) y `'P'` (parar) desde la PC.

### Comandos

| Byte | Accion |
|------|--------|
| `'R'` | `BCF FLAGS, 1` (limpia emergencia) |
| `'P'` | `CALL ISR_EMERGENCIA` |
| Otro | Ignorado |

### Requisitos

1. `PIE1, RCIE = 1`.
2. `INTCON, PEIE = 1` (ya lo deja HU-04 con `0xD0`).

### Integracion

1. Borrar `__CONFIG` y `CBLOCK`.
2. En MAIN: `BSF PIE1, RCIE`.
3. En dispatcher: insertar `CHECK_RCIF` entre INT0 y T0.
4. Pegar `ISR_UART_RX`.

---

## HU-03 - ADC + Display

> **OBSOLETA** - La implementacion operativa vive en `tpFinal.asm` y `HU03-ADC-DISPLAY.asm`.

**Archivo historico:** `HU03-ADC-DISPLAY.asm`

### Configuracion ADC

- `ADCON1 = 0x80`: Vref = VDD, justificado a derecha.
- `ADCON0 = 0x41`: canal AN0, ADC ON.
- Leer: `BSF ADCON0, GO` -> esperar -> `MOVF ADRESL, W`.

### Mapeo a cm

`UMBRAL_CM = 5 + (ADC_RES / 13)` (rango 5-25 cm).

### Conversion a BCD

Resta sucesiva de 10 para obtener UMBRAL_DEC y UMBRAL_UNI.

### RUTINA_DISPLAY

Multiplexado con anti-ghosting, alterna RE0/RE1 segun DISP_SEL. Tabla BCD_7SEG en program memory.

---

## HU-01 - Medicion HC-SR04

> **OBSOLETA** - La implementacion operativa vive en `tpFinal.asm`.

**Archivo historico:** `HU01-HCSR04.asm`

### Secuencia

1. Pulso TRIG de 10 us en RC0.
2. Esperar ECHO = 1 (timeout ~1 ms).
3. Medir ancho con Timer1 (1 tick = 1 us).
4. `dist_cm = ticks * 9 / 512`.
5. Timeout -> `DIST_CM = 0xFF`.

---

## HU-02 - Corte automatico

> **OBSOLETA** - La implementacion operativa vive en `tpFinal.asm`.

**Archivo historico:** `HU02-CORTE.asm`

### Logica de COMPARAR_Y_ACTUAR

```
DIST_CM < UMBRAL_CM?
  SI -> PWM_OFF, LED rojo ON, FLAG_MOTOR = 0
  NO -> FLAG_EMERGENCY = 1?
          SI -> PWM_OFF, LED rojo ON, FLAG_MOTOR = 0
          NO -> PWM_ON, LED verde ON, FLAG_MOTOR = 1
```

### Configuracion PWM

Ahora delegada a HU-10. `COMPARAR_Y_ACTUAR` solo llama a `PWM_ON` / `PWM_OFF`.

---

*Fin del documento*
