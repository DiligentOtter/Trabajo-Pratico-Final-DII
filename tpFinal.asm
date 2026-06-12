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
    GOTO ISR

; === MAIN ===
MAIN
    ; <<< puertos y perifericos>>>
    ; OPTION_REG=0x05, TMR0=100, INTCON=0xB0

    ;CONFIGURACIONES BK 0
    BCF STATUS,RP0
    BCF STATUS,RP1
    ;T1 CONFIG
    MOVLW 0x01
    MOVWF T1CON

    ;CONFIGURACIONES BK 1
    BCF STATUS,RP0
    BSF STATUS,RP1

    ;T0 CONFIG
    MOVLW   0x05        ; prescaler 1:64 for Timer0
    MOVWF   OPTION_REG
    MOVLW   0xB0
    MOVWF   INTCON

    ; I/O PORTS
    BCF TRISC,0
    BSF TRISC,1

    ;CONFIGURACIONES BK 2
    ;CONFIGURACIONES BK 3



    ;INCIALIZACION
    BCF STATUS,RP0
    BCF STATUS,RP1

    MOVLW .100
    MOVWF TMR0

    CLRF DIST_CM
    CLRF UMBRAL_CM
    CLRF CICLO_CNT
    CLRF FLAGS
    CLRF PORTE
    CLRF PORTD
    BCF PORTC,0
LOOP
    GOTO LOOP

; === ISR  (unica) ===
ISR
    MOVWF W_TEMP
    SWAPF STATUS,W
    MOVWF STATUS_TEMP
    MOVLW .100
    MOVWF TMR0
    BCF INTCON,T0IF

    ;Atender rutina de emergencia, si hay si no skip, y RETFIE

    ;rutina de funcionamiento normal
    ; <<< RUTINA_DISPLAY (HU-03) - siempre >>>
    CALL RUTINA_DISPLAY

    INCF CICLO_CNT,F
    MOVLW .10
    SUBWF CICLO_CNT,W
    BTFSS STATUS,Z
    GOTO FIN_ISR
    CLRF CICLO_CNT

    ; <<< cada 100ms: LEER_ADC, MEDIR_HCSR04, COMPARAR_Y_ACTUAR, despachador >>>
    CALL LEER_ADC
    CALL MEDIR_HCSR04
    CALL COMPARAR_Y_ACTUAR
    GOTO RECUPERAR_CONTEXTO

RECUPERAR_CONTEXTO
    SWAPF STATUS_TEMP,W
    MOVWF STATUS
    SWAPF W_TEMP,F
    SWAPF W_TEMP,W
    RETFIE

; ===================================== Subrutinas (pegar desde HU0X-*.asm) ===================================


MEDIR_HCSR04        ; HU-01
; --- PASO 1: Enviar pulso TRIG de 10µs ---
    ; BSF PORTC, RC0
    ; Esperar aprox 10µs
    MOVLW .2              ; ~9us con prescaler 1:1 a 4MHz

    MOVWF CONT_DELAY
    BSF PORTC,0
DELAY_10US
    DECF CONT_DELAY
    BTFSS STATUS,Z
    GOTO DELAY_10US
    BCF PORTC,0           ; fin del pulso TRIG

    ; --- PASO 2: Esperar que ECHO suba (con timeout) ---
    ; Polling de RC1, esperando que pase a 1
    ; Si pasa demasiado tiempo (~1ms), abortar

    MOVLW   .170        ; ~1ms timeout (1020us a 4MHz)
    MOVWF   CONT_DELAY
ESPERAR_ECHO
    BTFSC   PORTC,RC1
    GOTO    ECHO_HIGH
    DECFSZ  CONT_DELAY,F
    GOTO    ESPERAR_ECHO

    ; Timeout - sensor disconnected
    MOVLW   0xFF
    MOVWF   DIST_CM
    GOTO    RECUPERAR_CONTEXTO


    ; --- PASO 3: Iniciar Timer1 y medir ancho del pulso ---
    ; Cuando ECHO = 1:
    ;   TMR1H = 0, TMR1L = 0 (resetear Timer1)
    ; ECHO = 0 o TMR1IF = 1  entonces (timeout ~25ms)
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
    GOTO    RECUPERAR_CONTEXTO



    ; --- PASO 4: Calcular distancia ---
    ; Cuando ECHO baja (o timeout):
    ;   TMR1_H = TMR1H, TMR1_L = TMR1L (guardar)
    ;   distancia_cm = ticks / 58 == ticks*9/512
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


RUTINA_DISPLAY      ; HU-03
LEER_ADC            ; HU-03
COMPARAR_Y_ACTUAR   ; HU-02
BCD_7SEG            ; HU-03

    END
