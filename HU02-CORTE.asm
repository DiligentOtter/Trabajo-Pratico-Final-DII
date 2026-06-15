 ;integrada!

  LIST p=16F887
  #INCLUDE "P16F887.inc"
  RADIX HEX

 __CONFIG _CONFIG1, _FOSC_HS & _WDTE_OFF & _PWRTE_ON & _MCLRE_ON & _LVP_OFF
 __CONFIG _CONFIG2, _BOR4V_BOR40V & _WRT_OFF

    ;Variables compartidas con HU-01 y HU-03
    CBLOCK 0x20
       DIST_CM ; 1 byte - lo escribe HU-01
       UMBRAL_CM ; 1 byte - lo escribe HU-03
       FLAGS ; 1 byte - bit2 = FLAG_MOTOR
       DELAY1
       DELAY2
       DELAY3
    ENDC

    ORG 0
    GOTO MAIN
    ORG 4
    GOTO ISR

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
    BCF STATUS,RP0 ;BK0
    BCF STATUS,RP1

    ;LEDs apagados al inicio
    CLRF PORTD


    BSF STATUS,RP0 ;BANCO 1
    BCF STATUS,RP1

    ;Configuracion de puertos
    BCF TRISC,2 ;Conf como salida RC2
    BCF TRISD,0 ;Conf. como salida RD0 (LED)
    BCF TRISD,1 ;Conf. como salida RD1 (LED)



    ;Inicializar variables y LEDs
    BCF STATUS,RP1 ;BANCO 0
    BCF STATUS,RP0

    CLRF FLAGS
    BCF PORTA,1 ;LED verde OFF
    BSF PORTA,2 ;LED rojo ON

TEST_LOOP
    ; Caso 1: DIST_CM=10, UMBRAL_CM=15 → mano cerca → MOTOR_OFF
    MOVLW   .10
    MOVWF   DIST_CM
    MOVLW   .15
    MOVWF   UMBRAL_CM
    CALL    COMPARAR_Y_ACTUAR

    ; Caso 2: DIST_CM=20, UMBRAL_CM=15 → mano lejos → MOTOR_ON
    MOVLW   .20
    MOVWF   DIST_CM
    CALL    COMPARAR_Y_ACTUAR

    GOTO    TEST_LOOP

COMPARAR_Y_ACTUAR
    ;Comparar DIST_CM con UMBRAL_CM

    MOVF UMBRAL_CM,W
    SUBWF DIST_CM,W

    BTFSS STATUS,C
    GOTO MOTOR_OFF
    GOTO MOTOR_ON

MOTOR_ON
    CALL    PWM_ON
    BSF     PORTA, 1        ; LED verde ON
    BCF     PORTA, 2        ; LED rojo OFF
    BSF     FLAGS, 2        ; FLAG_MOTOR = 1
    RETURN

MOTOR_OFF
    CALL    PWM_OFF
    BCF     PORTA, 1        ; LED verde OFF
    BSF     PORTA, 2        ; LED rojo ON
    BCF     FLAGS, 2        ; FLAG_MOTOR = 0
    RETURN


PWM_ON ;stub de la version real

    BSF FLAGS,2 ;Motor ON
    RETURN

PWM_ON ;stub de la version real

    BCF FLAGS,2 ;Motor OFF
    RETURN



    END
