# Contrato de interfaces — Proyecto Sierra Segura

> Variables compartidas, flags, pines. **Esto no se cambia sin avisar al otro.**

## Mapa de RAM compartida (Bank 0)

| Dirección | Nombre | Tamaño | Escribe | Lee | Descripción |
|-----------|--------|--------|---------|-----|-------------|
| `0x20` | `DIST_CM` | 1 byte | HU-01 | HU-02 | Distancia medida en cm |
| `0x21` | `UMBRAL_CM` | 1 byte | HU-03 | HU-02 | Umbral de corte (5-25 cm) |
| `0x22` | `UMBRAL_DEC` | 1 byte | HU-03 | — | Dígito decenas del umbral |
| `0x23` | `UMBRAL_UNI` | 1 byte | HU-03 | — | Dígito unidades del umbral |
| `0x24` | `DISP_SEL` | 1 byte | HU-03 | — | Flag selector display (bit 0) |
| `0x25` | `CICLO_CNT` | 1 byte | HU-01 | — | Contador ciclos Timer0 (0-9) |
| `0x26` | `FLAGS` | 1 byte | Todos | Todos | Bits de estado del sistema |

### FLAGS (0x26)

| Bit | Nombre | Quién setea | Quién limpia | Descripción |
|-----|--------|-------------|--------------|-------------|
| 0 | `FLAG_TX` | HU-01/ISR | Main loop | Hay trama UART para enviar |
| 1 | `FLAG_EMERGENCY` | INT0 | 'R' desde PC | Paro de emergencia activo |
| 2 | `FLAG_MOTOR` | HU-02 | HU-02 | 1 = motor ON, 0 = motor OFF |

## Pines (no cambiar)

| Pin | Dirección | Función | Componente | HU que lo usa |
|-----|-----------|---------|------------|---------------|
| RA0/AN0 | IN | ADC input | Potenciómetro | HU-03 |
| RB0/INT0 | IN | INT externa | Botón emergencia | — (HU-04) |
| RC0 | OUT | TRIG | HC-SR04 | HU-01 |
| RC1 | IN | ECHO | HC-SR04 | HU-01 |
| RC2/CCP1 | OUT | PWM | Motor | HU-02 |
| RC6/TX | OUT | UART TX | PC | — (HU-05) |
| RC7/RX | IN | UART RX | PC | — (HU-06) |
| RD0 | OUT | LED verde | Estado OK | HU-02 |
| RD1 | OUT | LED rojo | Estado alarma | HU-02 |
| RD2–RD7 | OUT | Seg. a–f | Displays | HU-03 |
| RE0 | OUT | Selector dec | Display | HU-03 |
| RE1 | OUT | Selector uni | Display | HU-03 |

## Tabla BCD→7 segmentos (compartida)

Orden `gfedcba`, cátodo común, activo en alto.

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

| Registro | Valor | Quién lo configura |
|----------|-------|-------------------|
| ADCON0 | `0x01` | HU-03 |
| ADCON1 | `0x80` | HU-03 |
| OPTION_REG | `0x05` (Timer0 prescaler 1:64) | HU-03 |
| T1CON | `0x01` (Timer1 ON, 1:1) | HU-01 |
| T2CON | `0x04` (Timer2 ON, 1:1) | HU-02 |
| PR2 | `0xFF` | HU-02 |
| CCP1CON | `0x0C` (PWM mode) | HU-02 |
| SPBRG | `0x19` (9600 bps) | — |
| INTCON | `0xB0` (GIE, TMR0IE, INTE) | HU-03 |
| TRISC2 | 0 (salida) | HU-02 |
