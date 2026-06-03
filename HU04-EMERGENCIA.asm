;---------------------------------------------------------------------
; HU-04 — Botón de emergencia (INT0 en RB0)
; Propósito: Atender por flanco descendente en RB0, cortar motor,
;            activar LED rojo y marcar FLAG_EMERGENCY. La liberación
;            es responsabilidad de HU-06 (al recibir 'R' desde PC).
; Integración: al pegar en tpFinal.asm, borrar este __CONFIG y este
;              CBLOCK, y fusionar ISR_EMERGENCIA + dispatcher.
; ------------------------------------------------------------------
    LIST p=16F887
    #INCLUDE "P16F887.inc"
    RADIX HEX

    __CONFIG _CONFIG1, _FOSC_HS & _WDTE_OFF & _PWRTE_ON & _MCLRE_ON & _LVP_OFF
    __CONFIG _CONFIG2, _BOR4V_BOR40V & _WRT_OFF

; ─── Variables (CONTRATO + privadas de la HU) ───
    CBLOCK 0x20
        DIST_CM         ; 0x20  — compartido, no se usa acá
        UMBRAL_CM       ; 0x21  — compartido, no se usa acá
        UMBRAL_DEC      ; 0x22
        UMBRAL_UNI      ; 0x23
        DISP_SEL        ; 0x24
        CICLO_CNT       ; 0x25
        FLAGS           ; 0x26  — bit 1 = FLAG_EMERGENCY (dueño: HU-04 setea, HU-06 limpia)
        TEMP            ; 0x27
        W_TEMP          ; 0x28  — context save
        STATUS_TEMP     ; 0x29
    ENDC

; ─── Vector Reset ───
    ORG     0
    GOTO    MAIN

; ─── Vector ISR ───
    ORG     4
    GOTO    ISR_DISPATCHER

; =================================================================
; MAIN
; Configura RB0 como entrada y dispara la ISR al primer flanco
; descendente. El resto (PWM, LEDs, etc.) lo asume ya hecho HU-02
; en el integrado.
; =================================================================
MAIN:
    ; ── 1. RB0 como entrada ──
    BANKSEL TRISB
    BSF     TRISB, 0          ; RB0/INT0 = IN

    ; ── 2. Flanco descendente en INT0 ──
    ; OPTION_REG bit 6 = INTEDG. 0 = descendente, 1 = ascendente.
    ; Cuidado: el resto de OPTION_REG lo define HU-03 (prescaler T0),
    ; por eso usamos BCF sobre el bit, no MOVLW directo.
    BANKSEL OPTION_REG
    BCF     OPTION_REG, INTEDG

    ; ── 3. Habilitar INT0 en INTCON ──
    ; GIE=1 + INTE=1 + T0IE=1 (+ PEIE=1 que pide HU-06)
    ; Ver CONTRATO.md: valor final 0xD0.
    BANKSEL INTCON
    MOVLW   0xD0
    MOVWF   INTCON

    ; ── 4. Estado inicial seguro ──
    ; Asumimos que HU-02 ya dejó motor OFF. Si este esqueleto corre
    ; standalone, forzar el estado seguro acá:
    BCF     STATUS, RP0       ; Bank 0
    BCF     STATUS, RP1
    ; BSF     PORTD, 1         ; LED rojo ON
    ; BCF     PORTD, 0         ; LED verde OFF
    ; CLRF    CCPR1L           ; PWM 0% (motor OFF)
    ; BSF     FLAGS, 1         ; FLAG_EMERGENCY = 1 (arranca seguro)

    ; ── 5. Loop principal ──
LOOP:
    GOTO    LOOP              ; en el integrado se chequea FLAG_TX (HU-05)


; =================================================================
; ISR_DISPATCHER — orden de prioridad lógica:
;   1) INT0  (emergencia)
;   2) (acá iría RCIF cuando se integre HU-06)
;   3) T0IF  (flujo normal)
; =================================================================
ISR_DISPATCHER:
    ; Guardar contexto
    MOVWF   W_TEMP
    SWAPF   STATUS, W
    MOVWF   STATUS_TEMP

    ; Recargar T0 y limpiar flag (el T0 también puede haber disparado)
    MOVLW   .100
    MOVWF   TMR0
    BCF     INTCON, T0IF

    ; ── 1. Chequear INT0 (alta prioridad lógica) ──
    BTFSS   INTCON, INT0IF
    GOTO    ISR_NORMAL        ; no hay emergencia → flujo normal
    CALL    ISR_EMERGENCIA
    GOTO    RECUPERAR_CONTEXTO

ISR_NORMAL:
    ; (En el integrado: acá se mete el chequeo de RCIF y luego el
    ;  flujo de Timer0 que ya tienen HU-01/02/03.)
    ; Por ahora, solo return.
    GOTO    RECUPERAR_CONTEXTO


; =================================================================
; ISR_EMERGENCIA — se ejecuta con GIE=0 implícito (no seベafecta
;                  por INTE porque ya está dentro de la ISR).
;                  Limpia el flag, corta el motor, enciende LED rojo
;                  y setea FLAG_EMERGENCY.
; =================================================================
ISR_EMERGENCIA:
    ; 1. Limpiar flag de INT0
    BCF     INTCON, INT0IF

    ; 2. Cortar el motor (PWM 0%)
    BANKSEL CCPR1L
    CLRF    CCPR1L            ; duty 0% → motor OFF

    ; 3. LEDs: rojo ON, verde OFF
    BCF     STATUS, RP0       ; asegurar Bank 0
    BCF     STATUS, RP1
    BCF     PORTD, 0          ; verde OFF
    BSF     PORTD, 1          ; rojo ON

    ; 4. Marcar flag (dueño: HU-04 al setear, HU-06 al limpiar)
    BSF     FLAGS, 1          ; FLAG_EMERGENCY = 1

    ; 5. (Opcional) forzar envío inmediato de trama UART para que la
    ;    PC se entere de la emergencia. Lo decide la integración.
    ;    BSF     FLAGS, 0      ; FLAG_TX = 1

    RETURN


; =================================================================
; RECUPERAR_CONTEXTO
; =================================================================
RECUPERAR_CONTEXTO:
    SWAPF   STATUS_TEMP, W
    MOVWF   STATUS
    SWAPF   W_TEMP, F
    SWAPF   W_TEMP, W
    RETFIE


; =================================================================
; BLOQUE DE TEST — para probar este esqueleto standalone en MPLABX
; Simulator. Comentar/eliminar al integrar en tpFinal.asm.
; =================================================================
; Para activar:
;   1. Cargar HU04-EMERGENCIA.asm standalone en MPLABX
;   2. Poner stim en RB0 (pin stimulus, flanco descendente)
;   3. Simular → verificar:
;       - CCPR1L = 0x00
;       - PORTD bit 1 = 1 (rojo ON), bit 0 = 0 (verde OFF)
;       - FLAGS bit 1 = 1
;   4. Simular otro flanco descendente (sin limpiar nada):
;       - El estado debe permanecer (es latch, no toggle)
;   5. Para "liberar" en el test, escribir manualmente:
;       - BCF FLAGS, 1
;       - BSF PORTD, 0 / BCF PORTD, 1
;       - MOVLW 0xFF / MOVWF CCPR1L
;      (En producción esto lo hace HU-06 con 'R')

    END
