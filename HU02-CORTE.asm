; ──────────────────────────────────────────────────────────────
; HU-02 — Corte automático del motor
; Propósito: Comparar distancia vs umbral, setear PWM ON/OFF.
; Responsable: Amy
; ──────────────────────────────────────────────────────────────
    LIST p=16F887
    #INCLUDE "P16F887.inc"
    RADIX HEX

    __CONFIG _CONFIG1, _FOSC_HS & _WDTE_OFF & _PWRTE_ON & _MCLRE_ON & _LVP_OFF
    __CONFIG _CONFIG2, _BOR4V_BOR40V & _WRT_OFF

; ─── Variables (compartidas con HU-01 y HU-03) ───
    CBLOCK 0x20
        DIST_CM         ; 1 byte  — lo escribe HU-01
        UMBRAL_CM       ; 1 byte  — lo escribe HU-03
        FLAGS           ; 1 byte  — bit2 = FLAG_MOTOR
    ENDC

; ─── Vector Reset ───
    ORG     0
    GOTO    MAIN

; ─── Vector ISR ───
    ORG     4
    GOTO    ISR_CORTE

; =================================================================
; MAIN
; =================================================================
MAIN:
    ; 1. Configurar puertos
    ;    - TRISC: RC2 como salida (CCP1/PWM)
    ;    - TRISD: RD0, RD1 como salidas (LEDs)
    ;    - LEDs apagados al inicio
    ; TODO

    ; 2. Configurar PWM con CCP1
    ;    Timer2 como base:
    ;      - T2CON = 0x04 (Timer2 ON, prescaler 1:1)
    ;      - PR2 = 0xFF (periodo máximo)
    ;    CCP1 en modo PWM:
    ;      - CCP1CON = 0x0C
    ;      - CCPR1L = 0x00 (duty 0%, motor OFF)
    ;    PR2 ya requiere BANKSEL
    ; TODO

    ; 3. Inicializar variables y LEDs
    ;    - LED rojo ON (RD1), LED verde OFF (RD0)
    ;    - FLAGS = 0 (todo apagado/seguro)
    ; TODO

; ─── LOOP principal ───
LOOP:
    ; ============================================================
    ; PARA PRUEBA STANDALONE sin esperar HU-01/HU-03:
    ; Descomentar las líneas de TEST y comentar las reales.
    ; ============================================================

    ; --- MODO TEST: valores hardcodeados ---
    ; Descomentar para probar el PWM sin depender de otros módulos:
    ;
    ;   MOVLW   .10          ; prueba: DIST_CM = 10 cm
    ;   MOVWF   DIST_CM
    ;   MOVLW   .15          ; prueba: UMBRAL_CM = 15 cm
    ;   MOVWF   UMBRAL_CM
    ;   CALL    COMPARAR_Y_ACTUAR
    ;
    ;   MOVLW   .20          ; prueba: DIST_CM = 20 cm (> umbral)
    ;   MOVWF   DIST_CM
    ;   CALL    COMPARAR_Y_ACTUAR
    ;
    ;   CALL    DELAY_LARGO  ; delay para ver LEDs
    ;   GOTO    LOOP

    ; --- MODO INTEGRADO (cuando HU-01 y HU-03 estén listos) ---
    ;   CALL    COMPARAR_Y_ACTUAR
    ;   GOTO    LOOP

    GOTO    LOOP


; =================================================================
; COMPARAR_Y_ACTUAR — decisión central del sistema
; Lee DIST_CM y UMBRAL_CM, setea PWM y LEDs.
; =================================================================
COMPARAR_Y_ACTUAR:
    ; 1. Comparar DIST_CM con UMBRAL_CM
    ;    MOVF    UMBRAL_CM, W
    ;    SUBWF   DIST_CM, W      ; W = DIST_CM - UMBRAL_CM
    ;    BTFSS   STATUS, C       ; ¿C=1 → DIST_CM >= UMBRAL_CM?
    ;    GOTO    MOTOR_OFF       ; No → distancia < umbral, cortar
    ;
    ; MOTOR_ON:
    ;    ; Verificar que no haya emergencia primero
    ;    BTFSC   FLAGS, 1        ; FLAG_EMERGENCY?
    ;    GOTO    MOTOR_OFF       ; sí → no arrancar
    ;
    ;    CCPR1L = 0xFF (100% duty)
    ;    LED verde ON, LED rojo OFF
    ;    FLAGS bit2 = 1 (FLAG_MOTOR)
    ;    RETURN
    ;
    ; MOTOR_OFF:
    ;    CCPR1L = 0x00 (0% duty)
    ;    LED verde OFF, LED rojo ON
    ;    FLAGS bit2 = 0
    ;    RETURN
    ; TODO

    RETURN


; =================================================================
; PWM_ON / PWM_OFF — macros para control del motor
; =================================================================
PWM_ON   MACRO
    BANKSEL CCPR1L
    MOVLW   0xFF
    MOVWF   CCPR1L
    ENDM

PWM_OFF  MACRO
    BANKSEL CCPR1L
    MOVLW   0x00
    MOVWF   CCPR1L
    ENDM


; =================================================================
; ISR placeholder — para integración futura
; =================================================================
ISR_CORTE:
    ; En el integrado final, acá se llamará COMPARAR_Y_ACTUAR
    ; desde la ISR del Timer0. Por ahora, solo retornar.
    RETFIE


; =================================================================
; DELAY_LARGO — delay para pruebas (aprox 0.5s a 4MHz)
; =================================================================
DELAY_LARGO:
    ; Triple loop anidado para delay visible
    ; TODO: implementar si hace falta para pruebas standalone
    RETURN


    END
