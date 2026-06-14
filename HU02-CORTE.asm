    LIST p=16F887
    #INCLUDE "P16F887.inc"
    RADIX HEX

    __CONFIG _CONFIG1, _FOSC_HS & _WDTE_OFF & _PWRTE_ON & _MCLRE_ON & _LVP_OFF
    __CONFIG _CONFIG2, _BOR4V_BOR40V & _WRT_OFF

;Variables compartidas con HU-01 y HU-03
    CBLOCK 0x20
        DIST_CM         ; 1 byte - lo escribe HU-01
        UMBRAL_CM       ; 1 byte - lo escribe HU-03
        FLAGS           ; 1 byte - bit2 = FLAG_MOTOR
	DELAY1
	DELAY2
	DELAY3
	
    ENDC
    
    ORG 0
    GOTO MAIN

    ORG 4
    GOTO ISR_CORTE

;PWM_ON / PWM_OFF
PWM_ON MACRO
    BANKSEL CCPR1L
    MOVLW b'11111111'
    MOVWF CCPR1L
    ENDM

PWM_OFF MACRO
    BANKSEL CCPR1L
    CLRF CCPR1L
    ENDM
   
MAIN
    
    BSF STATUS,RP0
    BCF STATUS,RP1           ;BANCO 1
    
    ;Configuracion de puertos
    BCF TRISC,2       ;Conf como salida RC2
    BCF TRISD,0       ;Conf. como salida RD0 (LED)
    BCF TRISD,1       ;Conf. como salida RD1 (LED)
    
    ;LEDs apagados al inicio
    BANKSEL PORTD
    CLRF PORTD
    
    ;Conf. PWM con CCP1
    BANKSEL T2CON
    MOVLW b'00000100'
    MOVWF T2CON      ;timer ON con prescaler 1:1
    
    BANKSEL PR2
    MOVLW b'11111111'
    MOVWF PR2       ;periodo maximo
    
    BANKSEL CCP1CON
    MOVLW b'00001100'
    MOVWF CCP1CON
    
    BANKSEL CCPR1L
    CLRF CCPR1L 
    
    ;Inicializar variables y LEDs
    BANKSEL FLAGS
    CLRF FLAGS   

    BCF PORTD,0          ;LED verde OFF 
    BSF PORTD,1          ;LED rojo ON  

LOOP
    ;CASO 1:Mano cerca (DIST_CM < UMBRAL_CM), motor OFF
    BANKSEL DIST_CM
    
    MOVLW .10
    MOVWF DIST_CM
    MOVLW .15
    MOVWF UMBRAL_CM
    CALL COMPARAR_Y_ACTUAR
    CALL DELAY_LARGO

    ;CASO 2: Mano lejos (DIST_CM > UMBRAL_CM), motor ON 
    MOVLW .20
    MOVWF DIST_CM
    CALL COMPARAR_Y_ACTUAR
    CALL DELAY_LARGO

    GOTO    LOOP

COMPARAR_Y_ACTUAR
    ;Comparar DIST_CM con UMBRAL_CM
    BANKSEL DIST_CM
    MOVF UMBRAL_CM,W
    SUBWF DIST_CM,W
    BTFSS STATUS,C
    GOTO MOTOR_OFF
    GOTO MOTOR_ON
MOTOR_ON
    ;Primero verificar que no haya emergencia
    BANKSEL FLAGS
    BTFSC FLAGS,1
    GOTO MOTOR_OFF

    PWM_ON 
    
    BANKSEL PORTD
    BSF PORTD,0          ;Led verde ON
    BCF PORTD,1          ;Led rojo off
    
    ;Motor encendido
    BANKSEL FLAGS
    BSF FLAGS,2          ;Motor ON
    RETURN 
 
MOTOR_OFF
    PWM_OFF
    
    BANKSEL PORTD
    BCF PORTD,0          ;Led verde OFF
    BSF PORTD,1          ;Led rojo ON
    
    BANKSEL FLAGS
    BCF FLAGS,2        ;Flag motor=0
    RETURN

ISR_CORTE
    ; En el integrado final, acá se llamará COMPARAR_Y_ACTUAR
    ; desde la ISR del Timer0. Por ahora, solo retornar.
    RETFIE

DELAY_LARGO
    BANKSEL DELAY1
    MOVLW .3
    MOVWF DELAY1
LOOP_A
    MOVLW .250
    MOVWF DELAY2
LOOP_B
    MOVLW .250
    MOVWF DELAY3
LOOP_C
    DECFSZ DELAY3,1
    GOTO LOOP_C
    DECFSZ DELAY2,1
    GOTO LOOP_B
    DECFSZ DELAY1,1
    GOTO LOOP_A
    
    RETURN

    END

