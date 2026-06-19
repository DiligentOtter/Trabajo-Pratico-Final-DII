;---------------------------------------------------------------------
; HU-05 — Monitoreo desde PC (UART TX)
; Propósito: Cada 100 ms, enviar por UART la trama
;            "D:XXcm U:XXcm M:XX\r\n" con distancia, umbral y
;            estado del motor. 9600 8N1.
; Integración: LISTO!
; ------------------------------------------------------------------
    LIST p=16F887
    #INCLUDE "P16F887.inc"
    RADIX HEX

    __CONFIG _CONFIG1, _FOSC_HS & _WDTE_OFF & _PWRTE_ON & _MCLRE_ON & _LVP_OFF
    __CONFIG _CONFIG2, _BOR4V_BOR40V & _WRT_OFF

; ─── Variables (CONTRATO + scratch para TX) ───
    CBLOCK 0x20
        DIST_CM         ; 0x20  — lee
        UMBRAL_CM       ; 0x21  — lee
        UMBRAL_DEC      ; 0x22
        UMBRAL_UNI      ; 0x23
        DISP_SEL        ; 0x24
        CICLO_CNT       ; 0x25
        FLAGS           ; 0x26  — bit 0 = FLAG_TX
        TEMP            ; 0x27  — uso general (decenas/unidades)
        W_TEMP          ; 0x28  — context save
        STATUS_TEMP     ; 0x29
        TX_DEC          ; 0x2A  — decenas ASCII (HU-05)
        TX_UNI          ; 0x2B  — unidades ASCII (HU-05)
    ENDC

; ─── Vector Reset ───
    ORG     0
    GOTO    MAIN

; ─── Vector ISR ───
    ORG     4
    GOTO    ISR_DISPATCHER


; =================================================================
; MAIN - configura UART y entra al loop que espera FLAG_TX
; =================================================================
MAIN
    ;---------------
    BCF STATUS,RP1 ;BK0
    BCF STATUS,RP0

    MOVLW 0x90
    MOVWF RCSTA
    ;---------------
    BCF STATUS,RP1
    BSF STATUS,RP0   ; BANK 1

    MOVLW   0x19
    MOVWF   SPBRG
    
    MOVLW   0x24
    MOVWF   TXSTA
    
    BCF     TRISC, 6        ; RC6 = TX out
    BSF     TRISC, 7        ; RC7 = RX in

    ;-----------------
    BCF STATUS,RP1 ;BK0
    BCF STATUS,RP0
 
    CLRF FLAGS
    MOVLW 0XD0
    MOVWF INTCON

    ; 5. LOOP: espera FLAG_TX y envia 
 ; LOOP
 ;   GOTO    LOOP */


; =================================================================
; ISR_DISPATCHER - placeholder minimo . En el integrado se reemplaza por el dispatcher real
; (INT0 -> RCIF -> T0IF) y se setea FLAG_TX al final del ciclo de
; 100 ms.
; =================================================================
ISR_DISPATCHER
    MOVWF   W_TEMP
    SWAPF   STATUS, W
    MOVWF   STATUS_TEMP
   ; MOVLW   .100
   ; MOVWF   TMR0
   ; BCF     INTCON, T0IF */
    ; (En integrado: chequear INT0IF → RCIF → T0IF en ese orden)

   
    BSF     FLAGS, 0
    CALL ENVIAR_TRAMA
    GOTO    RECUPERAR_CONTEXTO


; =================================================================
; ENVIAR_TRAMA - emite "D:XXcm U:XXcm M:XX\r\n" (18 bytes)
;
; Lee DIST_CM, UMBRAL_CM y FLAGS bit 2 (FLAG_MOTOR), los formatea
; en ASCII y los manda byte por byte via TX_BYTE.
; =================================================================

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
    GOTO MOTOR_OFF
MOTOR_ON
    MOVLW 'O'
    CALL TX_BYTE
    MOVLW 'N'
    CALL TX_BYTE
    GOTO END_MOTOR
MOTOR_OFF
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



; =================================================================
; TX_BYTE - envía el byte en W por UART, espera TRMT = 1.
; Destruye: W (preservado), TEMP
; =================================================================
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

; =================================================================
; BIN_TO_ASCII - convierte byte 0-99 en ASCII decimal.
;   W      = entrada (valor binario 0-99)
;   TX_DEC = decenas en ASCII
;   TX_UNI = unidades en ASCII
; Usa TEMP como scratch.
; =================================================================
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


; =================================================================
; RECUPERAR_CONTEXTO
; =================================================================
RECUPERAR_CONTEXTO
    SWAPF   STATUS_TEMP, W
    MOVWF   STATUS
    SWAPF   W_TEMP, F
    SWAPF   W_TEMP, W
    RETFIE
    END
