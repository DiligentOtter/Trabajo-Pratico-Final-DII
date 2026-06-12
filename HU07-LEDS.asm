;---------------------------------------------------------------------
; HU-07 - Indicacion visual de estado (LEDs RD0 y RD1)
; Proposito: Subrutina ACTUALIZAR_LEDS que refleja el estado del motor
;            en los LEDs: verde (RD0) = motor ON, rojo (RD1) = motor OFF.
;            Son mutuamente excluyentes.
; Integracion: al pegar en tpFinal.asm, borrar este __CONFIG y CBLOCK.
;              Llamar a ACTUALIZAR_LEDS desde COMPARAR_Y_ACTUAR (HU-02)
;              y desde ISR_EMERGENCIA (HU-04) cada vez que cambie el estado.
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
        FLAGS           ; 0x26  - bit 2 = FLAG_MOTOR
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
; MAIN - configura puertos y loop principal
; =================================================================
MAIN
    ; --- COMPLETAR: configurar RD0 y RD1 como salidas ---
    ; --- COMPLETAR: estado inicial LEDs (ej: rojo ON) ---

LOOP
    ; --- COMPLETAR: llamar a ACTUALIZAR_LEDS en cada ciclo ---
    GOTO    LOOP


; =================================================================
; ISR_DISPATCHER - placeholder. En integrado se reemplaza por el
;                  dispatcher real.
; =================================================================
ISR_DISPATCHER
    MOVWF   W_TEMP
    SWAPF   STATUS, W
    MOVWF   STATUS_TEMP

    ; --- COMPLETAR: llamar a ACTUALIZAR_LEDS si cambio el estado ---

    GOTO    RECUPERAR_CONTEXTO


; =================================================================
; ACTUALIZAR_LEDS - pone RD0/RD1 segun FLAG_MOTOR (FLAGS bit 2).
;
; Lee:    FLAGS (bit 2)
; Escribe: PORTD bits 0 y 1
; Uso:    llamar desde COMPARAR_Y_ACTUAR y desde ISR_EMERGENCIA
;         cada vez que cambie el estado del motor.
; =================================================================
ACTUALIZAR_LEDS
    ; --- COMPLETAR: si FLAGS bit 2 = 1 (motor ON) ---
    ;       -> RD0 = 1 (verde ON), RD1 = 0 (rojo OFF)
    ; --- COMPLETAR: si FLAGS bit 2 = 0 (motor OFF) ---
    ;       -> RD0 = 0 (verde OFF), RD1 = 1 (rojo ON)
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
; 1. Cargar HU07-LEDS.asm standalone
; 2. Configurar RD0 y RD1 como salidas, inicializar LEDs
; 3. Asignar valor de prueba a FLAGS bit 2
; 4. Llamar a ACTUALIZAR_LEDS y verificar PORTD bits 0 y 1
; 5. Cambiar FLAGS bit 2 y verificar que los LEDs se actualizan
; 6. Verificar que nunca quedan ambos LEDs encendidos
;
; Para integracion en tpFinal.asm:
;   - Borrar __CONFIG y CBLOCK
;   - Agregar CALL ACTUALIZAR_LEDS en COMPARAR_Y_ACTUAR (despues de
;     decidir motor ON/OFF) y en ISR_EMERGENCIA (despues de cortar)
; =================================================================

    END
