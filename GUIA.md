# Guía de implementación — HUs 1 a 3

> Sin código. Pasos, registros, lógica. Cada HU se prueba standalone en simulador.

---

## HU-03 — ADC + Display (Ari)

**Archivo:** `HU03-ADC-DISPLAY.asm`

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

## HU-01 — Medición HC-SR04 (Juan)

**Archivo:** `HU01-HCSR04.asm`

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

## HU-02 — Corte automático (Amy)

**Archivo:** `HU02-CORTE.asm`

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
