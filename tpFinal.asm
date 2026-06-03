    LIST p=16F887
    #INCLUDE "P16F887.inc"
    RADIX HEX

    __CONFIG _CONFIG1, _FOSC_HS & _WDTE_OFF & _PWRTE_ON & _MCLRE_ON & _CP_OFF & _CPD_OFF & _BOREN_ON & _IESO_OFF & _FCMEN_OFF & _LVP_OFF
    __CONFIG _CONFIG2, _BOR4V_BOR40V & _WRT_OFF

; Al integrar cada HU0X-*.asm: borrar su __CONFIG y su CBLOCK
; (queda solo el de tpFinal).

; === Variables (CONTRATO + privadas) ===
    CBLOCK 0x20
        DIST_CM         ; 0x20
        UMBRAL_CM       ; 0x21
        UMBRAL_DEC      ; 0x22
        UMBRAL_UNI      ; 0x23
        DISP_SEL        ; 0x24
        CICLO_CNT       ; 0x25
        FLAGS           ; 0x26
        TEMP            ; 0x27
        ADC_RES         ; 0x28
        TMR1_H          ; 0x29
        TMR1_L          ; 0x2A
        CONT_DELAY      ; 0x2B
    ENDC
    CBLOCK 0x7D
        W_TEMP
        STATUS_TEMP
    ENDC

    ORG 0
    GOTO MAIN
    ORG 4
    GOTO ISR_TIMER0

; === MAIN ===
MAIN:
    ; <<< puertos y perifericos de HU-01, HU-02, HU-03 >>>
    ; OPTION_REG=0x05, TMR0=100, INTCON=0xB0
    CLRF DIST_CM
    CLRF UMBRAL_CM
    CLRF CICLO_CNT
    CLRF FLAGS
    CLRF PORTE
    CLRF PORTD
LOOP:
    GOTO LOOP

; === ISR Timer0 (unica) ===
ISR_TIMER0:
    MOVWF W_TEMP
    SWAPF STATUS,W
    MOVWF STATUS_TEMP
    BANKSEL TMR0
    MOVLW .100
    MOVWF TMR0
    BCF INTCON,T0IF

    ; <<< RUTINA_DISPLAY (HU-03) - siempre >>>

    INCF CICLO_CNT,F
    MOVLW .10
    SUBWF CICLO_CNT,W
    BTFSS STATUS,Z
    GOTO FIN_ISR
    CLRF CICLO_CNT
    ; <<< cada 100ms: LEER_ADC, MEDIR_HCSR04, COMPARAR_Y_ACTUAR >>>

FIN_ISR:
    SWAPF STATUS_TEMP,W
    MOVWF STATUS
    SWAPF W_TEMP,F
    SWAPF W_TEMP,W
    RETFIE

; === Subrutinas (pegar desde HU0X-*.asm) ===
;MEDIR_HCSR04:        ; HU-01
;RUTINA_DISPLAY:      ; HU-03
;LEER_ADC:            ; HU-03
;COMPARAR_Y_ACTUAR:   ; HU-02
;BCD_7SEG:            ; HU-03

    END
