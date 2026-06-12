# Contrato de interfaces — Proyecto Sierra Segura

> Variables compartidas, flags, pines y registros. **Esto no se cambia sin avisar al equipo.**
>
> Las HUs 04-09 se entregan como esqueletos standalone. Al integrar en `tpFinal.asm`, se borra su `__CONFIG` y su `CBLOCK` y se conserva solo el del archivo final (ver cabecera de `tpFinal.asm`).

## Mapa de RAM compartida (Bank 0)

| Dirección | Nombre | Tamaño | Escribe | Lee | Descripción |
|-----------|--------|--------|---------|-----|-------------|
| `0x20` | `DIST_CM` | 1 byte | HU-01 | HU-02, HU-05, HU-07 | Distancia medida en cm (`0xFF` = error/sensor desconectado) |
| `0x21` | `UMBRAL_CM` | 1 byte | HU-03, HU-08 | HU-02, HU-05, HU-07 | Umbral de corte (5–25 cm) |
| `0x22` | `UMBRAL_DEC` | 1 byte | HU-08 | HU-09 | Dígito decenas del umbral |
| `0x23` | `UMBRAL_UNI` | 1 byte | HU-08 | HU-09 | Dígito unidades del umbral |
| `0x24` | `DISP_SEL` | 1 byte | HU-09 | HU-09 | Flag selector display (bit 0) — alterna en cada llamada a RUTINA_DISPLAY |
| `0x25` | `CICLO_CNT` | 1 byte | HU-01 | — | Contador ciclos Timer0 (0–9) |
| `0x26` | `FLAGS` | 1 byte | Todos | Todos | Bits de estado del sistema (ver tabla) |
| `0x27` | `TEMP` | 1 byte | Cualquiera | Cualquiera | Scratch de uso general (TX, conversiones) |
| `0x28` | `ADC_RES` | 1 byte | HU-03 | HU-03 | Último valor leído del ADC |
| `0x29` | `TMR1_H` | 1 byte | HU-01 | HU-01 | Timer1 alto (eco debugging) |
| `0x2A` | `TMR1_L` | 1 byte | HU-01 | HU-01 | Timer1 bajo (eco debugging) |
| `0x2B` | `CONT_DELAY` | 1 byte | Cualquiera | Cualquiera | Contador para retardos cortos (≤256 µs) |
| `0x2C` | `TX_DEC` | 1 byte | HU-05 | HU-05 | Decenas ASCII generadas por BIN_TO_ASCII |
| `0x2D` | `TX_UNI` | 1 byte | HU-05 | HU-05 | Unidades ASCII generadas por BIN_TO_ASCII |

> Las HUs 04-09 **no requieren** direcciones nuevas si sus variables internas son locales a sus subrutinas (salvadas en W o stack). Si una HU necesita variables persistentes propias, se documenta acá antes de sumarla.

### FLAGS (0x26)

| Bit | Nombre | Quién setea | Quién limpia | Descripción |
|-----|--------|-------------|--------------|-------------|
| 0 | `FLAG_TX` | ISR Timer0 (cada 100 ms al final del ciclo) | Main loop (cuando envía la trama) | Hay trama UART lista para enviar |
| 1 | `FLAG_EMERGENCY` | HU-04 (ISR INT0) **y** HU-06 (al recibir `'P'`) | HU-06 (al recibir `'R'`) | Paro de emergencia activo |
| 2 | `FLAG_MOTOR` | HU-02 | HU-02 | 1 = motor ON, 0 = motor OFF. Lo lee HU-07 para actualizar LEDs |
| 3–7 | reservados | — | — | Disponibles para uso futuro |

> **Regla de oro:** cualquiera puede leer `FLAGS`. Solo el dueño de cada bit puede escribirlo.

## Pines (no cambiar)

| Pin | Dirección | Función | Componente | HU owner |
|-----|-----------|---------|------------|----------|
| RA0/AN0 | IN | ADC input | Potenciómetro | HU-03 |
| RB0/INT0 | IN | INT externa (flanco descendente) | Botón emergencia | **HU-04** |
| RC0 | OUT | TRIG | HC-SR04 | HU-01 |
| RC1 | IN | ECHO | HC-SR04 | HU-01 |
| RC2/CCP1 | OUT | PWM | Motor DC (vía TIP31C) | HU-02 |
| RC6/TX | OUT | UART TX | PC (RX) | **HU-05** |
| RC7/RX | IN | UART RX | PC (TX) | **HU-06** |
| RD0 | OUT | LED verde | Estado OK | HU-02, **HU-07** |
| RD1 | OUT | LED rojo | Estado alarma | HU-02, **HU-07** |
| RD2–RD7 | OUT | Seg. a–f | Displays (bus compartido) | HU-03, **HU-09** |
| RE0 | OUT | Selector decenas | Display | HU-03, **HU-09** |
| RE1 | OUT | Selector unidades | Display | HU-03, **HU-09** |

## Tabla BCD→7 segmentos (compartida)

Orden `gfedcba`, cátodo común, activo en alto. Vive en `tpFinal.asm` (no en cada HU).

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

## Registros compartidos (configuración fija)

| Registro | Valor | Bits clave | Quién lo configura | Notas |
|----------|-------|------------|--------------------|-------|
| `ADCON0` | `0x01` | canal AN0, ADC ON | HU-03 | |
| `ADCON1` | `0x80` | justificación derecha, Vref=VDD | HU-03 | |
| `OPTION_REG` | `0x05` | Timer0 prescaler 1:64, **INTEDG=0 (flanco descendente)** | HU-03 / HU-04 | El bit 6 (INTEDG) lo decide HU-04 |
| `T1CON` | `0x01` | Timer1 ON, prescaler 1:1 | HU-01 | |
| `T2CON` | `0x04` | Timer2 ON, prescaler 1:1 | HU-02 | |
| `PR2` | `0xFF` | Periodo PWM | HU-02 | |
| `CCP1CON` | `0x0C` | Modo PWM | HU-02 | |
| `TXSTA` | `0x24` | TX habilitado, async, BRGH=1 | **HU-05** | |
| `RCSTA` | `0x90` | SPEN + CREN, 8 bits | **HU-05** (escribe) / **HU-06** (lee para chequear SPEN) | |
| `SPBRG` | `0x19` | 9600 bps @ 4 MHz con BRGH=1 | **HU-05** | |
| `PIE1` | bit 5 = 1 | RCIE habilitado | **HU-06** | Otros bits de PIE1 en 0 |
| `PIR1` | `TMR1IF` (HU-01) / `RCIF` (HU-06) | Flags de periféricos | compartido: HU-01 limpia TMR1IF, HU-06 limpia RCIF | **No se pisan** (bits distintos) |
| **`INTCON`** | **`0xD0`** | GIE + PEIE + T0IE + INTE | HU-03 inicia con `0xB0`, **HU-04/HU-06 deben asegurar PEIE=1** (queda en `0xD0`) | **Cambio respecto a la versión vieja**: `0xB0` → `0xD0`. Sin PEIE, RCIF no interrumpe. |
| `TRISB` | bit 0 = 1 | RB0 entrada | **HU-04** | |
| `TRISC` | `0xC2` | RC2/RC6 OUT, RC1/RC7 IN | HU-01 + HU-02 + **HU-05/HU-06** | Cada HU setea su bit |
| `TRISD` | `0x03` | RD0–RD7 OUT | HU-02 + HU-03 | |
| `TRISE` | `0x00` | RE0, RE1 OUT | HU-03 | |

### Cambios críticos vs versión vieja

1. **`INTCON = 0xD0` (no `0xB0`).** HU-03 lo escribe en `0xB0`. Hay que actualizarlo a `0xD0` para que las interrupciones de periféricos (RCIF) lleguen. Si esto no se cambia, **HU-06 no funciona**.
2. **`PEIE` (INTCON bit 6) = 1** obligatorio para HU-06.
3. **`PIE1, RCIE` = 1** obligatorio para HU-06. Lo setea HU-06 en su `MAIN`.
4. **Conflicto de `PIR1`:** HU-01 toca `TMR1IF` y HU-06 toca `RCIF`. Bits distintos → no se pisan, pero queda documentado acá para que nadie haga un `BCF PIR1, F` por descuido.

### Orden de prioridad en el dispatcher de la ISR

El archivo integrado debe respetar este orden en el vector 0x04:

1. **INT0 (alta prioridad lógica)** — atender primero
2. **RCIF (UART RX)** — atender segundo
3. **T0IF (Timer0)** — flujo normal al final

Mientras no se active `IPEN=1` (RCON), todas las interrupciones tienen la misma prioridad hardware. El "orden lógico" se logra con la secuencia de chequeo de flags en el dispatcher. Si en el futuro se quiere prioridad hardware real para INT0, hay que sumar `BSF RCON, IPEN` y `BSF INTCON2, INT0IP`.
