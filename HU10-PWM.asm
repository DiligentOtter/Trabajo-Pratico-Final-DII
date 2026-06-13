;---------------------------------------------------------------------
; HU-10 - Control PWM del motor
; Proposito: Configurar CCP1 en modo PWM con Timer2 para controlar
;            el motor DC via RC2. Proporciona subrutinas PWM_ON y
;            PWM_OFF que setean CCPR1L a 0xFF o 0x00.
;            La configuracion se hace una vez en MAIN.
; Referencia: Requirements.md Anexo F - T2CON, PR2, CCP1CON, CCPR1L.
; Integracion: al pegar en tpFinal.asm, borrar este __CONFIG y
;              CBLOCK. Llamar a PWM_INIT en MAIN (despues de
;              configurar TRISC) y usar PWM_ON / PWM_OFF desde
;              COMPARAR_Y_ACTUAR (HU-02) e ISR_EMERGENCIA (HU-04).
; ------------------------------------------------------------------
    LIST p=16F887
    #INCLUDE "P16F887.inc"
    RADIX HEX

    __CONFIG _CONFIG1, _FOSC_HS & _WDTE_OFF & _PWRTE_ON & _MCLRE_ON & _LVP_OFF
    __CONFIG _CONFIG2, _BOR4V_BOR40V & _WRT_OFF

; --- Variables (CONTRATO) ---
    CBLOCK 0x20
        DIST_CM         ; 0x20
        UMBRAL_CM       ; 0x21
        UMBRAL_DEC      ; 0x22
        UMBRAL_UNI      ; 0x23
        DISP_SEL        ; 0x24
        CICLO_CNT       ; 0x25
        FLAGS           ; 0x26
        TEMP            ; 0x27
        W_TEMP          ; 0x28
        STATUS_TEMP     ; 0x29
    ENDC

; --- Vector Reset ---
    ORG     0
    GOTO    MAIN

; --- Vector ISR ---
    ORG     4
    GOTO    ISR_DISPATCHER


; =================================================================
; MAIN - configura PWM y loop
; =================================================================
MAIN
    ; --- COMPLETAR: llamar a PWM_INIT para configurar modulo CCP1 ---

LOOP
    GOTO    LOOP


; =================================================================
; ISR_DISPATCHER - placeholder
; =================================================================
ISR_DISPATCHER
    MOVWF   W_TEMP
    SWAPF   STATUS, W
    MOVWF   STATUS_TEMP

    GOTO    RECUPERAR_CONTEXTO


; =================================================================
; PWM_INIT - configura CCP1 en modo PWM con Timer2.
;
; Registros a configurar:
;   - TRISC, bit 2 = 0  (RC2 como salida, antes de habilitar CCP1)
;   - T2CON = 0x04      (Timer2 ON, prescaler 1:1)
;   - PR2   = 0xFF      (periodo maximo, ~3.9 kHz a 4 MHz)
;   - CCP1CON = 0x0C    (modo PWM)
;   - CCPR1L = 0x00     (duty 0% - motor OFF por defecto)
; =================================================================
PWM_INIT
    ; --- COMPLETAR: configurar TRISC2 como salida ---
    ; --- COMPLETAR: T2CON = 0x04 ---
    ; --- COMPLETAR: PR2 = 0xFF ---
    ; --- COMPLETAR: CCP1CON = 0x0C ---
    ; --- COMPLETAR: CCPR1L = 0x00 (motor OFF) ---
    RETURN


; =================================================================
; PWM_ON - enciende el motor al 100% duty.
;   CCPR1L = 0xFF
; =================================================================
PWM_ON
    ; --- COMPLETAR: CCPR1L = 0xFF ---
    RETURN


; =================================================================
; PWM_OFF - apaga el motor (0% duty).
;   CCPR1L = 0x00
; =================================================================
PWM_OFF
    ; --- COMPLETAR: CCPR1L = 0x00 ---
    RETURN


; =================================================================
; RECUPERAR_CONTEXTO
; =================================================================
RECUPERAR_CONTEXTO
    SWAPF   STATUS_TEMP, W
    MOVWF   STATUS
    SWAPF   W_TEMP, F
    SWAPF   W_TEMP, W
    RETFIE


; =================================================================
; BLOQUE DE TEST - para probar este esqueleto standalone en MPLABX.
;
; 1. Cargar HU10-PWM.asm standalone
; 2. Ejecutar, verificar en SFR:
;      - T2CON = 0x04
;      - PR2 = 0xFF
;      - CCP1CON = 0x0C
;      - CCPR1L = 0x00 (inicial)
; 3. Llamar a PWM_ON -> CCPR1L = 0xFF
; 4. Llamar a PWM_OFF -> CCPR1L = 0x00
; 5. Verificar RC2 como salida (TRISC bit 2 = 0)
;
; Para integracion en tpFinal.asm:
;   - Borrar __CONFIG y CBLOCK
;   - Llamar a PWM_INIT en MAIN (despues de configurar TRISC)
;   - Usar PWM_ON / PWM_OFF desde COMPARAR_Y_ACTUAR e ISR_EMERGENCIA
; =================================================================

    END
