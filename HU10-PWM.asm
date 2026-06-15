
    LIST p=16F887
    #INCLUDE "P16F887.inc"
    RADIX HEX

    __CONFIG _CONFIG1, _FOSC_HS & _WDTE_OFF & _PWRTE_ON & _MCLRE_ON & _LVP_OFF
    __CONFIG _CONFIG2, _BOR4V_BOR40V & _WRT_OFF

    CBLOCK 0x20
        DIST_CM         ;0x20
        UMBRAL_CM       ;0x21
        UMBRAL_DEC      ;0x22
        UMBRAL_UNI      ;0x23
        DISP_SEL        ;0x24
        CICLO_CNT       ;0x25
        FLAGS           ;0x26
        TEMP            ;0x27
        W_TEMP          ;0x28
        STATUS_TEMP     ;0x29
    ENDC

    ORG 0
    GOTO MAIN

    ORG 4
    GOTO ISR_DISPATCHER

MAIN
    CALL PWM_INIT
    ;CALL PWM_ON ,la llame para probarla
    ;CALL PWM_OFF ,la llame para probarla

LOOP
    GOTO LOOP

ISR_DISPATCHER
    MOVWF W_TEMP
    SWAPF STATUS,W
    MOVWF STATUS_TEMP

    GOTO RECUPERAR_CONTEXTO

PWM_INIT
    BANKSEL TRISC
    BCF TRISC,2
    
    BANKSEL T2CON
    MOVLW b'00000100'
    MOVWF T2CON
    
    BANKSEL PR2
    MOVLW b'11111111'
    MOVWF PR2
    
    BANKSEL CCP1CON
    MOVLW b'00001100'
    MOVWF CCP1CON
    
    BANKSEL CCPR1L
    CLRF CCPR1L
  
    RETURN

PWM_ON
    ;PWM_ON(enciende el motor al 100% duty)
    MOVLW b'11111111'
    MOVWF CCPR1L    
    RETURN

    ;PWM_OFF(apaga el motor al 0% duty)
PWM_OFF
    CLRF CCPR1L
    RETURN

RECUPERAR_CONTEXTO
    SWAPF STATUS_TEMP,W
    MOVWF STATUS
    SWAPF W_TEMP,F
    SWAPF W_TEMP,W
    RETFIE

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

    END
