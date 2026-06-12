;---------------------------------------------------------------------
; HU-08 - Display del umbral de corte (conversion a BCD)
; Proposito: Subrutina CONVERTIR_UMBRAL_A_BCD que toma UMBRAL_CM
;            (0-25) y lo descompone en UMBRAL_DEC (decenas) y
;            UMBRAL_UNI (unidades) para que HU-09 las muestre.
;            Se llama cada 100 ms desde el ciclo de la ISR.
; Integracion: al pegar en tpFinal.asm, borrar este __CONFIG y CBLOCK.
;              Llamar a CONVERTIR_UMBRAL_A_BCD cada 100 ms (cuando
;              se actualiza UMBRAL_CM desde LEER_ADC).
; ------------------------------------------------------------------
    LIST p=16F887
    #INCLUDE "P16F887.inc"
    RADIX HEX

    __CONFIG _CONFIG1, _FOSC_HS & _WDTE_OFF & _PWRTE_ON & _MCLRE_ON & _LVP_OFF
    __CONFIG _CONFIG2, _BOR4V_BOR40V & _WRT_OFF

; --- Variables (CONTRATO) ---
    CBLOCK 0x20
        DIST_CM         ; 0x20
        UMBRAL_CM       ; 0x21  - lee (valor a convertir)
        UMBRAL_DEC      ; 0x22  - escribe (decenas)
        UMBRAL_UNI      ; 0x23  - escribe (unidades)
        DISP_SEL        ; 0x24
        CICLO_CNT       ; 0x25
        FLAGS           ; 0x26
        TEMP            ; 0x27  - scratch para conversion
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
; MAIN - inicializa valores de prueba y loop
; =================================================================
MAIN
    ; --- COMPLETAR (opcional): inicializar UMBRAL_DEC y UMBRAL_UNI ---

LOOP
    ; --- COMPLETAR: llamar a CONVERTIR_UMBRAL_A_BCD ---
    GOTO    LOOP


; =================================================================
; ISR_DISPATCHER - placeholder. En integrado se llama cada 100 ms
;                  (despues de LEER_ADC y actualizar UMBRAL_CM).
; =================================================================
ISR_DISPATCHER
    MOVWF   W_TEMP
    SWAPF   STATUS, W
    MOVWF   STATUS_TEMP

    ; --- COMPLETAR: llamar a CONVERTIR_UMBRAL_A_BCD ---

    GOTO    RECUPERAR_CONTEXTO


; =================================================================
; CONVERTIR_UMBRAL_A_BCD - descompone UMBRAL_CM en decenas y
;                          unidades mediante resta sucesiva de 10.
;
; Lee:    UMBRAL_CM
; Escribe: UMBRAL_DEC, UMBRAL_UNI
; Usa:    TEMP como scratch
; =================================================================
CONVERTIR_UMBRAL_A_BCD
    ; --- COMPLETAR: copiar UMBRAL_CM a TEMP ---
    ; --- COMPLETAR: restar 10 repetidamente, contar decenas en UMBRAL_DEC ---
    ; --- COMPLETAR: el resto queda como UMBRAL_UNI ---
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
; BCD_7SEG - tabla lookup para display 7 segmentos.
; Se incluye aca como placeholder. En integrado vive una sola vez
; en tpFinal.asm (o en HU-09).
; =================================================================
BCD_7SEG
    ; --- COMPLETAR: tabla lookup digito 0-9 a patron gfedcba ---
    ; --- (ver Anexo E de Requirements.md) ---
    RETURN


; =================================================================
; BLOQUE DE TEST - para probar este esqueleto standalone en MPLABX.
;
; 1. Cargar HU08-DISPLAY-UMBRAL.asm standalone
; 2. Poner valor de prueba en UMBRAL_CM
; 3. Llamar a CONVERTIR_UMBRAL_A_BCD
; 4. Verificar UMBRAL_DEC y UMBRAL_UNI
; 5. Probar varios valores: 0, 7, 15, 25
;
; Para integracion en tpFinal.asm:
;   - Borrar __CONFIG y CBLOCK
;   - Llamar a CONVERTIR_UMBRAL_A_BCD cada 100 ms (despues de
;     actualizar UMBRAL_CM desde LEER_ADC)
; =================================================================

    END
