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
        TX_DEC          ; 0x2C  ? decenas ASCII (HU-05)
        TX_UNI          ; 0x2D  ? unidades ASCII (HU-05)
    ENDC
    CBLOCK 0x7D
        W_TEMP
        STATUS_TEMP
    ENDC

    ORG 0
    GOTO MAIN
    ORG 4
    GOTO ISR

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

; === MAIN ===
MAIN
    ; <<< puertos y perifericos>>>

    ;------------BK0---------------
    BCF STATUS,RP0
    BCF STATUS,RP1

    ;T1 CONFIG
    MOVLW 0x01
    MOVWF T1CON

    ;ADC
    MOVLW 0x41        ; ADCS=01 (Tad=2us), CHS=000 (AN0), ADON=1
    MOVWF ADCON0

    ;TX
    MOVLW 0x90
    MOVWF RCSTA
    ;-------------BK1-------------
    BCF STATUS,RP1
    BSF STATUS,RP0

    ;ADC
    MOVLW 0x80        ; ADFM=1: justificado a derecha, Vref=VDD
    MOVWF ADCON1

    ;TX/RX
    MOVLW   0x19
    MOVWF   SPBRG

    MOVLW   0x24
    MOVWF   TXSTA

    ;T0 CONFIG
    MOVLW   0x05        ; prescaler 1:64 for Timer0
    MOVWF   OPTION_REG

    ; I/O PORTS
    ;PORT A
    BSF TRISA,0 ;POTENCIOMETRO
    BCF TRISA,1
    BCF TRISA,2

    ;PORTB | INTERRUPCION
    BSF TRISB,0
    BSF WPUB,0

    ;PORTC
    BCF TRISC,0 ;TRIGGER SENSOR
    BSF TRISC,1 ;ECHO SENSOR
    BCF TRISC,2
    BCF TRISC,6 ;TX
    BSF TRISC,7 ;RX

    ;PORTD | 7SEG
    CLRF TRISD

    ;PORTE | 7SEG SELCT
    CLRF TRISE


    ;--------------BK3--------------------
    ;CONFIGURACIONES BK 3, ANALOGIC REGS
    BSF STATUS,RP0
    BSF STATUS,RP1

    BSF ANSEL,0 ;RA0/AN0
    BCF ANSEL,1 ;LED VERDE
    BCF ANSEL,2 ;LED ROJO
    CLRF ANSELH



    ;INCIALIZACION BK0
    BCF STATUS,RP0
    BCF STATUS,RP1
    
    ;INTERRUPCIONES
    MOVLW b'11110000'
    MOVWF INTCON



    CLRF DIST_CM
    CLRF UMBRAL_CM
    CLRF CICLO_CNT
    CLRF FLAGS
    CLRF PORTE
    CLRF PORTD
    BCF PORTA,1 ;LED VERDE
    BSF PORTA,2 ;LED ROJO
    BCF PORTC,0
    BCF FLAGS,1

    CALL PWM_INIT

    MOVLW .100
    MOVWF TMR0
LOOP
    GOTO LOOP

; === ISR  (unica) ===
ISR
    MOVWF W_TEMP ;SAVE CONTEXT
    SWAPF STATUS,W
    MOVWF STATUS_TEMP

    BCF     STATUS, RP0 ;BK0
    BCF     STATUS, RP1

    MOVLW .100 ;REFRESH T0
    MOVWF TMR0
    BCF INTCON,T0IF

    ;Atender rutina de emergencia
    BTFSC INTCON,INTF
    GOTO ISR_EMERGENCIA

    ;rutina de funcionamiento normal
    CALL RUTINA_DISPLAY

    INCF CICLO_CNT,F
    MOVLW .10
    SUBWF CICLO_CNT,W
    BTFSS STATUS,Z
    GOTO REVISA_RX
    CLRF CICLO_CNT

    ; <<< cada 100ms: LEER_ADC, MEDIR_HCSR04, COMPARAR_Y_ACTUAR >>>
    CALL ESPERA_ADC
    CALL MEDIR_HCSR04
    CALL COMPARAR_Y_ACTUAR
    CALL ENVIAR_TRAMA
    GOTO RECUPERAR_CONTEXTO
    
REVISA_RX
    BTFSC PIR1, RCIF 
    CALL ISR_UART_RX
    GOTO RECUPERAR_CONTEXTO

RECUPERAR_CONTEXTO
    SWAPF STATUS_TEMP,W
    MOVWF STATUS
    SWAPF W_TEMP,F
    SWAPF W_TEMP,W
    RETFIE

; ===================================== Subrutinas (pegar desde HU0X-*.asm) ===================================

ISR_EMERGENCIA

    BCF INTCON,INTF

    CALL PWM_OFF
    BCF PORTA,1      ; verde OFF
    BSF PORTA,2      ; rojo ON

    BSF FLAGS,1       ; FLAG_EMERGENCY = 1

    GOTO RECUPERAR_CONTEXTO

;-------------------------------------------------------

MEDIR_HCSR04
; --- Enviar pulso TRIG de 10µs ---
    ; BSF PORTC, RC0
    ; Esperar aprox 9µs
    
    MOVLW .3
    MOVWF CONT_DELAY
    BSF PORTC,0

DELAY_10US
    DECF CONT_DELAY
    BTFSS STATUS,Z
    GOTO DELAY_10US
    BCF PORTC,0           ; fin del pulso TRIG


    ; Polling de RC1, esperando que ECHO pase a 1

    MOVLW   .170        ; ~1ms timeout
    MOVWF   CONT_DELAY
ESPERAR_ECHO
    BTFSC   PORTC,RC1
    GOTO    ECHO_HIGH
    DECFSZ  CONT_DELAY,F
    GOTO    ESPERAR_ECHO

    ; Timeout
    CLRF   DIST_CM
    RETURN



    ; Cuando ECHO = 1:
    ;   TMR1H = 0, TMR1L = 0 (resetear Timer1)
    ;   ECHO = 0 o TMR1IF = 1  entonces (timeout ~25ms)
ECHO_HIGH

    CLRF TMR1H
    CLRF TMR1L
    BCF   PIR1, TMR1IF
    
ESPERAR_ECHO_BAJA
    BTFSS   PORTC,RC1
    GOTO    ECHO_LOW
    BTFSC   PIR1, TMR1IF
    GOTO    ECHO_TIMEOUT
    GOTO    ESPERAR_ECHO_BAJA
    
ECHO_TIMEOUT
    MOVLW   0xFF
    MOVWF   DIST_CM
    RETURN




    ; Cuando ECHO baja (o timeout):
    ; Si timeout (TMR1IF): DIST_CM = 0xFF (error/desconectado)
ECHO_LOW
    MOVF TMR1H,0
    MOVWF TMR1_H
    MOVF TMR1L,0
    MOVWF TMR1_L

    ; CORREMOS 3 VECES LOS BITS DE LOS REGISTROS
    BCF STATUS,C ; TMR1 * 2
    RLF TMR1_L,1
    RLF TMR1_H,1

    BCF STATUS,C ; TMR1 * 4
    RLF TMR1_L,1
    RLF TMR1_H,1

    BCF STATUS,C ;TMR1 * 8
    RLF TMR1_L,1
    RLF TMR1_H,1

    ; SUMAMOS LOS ORIGNALES PARA HACER * 9
    MOVF TMR1L,0
    ADDWF TMR1_L
    BTFSC STATUS,C
    INCF TMR1_H
    MOVF TMR1H,0
    ADDWF TMR1_H

    ;dividimos por 512, moviendo solo el registro alto un bit a la derecha, tenemos una tolerancia de +-1cm
    BCF STATUS,C
    RRF TMR1_H,1
    MOVF TMR1_H,0
    MOVWF DIST_CM
    RETURN


;----------------------------------------------

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

;-------------lectura ADC-----------

ESPERA_ADC
    BSF ADCON0,GO
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

    ;Conversion a BCD
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

    RETURN

;------------------------------

COMPARAR_Y_ACTUAR   ; HU-02
    ;Comparar DIST_CM con UMBRAL_CM

    MOVF UMBRAL_CM,W
    SUBWF DIST_CM,W

    BTFSS   STATUS, C
    GOTO    MOTOR_OFF
    BTFSC   FLAGS, 1
    GOTO    MOTOR_OFF
    GOTO    MOTOR_ON

MOTOR_ON
    CALL    PWM_ON
    BSF     PORTA, 1  ; LED verde
    BCF     PORTA, 2  ; LED rojo
    BSF     FLAGS, 2  ; FLAG_MOTOR
    RETURN

MOTOR_OFF
    CALL    PWM_OFF
    BCF     PORTA, 1
    BSF     PORTA, 2
    BCF     FLAGS, 2
    RETURN


PWM_ON ;(motor 100% duty)
    MOVLW b'11111111'
    MOVWF CCPR1L
    RETURN


PWM_OFF ;(motor a 0% duty)
    CLRF CCPR1L
    RETURN
;-------------------------------

ENVIAR_TRAMA ; emitir "D:XXcm U:XXcm M:XX\r\n"
    MOVLW 'D'
    CALL TX_BYTE
    MOVLW ':'
    CALL TX_BYTE
    ;Emitiendo distancia ACTUAL
    MOVF DIST_CM,W
    CALL BIN_TO_ASCII

    MOVF TX_DEC,W
    CALL TX_BYTE
    MOVF TX_UNI,W
    CALL TX_BYTE
    MOVLW 'c'
    CALL TX_BYTE
    MOVLW 'm'
    CALL TX_BYTE

    ;emitiendo umbral actual ' U:xxcm'

    MOVLW ' '
    CALL TX_BYTE
    MOVLW 'U'
    CALL TX_BYTE
    MOVLW ':'
    CALL TX_BYTE
    MOVF UMBRAL_CM,W
    CALL BIN_TO_ASCII
    MOVF TX_DEC,W
    CALL TX_BYTE
    MOVF TX_UNI,W
    CALL TX_BYTE
    MOVLW 'c'
    CALL TX_BYTE
    MOVLW 'm'
    CALL TX_BYTE

    ;emitiendo estado motor
    MOVLW ' '
    CALL TX_BYTE
    MOVLW 'M'
    CALL TX_BYTE
    MOVLW ':'
    CALL TX_BYTE
    BTFSS FLAGS,2
    GOTO MOTOR_STATE_OFF
MOTOR_STATE_ON
    MOVLW 'O'
    CALL TX_BYTE
    MOVLW 'N'
    CALL TX_BYTE
    GOTO END_MOTOR

MOTOR_STATE_OFF
    MOVLW 'O'
    CALL TX_BYTE
    MOVLW 'O'
    CALL TX_BYTE
    MOVLW 'F'
    CALL TX_BYTE
END_MOTOR

    ;FIN TRAMA
    MOVLW 0X0D
    CALL TX_BYTE
    MOVLW 0X0A
    CALL TX_BYTE

    RETURN ;VOLVEMOS AL DISPACHER PARA LOS DEMAS PROCESOS

TX_BYTE
    MOVWF   TEMP
    BCF     STATUS, RP1
    BSF     STATUS, RP0     ; BANK 1
TX_WAIT
    BTFSS   TXSTA, TRMT
    GOTO    TX_WAIT
    MOVF    TEMP, W
    BCF     STATUS, RP1
    BCF     STATUS, RP0     ; BANK 0
    MOVWF   TXREG
    RETURN

BIN_TO_ASCII
    MOVWF   TEMP
    CLRF    TX_DEC
BIN_DEC_LOOP
    MOVLW   .10
    SUBWF   TEMP, W
    BTFSS   STATUS, C
    GOTO    BIN_DEC_DONE
    MOVWF   TEMP
    INCF    TX_DEC, F
    GOTO    BIN_DEC_LOOP
BIN_DEC_DONE
    MOVLW   '0'
    ADDWF   TEMP, W
    MOVWF   TX_UNI
    MOVF    TX_DEC, W
    ADDLW   '0'
    MOVWF   TX_DEC
    RETURN
    
;---------ISR DE RECEPCION---------------

ISR_UART_RX
    ;VER BYTE RECIBIDO
    MOVF    RCREG, W
    MOVWF   TEMP         


    BTFSS   RCSTA, OERR ;ERROR DE RECEPCION?
    GOTO    CHECK_CMD    

    ; Resetear OERR
    BCF     RCSTA, CREN
    BSF     RCSTA, CREN
    RETURN

CHECK_CMD
    ; ¿Es 'R' (0x52)?  reanudar
    MOVLW   'R'
    SUBWF   TEMP, W
    BTFSC   STATUS, Z
    GOTO    CMD_REANUDAR

    ; ¿Es 'P' (0x50)?
    MOVLW   'P'
    SUBWF   TEMP, W
    BTFSC   STATUS, Z
    GOTO    CMD_PARAR

   
    RETURN


CMD_REANUDAR
    BCF     FLAGS, 1            ; FLAG_EMERGENCY = 0
    
    BSF     PORTA, 1            ; LED verde ON
    BCF     PORTA, 2            ; LED rojo OFF
    CALL PWM_ON
    RETURN


CMD_PARAR
    ; Cortar motor
    CALL    PWM_OFF
    
    BCF     PORTA, 1            ; LED verde OFF
    BSF     PORTA, 2            ; LED rojo ON

    BSF     FLAGS, 1            ; FLAG_EMERGENCY = 1

    RETURN

;-------------------------------


PWM_INIT

    MOVLW b'00000100'
    MOVWF T2CON

    BCF STATUS,RP1 ;BK1
    BSF STATUS,RP0

    MOVLW b'11111111'
    MOVWF PR2

    BCF STATUS,RP1 ;BK0
    BCF STATUS,RP0


    MOVLW b'00001100'
    MOVWF CCP1CON

    CLRF CCPR1L
    RETURN

    END
