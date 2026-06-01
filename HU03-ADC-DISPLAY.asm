 LIST p=16F887
    #INCLUDE "P16F887.inc"
    RADIX HEX

    __CONFIG _CONFIG1, _FOSC_HS & _WDTE_OFF & _PWRTE_ON & _MCLRE_ON & _LVP_OFF
    __CONFIG _CONFIG2, _BOR4V_BOR40V & _WRT_OFF

    ;Variables 
    CBLOCK 0x20
        W_TEMP
        STATUS_TEMP
        CICLO_CNT
	TEMP
        UMBRAL_CM       ; 1 byte  ? resultado ADC mapeado a cm
        UMBRAL_DEC      ; 1 byte  ? dígito decenas
        UMBRAL_UNI      ; 1 byte  ? dígito unidades
        DISP_SEL        ; 1 byte  ? flag selector (bit0: 0=dec, 1=uni)
        ADC_RES         ; 1 byte  ? raw del ADC (justificado izq)
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
    
    MOVLW b'00000000'
    MOVWF ADCON1
    
    BCF STATUS,RP0         ;BANCO 0
    BCF STATUS,RP1
    
    MOVLW b'01000001'
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
    
    ;Inicialización de displays apagados y variables
    CLRF PORTE
    CLRF PORTD
    CLRF CICLO_CNT
    CLRF TEMP
    CLRF UMBRAL_CM
    CLRF UMBRAL_DEC
    CLRF UMBRAL_UNI
    CLRF DISP_SEL
    CLRF ADC_RES
 
    ;Habilitación de interrupciones
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
    
    ;Inicialización de la conversión
    BSF ADCON0,GO

ESPERA_ADC
    BTFSC ADCON0,GO
    GOTO ESPERA_ADC

    ;Lectura del resultado
    MOVF ADRESH,W
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
    
    ;Conversión a BCD
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