;---------------------------------------------------------------------
; HU-01� medicion de distancia con HC-SR04
; Propósito: Enviar pulso TRIG, medir ancho ECHO con Timer1,
;            calcular distancia en cm.
; INTEGRACION: LISTO!
; Responsable: Juan
; ------------------------------------------------------------------
    LIST p=16F887
    #INCLUDE "P16F887.inc"
    RADIX HEX

    __CONFIG _CONFIG1, _FOSC_HS & _WDTE_OFF & _PWRTE_ON & _MCLRE_ON & _LVP_OFF
    __CONFIG _CONFIG2, _BOR4V_BOR40V & _WRT_OFF

; Variables
    CBLOCK 0x20
        DIST_CM         ; 1 byte  — distancia calculada en cm
        CICLO_CNT       ; 1 byte  — contador para temporizar 100ms
        TMR1_H          ; 1 byte  — valor alto Timer1 (para depuración)
        TMR1_L          ; 1 byte  — valor bajo Timer1
        W_TEMP          ; 1 byte  — guardado temporal de w
        STATUS_TEMP     ; 1 byte  — guardado temporal de STATUS
        CONT_DELAY
    ENDC

; Vector Reset
    ORG     0
    GOTO    MAIN

; ─── Vector ISR ───
    ORG     4
    GOTO    ISR_TIMER0

; =================================================================
; MAIN
; =================================================================
MAIN
    ; 1. Configurar puertos
    ;    - TRISC: RC0 como salida (TRIG), RC1 como entrada (ECHO)
    ;    - Inicializar RC0 = 0, RC1 como entrada
    BCF STATUS, RP1 ; BK1
    BSF STATUS, RP0

    BCF TRISC,0
    BSF TRISC,1

    ; 2. Configurar Timer0 para ~10ms e interrupciones
    ;    - OPTION_REG = 0x05 (prescaler 1:64), 156 x 64 aprox 10000 us
    ;    - TMR0 = 100 (para ~10ms)
    ;    - INTCON = 0xB0 (GIE=1, T0IE=1, INTE=1)


    BANKSEL OPTION_REG
    MOVLW   0x05        ; prescaler 1:64 for Timer0
    MOVWF   OPTION_REG
    MOVLW   0xB0
    MOVWF   INTCON



    BCF STATUS, RP0 ;BK0
    ; 3. Configurar Timer1 para medir ECHO
    ;    - T1CON = 0x01 (Timer1 ON, prescaler 1:1, osc deshabilitado)
    ;    - 1 tick = 1 µs a 4 MHz

    MOVLW 0x01
    MOVWF T1CON
    ; 4. Inicializar variables
    CLRF    DIST_CM
    CLRF    CICLO_CNT
    CLRF    TMR1_H
    CLRF    TMR1_L
    MOVLW .100
    MOVWF TMR0
    BCF PORTC,0



; ─── LOOP principal ───
LOOP
    ; Cada 100ms se ejecuta la medición desde ISR.
    GOTO    LOOP


; =================================================================
; ISR Timer0 (~10ms)
; =================================================================
ISR_TIMER0
    ; Guardar contexto (W y STATUS)
    CALL GUARDAR_CONTEXTO


    ; Relanzar Timer0
    MOVLW   .100
    MOVWF   TMR0
    BCF     INTCON, TMR0IF

    ; Incrementar contador de ciclos
    BANKSEL CICLO_CNT
    INCF    CICLO_CNT, F
    MOVLW   .10
    SUBWF   CICLO_CNT, W
    BTFSS   STATUS, Z
    GOTO    RECUPERAR_CONTEXTO

    ;Cada 10 ciclos (~100ms): medir distancia
    CLRF    CICLO_CNT
    CALL    MEDIR_HCSR04
    GOTO RECUPERAR_CONTEXTO


; =================================================================
; MEDIR_HCSR04 pulso TRIG + medicion ECHO con Timer1
; =================================================================
MEDIR_HCSR04
    ; --- PASO 1: Enviar pulso TRIG de 10�s ---
    ; BSF PORTC, RC0
    ; Esperar aprox 10�s
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
    GOTO RECUPERAR_CONTEXTO



GUARDAR_CONTEXTO
    MOVWF W_TEMP
    SWAPF STATUS,0
    MOVWF STATUS_TEMP
    RETURN

RECUPERAR_CONTEXTO
    SWAPF STATUS_TEMP,0
    MOVWF STATUS
    SWAPF W_TEMP,1
    SWAPF W_TEMP,0
    RETFIE

    END
