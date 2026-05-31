; ──────────────────────────────────────────────────────────────
; HU-01 — Medición de distancia con HC-SR04
; Propósito: Enviar pulso TRIG, medir ancho ECHO con Timer1,
;            calcular distancia en cm.
; Responsable: Juan
; ──────────────────────────────────────────────────────────────
    LIST p=16F887
    #INCLUDE "P16F887.inc"
    RADIX HEX

    __CONFIG _CONFIG1, _FOSC_HS & _WDTE_OFF & _PWRTE_ON & _MCLRE_ON & _LVP_OFF
    __CONFIG _CONFIG2, _BOR4V_BOR40V & _WRT_OFF

; ─── Variables ───
    CBLOCK 0x20
        DIST_CM         ; 1 byte  — distancia calculada en cm
        CICLO_CNT       ; 1 byte  — contador para temporizar 100ms
        TMR1_H          ; 1 byte  — valor alto Timer1 (para depuración)
        TMR1_L          ; 1 byte  — valor bajo Timer1
    ENDC

; ─── Vector Reset ───
    ORG     0
    GOTO    MAIN

; ─── Vector ISR ───
    ORG     4
    GOTO    ISR_TIMER0

; =================================================================
; MAIN
; =================================================================
MAIN:
    ; 1. Configurar puertos
    ;    - TRISC: RC0 como salida (TRIG), RC1 como entrada (ECHO)
    ;    - Inicializar RC0 = 0, RC1 como entrada
    ; TODO

    ; 2. Configurar Timer0 para ~10ms
    ;    - OPTION_REG = 0x04 (prescaler 1:32)
    ;    - TMR0 = 6 (para ~10ms)
    ; TODO

    ; 3. Configurar Timer1 para medir ECHO
    ;    - T1CON = 0x01 (Timer1 ON, prescaler 1:1, osc deshabilitado)
    ;    - 1 tick = 1 µs a 4 MHz
    ; TODO

    ; 4. Inicializar variables
    CLRF    DIST_CM
    CLRF    CICLO_CNT
    CLRF    TMR1_H
    CLRF    TMR1_L

    ; 5. Habilitar interrupciones Timer0
    ;    - INTCON = 0xB0 (GIE=1, TMR0IE=1)
    BANKSEL INTCON
    MOVLW   0xB0
    MOVWF   INTCON

; ─── LOOP principal ───
LOOP:
    ; Cada 100ms se ejecuta la medición desde ISR.
    ; Acá podrías poner un LED indicador o depuración.
    GOTO    LOOP


; =================================================================
; ISR Timer0 (~10ms)
; =================================================================
ISR_TIMER0:
    ; Guardar contexto (W y STATUS)
    ; TODO

    ; Relanzar Timer0
    BANKSEL TMR0
    MOVLW   6
    MOVWF   TMR0
    BCF     INTCON, TMR0IF

    ; Incrementar contador de ciclos
    BANKSEL CICLO_CNT
    INCF    CICLO_CNT, F
    MOVLW   .10
    SUBWF   CICLO_CNT, W
    BTFSS   STATUS, Z
    GOTO    ISR_END

    ; ── Cada 10 ciclos (~100ms): medir distancia ──
    CLRF    CICLO_CNT
    CALL    MEDIR_HCSR04

ISR_END:
    ; Restaurar contexto
    ; TODO
    RETFIE


; =================================================================
; MEDIR_HCSR04 — pulso TRIG + medición ECHO con Timer1
; =================================================================
MEDIR_HCSR04:
    ; --- PASO 1: Enviar pulso TRIG de 10µs ---
    ; BSF PORTC, RC0
    ; Esperar ~10µs (NOPs o loop corto)
    ; BCF PORTC, RC0
    ; TODO

    ; --- PASO 2: Esperar que ECHO suba (con timeout) ---
    ; Polling de RC1, esperando que pase a 1
    ; Si pasa demasiado tiempo (~1ms), abortar
    ; TODO

    ; --- PASO 3: Iniciar Timer1 y medir ancho del pulso ---
    ; Cuando ECHO = 1:
    ;   TMR1H = 0, TMR1L = 0 (resetear Timer1)
    ;   Timer1 ya está ON (configurado en init)
    ;
    ; Polling hasta que ECHO = 0 o TMR1IF = 1 (timeout ~25ms)
    ; TODO

    ; --- PASO 4: Calcular distancia ---
    ; Cuando ECHO baja (o timeout):
    ;   Leer TMR1H:TMR1L
    ;   TMR1_H = TMR1H, TMR1_L = TMR1L (guardar)
    ;   distancia_cm = ticks / 58
    ;
    ; Para dividir entre 58 sin usar división:
    ;   Podés usar resta sucesiva o tabla lookup
    ;   Alternativa: distancia_cm ≈ ticks / 58
    ;   Como 1/58 ≈ 0.0172, podés hacer (ticks * 9) / 512 ≈ ticks/57
    ;   O más simple: distancia_cm = ticks / 58 con resta sucesiva
    ;
    ; Si timeout (TMR1IF): DIST_CM = 0xFF (error/desconectado)
    ; TODO

    RETURN


    END
