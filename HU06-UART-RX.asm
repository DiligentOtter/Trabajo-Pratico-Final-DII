
    LIST    p=16F887
    #INCLUDE "P16F887.inc"
    RADIX   HEX

    __CONFIG _CONFIG1, _FOSC_HS & _WDTE_OFF & _PWRTE_ON & _MCLRE_ON & _LVP_OFF
    __CONFIG _CONFIG2, _BOR4V_BOR40V & _WRT_OFF


    CBLOCK  0x20
        DIST_CM         ; 0x20  ? HU-01 escribe, HU-06 NO toca
        UMBRAL_CM       ; 0x21  ? HU-03 escribe, HU-06 NO toca
        UMBRAL_DEC      ; 0x22
        UMBRAL_UNI      ; 0x23
        DISP_SEL        ; 0x24
        CICLO_CNT       ; 0x25
        FLAGS           ; 0x26  ? bit 1 = FLAG_EMERGENCY (HU-04 setea, HU-06 limpia)
        TEMP            ; 0x27  ? scratch general
        ADC_RES         ; 0x28
        TMR1_H          ; 0x29
        TMR1_L          ; 0x2A
        CONT_DELAY      ; 0x2B
        TX_DEC          ; 0x2C
        TX_UNI          ; 0x2D
        W_TEMP          ; 0x2E  ? context save ISR
        STATUS_TEMP     ; 0x2F  ? context save ISR
    ENDC


; Vector Reset

    ORG     0x00
    GOTO    MAIN


; Vector ISR

    ORG     0x04
    GOTO    ISR_DISPATCHER


; MAIN
; Configura UART RX y habilita interrupción RCIF.
; En el integrado este bloque se funde con el MAIN de tpFinal.asm.

MAIN
    ;Banco 0: RCSTA (habilitar puerto serie y recepción continua) ---
    BCF     STATUS, RP1
    BCF     STATUS, RP0         ; Banco 0

    MOVLW   0x90                ; SPEN=1, CREN=1, 8 bits, async
    MOVWF   RCSTA

    ;Banco 1: TRISC, TXSTA, SPBRG, PIE1
    BCF     STATUS, RP1
    BSF     STATUS, RP0         ; Banco 1

    BCF     TRISC, 6            ; RC6/TX = salida
    BSF     TRISC, 7            ; RC7/RX = entrada

    MOVLW   0x24                ; TX habilitado, async, BRGH=1
    MOVWF   TXSTA

    MOVLW   0x19                ; 9600 bps @ 4 MHz con BRGH=1
    MOVWF   SPBRG

    BSF     PIE1, RCIE          ; Habilitar interrupción RCIF

    ;Banco 0: INTCON
    BCF     STATUS, RP1
    BCF     STATUS, RP0         ; Bank 0

   
    MOVLW   0xD0
    MOVWF   INTCON

    ; Inicializar FLAGS: sin emergencia al arrancar
    BCF     FLAGS, 1            ; FLAG_EMERGENCY = 0

;Loop principal
LOOP
    GOTO    LOOP



ISR_DISPATCHER
    ; Guardar contexto (obligatorio por guía de estilo)
    MOVWF   W_TEMP
    SWAPF   STATUS, W
    MOVWF   STATUS_TEMP

    ; 1. Chequear INT0 (emergencia física ? HU-04 lo maneja en integrado)
    BTFSC   INTCON, INTF
    GOTO    ISR_EMERGENCIA     

    ; 2. Chequear RCIF (UART RX ? este archivo)
CHECK_RCIF
    BANKSEL PIR1
    BTFSC   PIR1, RCIF
    GOTO    ISR_UART_RX

 

    GOTO    RECUPERAR_CONTEXTO


; ISR_UART_RX
; Atiende RCIF: lee RCREG, procesa 'R' o 'P', ignora el resto.
; El flag RCIF se limpia automáticamente al leer RCREG (HW).
; Dueño del bit FLAGS,1: HU-04 setea, HU-06 limpia ('R').

ISR_UART_RX
    ; Leer byte recibido (limpia RCIF automáticamente)
    BCF     STATUS, RP1
    BCF     STATUS, RP0         ; Bank 0
    MOVF    RCREG, W
    MOVWF   TEMP                ; guardar byte para comparar

 
    BCF     STATUS, RP1
    BCF     STATUS, RP0         ; Banco 0
    BTFSS   RCSTA, OERR
    GOTO    CHECK_CMD           ; sin error ? procesar comando

    ; Resetear OERR: BCF/BSF CREN (RCSTA está en Banco 0)
    BCF     RCSTA, CREN
    BSF     RCSTA, CREN
    GOTO    RECUPERAR_CONTEXTO  ; descartar byte corrupto

CHECK_CMD
    ; ¿Es 'R' (0x52)? ? reanudar: limpiar FLAG_EMERGENCY
    MOVLW   'R'
    SUBWF   TEMP, W
    BTFSC   STATUS, Z
    GOTO    CMD_REANUDAR

    ; ¿Es 'P' (0x50)? ? parar: activar emergencia
    MOVLW   'P'
    SUBWF   TEMP, W
    BTFSC   STATUS, Z
    GOTO    CMD_PARAR

   
    GOTO    RECUPERAR_CONTEXTO


; CMD_REANUDAR ? 'R': limpiar FLAG_EMERGENCY (FLAGS bit 1)

CMD_REANUDAR
    BCF     FLAGS, 1            ; FLAG_EMERGENCY = 0
    ; Restablecer LEDs: verde ON, rojo OFF (estado normal)
    BCF     STATUS, RP1
    BCF     STATUS, RP0         ; Bank 0
    BSF     PORTD, 0            ; LED verde ON
    BCF     PORTD, 1            ; LED rojo OFF
    GOTO    RECUPERAR_CONTEXTO



CMD_PARAR
    ; Cortar motor (en integrado: CALL PWM_OFF de HU-10)
    BCF     STATUS, RP1
    BCF     STATUS, RP0         ; Bank 0
    CLRF    CCPR1L              ; duty = 0% (placeholder; integrado usa PWM_OFF)

    ; LEDs: rojo ON, verde OFF
    BCF     PORTD, 0            ; LED verde OFF
    BSF     PORTD, 1            ; LED rojo ON

    ; Setear FLAG_EMERGENCY (FLAGS bit 1)
    BSF     FLAGS, 1            ; FLAG_EMERGENCY = 1

    GOTO    RECUPERAR_CONTEXTO



ISR_EMERGENCIA
    BCF     INTCON, INTF        ; limpiar flag INT0
    CLRF    CCPR1L              ; motor OFF (placeholder)
    BCF     PORTD, 0            ; LED verde OFF
    BSF     PORTD, 1            ; LED rojo ON
    BSF     FLAGS, 1            ; FLAG_EMERGENCY = 1
    GOTO    RECUPERAR_CONTEXTO


; RECUPERAR_CONTEXTO ? restaurar W y STATUS, retornar de ISR

RECUPERAR_CONTEXTO
    SWAPF   STATUS_TEMP, W
    MOVWF   STATUS
    SWAPF   W_TEMP, F
    SWAPF   W_TEMP, W
    RETFIE

    END