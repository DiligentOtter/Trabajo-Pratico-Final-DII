<<<<<<< HEAD
    LIST p=16F887
=======
; HU-02 ? Corte automatico del motor
; PIC16F887, cristal 4 MHz

    LIST    p=16F887
>>>>>>> ed7ab7f335d115842d3842e3d38e14b51cbd7137
    #INCLUDE "P16F887.inc"
    RADIX   HEX

    __CONFIG _CONFIG1, _FOSC_HS & _WDTE_OFF & _PWRTE_ON & _MCLRE_ON & _LVP_OFF
    __CONFIG _CONFIG2, _BOR4V_BOR40V & _WRT_OFF

<<<<<<< HEAD
;Variables compartidas con HU-01 y HU-03
    CBLOCK 0x20
        DIST_CM         ; 1 byte - lo escribe HU-01
        UMBRAL_CM       ; 1 byte - lo escribe HU-03
        FLAGS           ; 1 byte - bit2 = FLAG_MOTOR
	DELAY1
	DELAY2
	DELAY3
	
=======
;Variables compartidas (CONTRATO.md ? no cambiar direcciones)
    CBLOCK  0x20
        DIST_CM         ; 0x20 escribe HU-01, lee HU-02
        UMBRAL_CM       ; 0x21 escribe HU-03, lee HU-02
        UMBRAL_DEC      ; 0x22 (no usado por HU-02)
        UMBRAL_UNI      ; 0x23 (no usado por HU-02)
        DISP_SEL        ; 0x24 (no usado por HU-02)
        CICLO_CNT       ; 0x25 (no usado por HU-02)
        FLAGS           ; 0x26 bit0=FLAG_TX, bit1=FLAG_EMERGENCY, bit2=FLAG_MOTOR
>>>>>>> ed7ab7f335d115842d3842e3d38e14b51cbd7137
    ENDC
    
    ORG 0
    GOTO MAIN

<<<<<<< HEAD
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

=======
; Variables privadas HU-02 (para el delay de prueba) 
    CBLOCK  0x30
        DELAY1
        DELAY2
        DELAY3
    ENDC

; Macros para controlar el motor via PWM (CCP1) 
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

;  Vectores 
    ORG     0x00
    GOTO    MAIN

    ORG     0x04
    GOTO    ISR_CORTE

;  MAIN: inicializa todo y entra al loop de prueba 
MAIN:
    CALL    INIT_PUERTOS
    CALL    INIT_PWM
    CALL    INIT_VARIABLES

;
LOOP:
    ;  Caso 1: mano cerca (DIST_CM < UMBRAL_CM) ? motor OFF
    MOVLW   .10
    MOVWF   DIST_CM
    MOVLW   .15
    MOVWF   UMBRAL_CM
    CALL    COMPARAR_Y_ACTUAR
    CALL    DELAY_LARGO

    ; Caso 2: mano lejos (DIST_CM > UMBRAL_CM) ? motor ON 
    MOVLW   .20
    MOVWF   DIST_CM
    CALL    COMPARAR_Y_ACTUAR
    CALL    DELAY_LARGO

    GOTO    LOOP

; MODO_INTEGRADO (cuando HU-01 y HU-03 ya estan corriendo en el mismo ISR):
;   CALL    COMPARAR_Y_ACTUAR
;   GOTO    LOOP

; 
; RD0 (LED verde) y RD1 (LED rojo) como salidas
; Estado inicial seguro: verde OFF, rojo ON
INIT_PUERTOS:
    BANKSEL TRISD
    BCF     TRISD, 0
    BCF     TRISD, 1

    BANKSEL PORTD
    BCF     PORTD, 0        ; LED verde OFF
    BSF     PORTD, 1        ; LED rojo ON
    RETURN

; 
; RC2 como salida ANTES de habilitar CCP1
; T2CON=0x04: Timer2 ON, prescaler 1:1 (base de tiempo del PWM)
; PR2=0xFF: periodo maximo (~3.9kHz a 4MHz) ? vive en banco 1
; CCP1CON=0x0C: CCP1 en modo PWM
; CCPR1L=0x00: duty 0% ? motor OFF al arrancar
INIT_PWM:
    BANKSEL TRISC
    BCF     TRISC, 2

    BANKSEL PR2
    MOVLW   0xFF
    MOVWF   PR2

    BANKSEL T2CON
    MOVLW   0x04
    MOVWF   T2CON

    MOVLW   0x0C
    MOVWF   CCP1CON

    CLRF    CCPR1L
    RETURN

; 
; FLAGS en 0: sin emergencia, motor marcado como apagado
INIT_VARIABLES:
    BANKSEL FLAGS
    CLRF    FLAGS
    RETURN


COMPARAR_Y_ACTUAR:
    BANKSEL DIST_CM
    MOVF    UMBRAL_CM, W
    SUBWF   DIST_CM, W       ; W = DIST_CM - UMBRAL_CM
    BTFSS   STATUS, C        ; C=1 si DIST_CM >= UMBRAL_CM
    GOTO    MOTOR_OFF        ; C=0 ? DIST_CM < UMBRAL_CM ? cortar

    BTFSC   FLAGS, 1         ; FLAG_EMERGENCY?
    GOTO    MOTOR_OFF

MOTOR_ON:
    PWM_ON
    BSF     PORTD, 0         ; LED verde ON
    BCF     PORTD, 1         ; LED rojo OFF
    BSF     FLAGS, 2         ; FLAG_MOTOR = 1
    RETURN

MOTOR_OFF:
    PWM_OFF
    BCF     PORTD, 0         ; LED verde OFF
    BSF     PORTD, 1         ; LED rojo ON
    BCF     FLAGS, 2         ; FLAG_MOTOR = 0
    RETURN

; 
ISR_CORTE:
    RETFIE


; DELAY_LARGO ? ~0.5s a 4MHz, triple loop anidado

DELAY_LARGO:
    BANKSEL DELAY1
    MOVLW   .3
    MOVWF   DELAY1
LOOP_A:
    MOVLW   .250
    MOVWF   DELAY2
LOOP_B:
    MOVLW   .250
    MOVWF   DELAY3
LOOP_C:
    DECFSZ  DELAY3, F
    GOTO    LOOP_C
    DECFSZ  DELAY2, F
    GOTO    LOOP_B
    DECFSZ  DELAY1, F
    GOTO    LOOP_A
    RETURN

>>>>>>> ed7ab7f335d115842d3842e3d38e14b51cbd7137
    END

