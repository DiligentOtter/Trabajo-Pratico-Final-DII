 LIST p=16F887
    #INCLUDE "P16F887.inc"
    RADIX HEX

    __CONFIG _CONFIG1, _FOSC_HS & _WDTE_OFF & _PWRTE_ON & _MCLRE_ON & _LVP_OFF
    __CONFIG _CONFIG2, _BOR4V_BOR40V & _WRT_OFF

    ; --- Mapa de RAM segun CONTRATO.md ---
    ; HU-03 es dueno de UMBRAL_*, DISP_SEL.
    ; Las demas se declaran solo para que el archivo sea autocontenido
    ; en simulacion standalone; al integrar se centraliza en un unico
    ; archivo de variables.
    CBLOCK 0x20
        DIST_CM         ; 0x20  - HU-01 escribe, HU-02 lee
        UMBRAL_CM       ; 0x21  - HU-03 escribe, HU-02 lee
        UMBRAL_DEC      ; 0x22  - HU-03 - decena del umbral
        UMBRAL_UNI      ; 0x23  - HU-03 - unidad del umbral
        DISP_SEL        ; 0x24  - HU-03 - selector display (bit0)
        CICLO_CNT       ; 0x25  - HU-01 - contador ciclos Timer0
        FLAGS           ; 0x26  - compartido
        TEMP            ; 0x27  - HU-03 - auxiliar para division
        ADC_RES         ; 0x28  - HU-03 - raw ADC (justificado derecha)
    ENDC

    ; --- Backup de contexto para ISR (zona alta, sin colision) ---
    CBLOCK 0x7D
        W_TEMP
        STATUS_TEMP
    ENDC

    ;Vector Reset 
    ORG     0
    GOTO    MAIN

    ;Vector ISR
    ORG     4
    GOTO    ISR_TIMER0
    
MAIN
    
    ;Conf. puertos
    BSF STATUS,RP0      ;BANCO 1
    BCF STATUS,RP1
    
    MOVLW b'00000001'
    MOVWF TRISA
    
    CLRF TRISD
    
    BCF TRISE,0
    BCF TRISE,1
    
    ;Conf. ADC
    BSF STATUS,RP0         ;BANCO 3
    BSF STATUS,RP1
    
    MOVLW b'00000001'
    MOVWF ANSEL
    
    CLRF ANSELH
    
    BSF STATUS,RP0            ;BANCO 1
    BCF STATUS,RP1
    
    MOVLW 0x80        ; ADFM=1: justificado a derecha, Vref=VDD
    MOVWF ADCON1
    
    BCF STATUS,RP0         ;BANCO 0
    BCF STATUS,RP1
    
    MOVLW 0x41        ; ADCS=01 (Tad=2us), CHS=000 (AN0), ADON=1
    MOVWF ADCON0
    
    ;Conf. option_reg
    BSF STATUS,RP0      ;BANCO 1
    BCF STATUS,RP1
    
    MOVLW b'00000101'
    MOVWF OPTION_REG
    
    ;Conf. timer
    BCF STATUS,RP0       ;BANCO 0
    BCF STATUS,RP1
    
    MOVLW .100
    MOVWF TMR0
    
    ;Inicializaci�n de displays apagados y variables
    CLRF PORTE
    CLRF PORTD
    CLRF CICLO_CNT
    CLRF TEMP
    CLRF UMBRAL_CM
    CLRF UMBRAL_DEC
    CLRF UMBRAL_UNI
    CLRF DISP_SEL
    CLRF ADC_RES
 
    ;Habilitaci�n de interrupciones
    MOVLW b'10110000'
    MOVWF INTCON
    
LOOP
    GOTO LOOP
 
ISR_TIMER0
    ;Guardado de contexto
    MOVWF W_TEMP
    SWAPF STATUS,W
    MOVWF STATUS_TEMP
    
    BANKSEL TMR0
    MOVLW .100
    MOVWF TMR0
    
    BCF INTCON,T0IF 
    
    INCF CICLO_CNT,F

    MOVLW .10
    SUBWF CICLO_CNT,W
    
    BTFSS STATUS,Z
    GOTO NO_ADC
    CLRF CICLO_CNT
    
    ;Inicializaci�n de la conversi�n
    BSF ADCON0,GO

ESPERA_ADC
    BTFSC ADCON0,GO
    GOTO ESPERA_ADC

    ;Lectura del resultado (ADCON1=0x80: justificado a derecha, 8 bits utiles en ADRESL)
    MOVF ADRESL,W
    MOVWF ADC_RES
    
    ;UMBRAL_CM = 5 + (ADC_RES/13)
    MOVF ADC_RES,W
    MOVWF TEMP
    MOVLW .5
    MOVWF UMBRAL_CM
    
DIV13
    MOVLW .13
    SUBWF TEMP,F

    BTFSS STATUS,C
    GOTO FIN_DIV13

    INCF UMBRAL_CM,F
    GOTO DIV13

FIN_DIV13
    
    ;Conversi�n a BCD
    CLRF UMBRAL_DEC

    MOVF UMBRAL_CM,W
    MOVWF UMBRAL_UNI
    BCD_LOOP
    MOVLW .10
    SUBWF UMBRAL_UNI,F

    BTFSS STATUS,C
    GOTO BCD_FIN

    INCF UMBRAL_DEC,F
    GOTO BCD_LOOP

BCD_FIN
    MOVLW .10
    ADDWF UMBRAL_UNI,F

NO_ADC
    CALL RUTINA_DISPLAY

    ;Restaurar contexto
    SWAPF STATUS_TEMP,W
    MOVWF STATUS
    SWAPF W_TEMP,F
    SWAPF W_TEMP,W
    
    RETFIE
    
RUTINA_DISPLAY
    BCF PORTE,0
    BCF PORTE,1
    
    BTFSS DISP_SEL,0
    GOTO SHOW_DECENAS
    GOTO SHOW_UNIDADES
    
SHOW_UNIDADES
    MOVF UMBRAL_UNI, W
    CALL BCD_7SEG
    MOVWF PORTD
    BSF PORTE,1
    
    BCF DISP_SEL,0     
    RETURN
    
SHOW_DECENAS
    MOVF UMBRAL_DEC,W
    CALL BCD_7SEG
    MOVWF PORTD
    BSF PORTE,0
    
    BSF DISP_SEL,0     
    RETURN
    
BCD_7SEG
    ADDWF PCL,F
    RETLW  b'00111111'    ; 0
    RETLW  b'00000110'    ; 1
    RETLW  b'01011011'    ; 2
    RETLW  b'01001111'    ; 3
    RETLW  b'01100110'    ; 4
    RETLW  b'01101101'    ; 5
    RETLW  b'01111101'    ; 6
    RETLW  b'00000111'    ; 7
    RETLW  b'01111111'    ; 8
    RETLW  b'01101111'    ; 9

    END