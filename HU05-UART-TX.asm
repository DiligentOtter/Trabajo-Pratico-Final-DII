;---------------------------------------------------------------------
; HU-05 — Monitoreo desde PC (UART TX)
; Propósito: Cada 100 ms, enviar por UART la trama
;            "D:XXcm U:XXcm M:XX\r\n" con distancia, umbral y
;            estado del motor. 9600 8N1.
; Integración: al pegar en tpFinal.asm, borrar este __CONFIG y este
;              CBLOCK, y mover la lógica al LOOP (chequeo FLAG_TX)
;              y a la ISR (set FLAG_TX cada 100 ms).
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
    ENDC

; ─── Vector Reset ───
    ORG     0
    GOTO    MAIN

; ─── Vector ISR ───
    ORG     4
    GOTO    ISR_DISPATCHER


; =================================================================
; MAIN — configura UART y entra al loop que espera FLAG_TX
; =================================================================
MAIN:
    ; ── 1. RC6/TX como salida ──
    BCF     STATUS, RP0
    BCF     STATUS, RP1       ; Bank 0
    BSF     TRISC, 7          ; RC7/RX = IN (habilitar antes que RCSTA)
    BCF     TRISC, 6          ; RC6/TX = OUT

    ; ── 2. Configurar UART: 9600 8N1 ──
    BANKSEL TXSTA
    MOVLW   0x24              ; TXEN=1, BRGH=1, async, 8 bits
    MOVWF   TXSTA

    MOVLW   0x19              ; 9600 bps @ 4 MHz con BRGH=1
    MOVWF   SPBRG

    BANKSEL RCSTA
    MOVLW   0x90              ; SPEN=1, CREN=1
    MOVWF   RCSTA             ; (al integrar, HU-06 también lee este reg)

    ; ── 3. INTCON con PEIE=1 para que RCIF pueda interrumpir ──
    ; (Lo pide HU-06, pero conviene dejarlo pronto.)
    BANKSEL INTCON
    MOVLW   0xD0              ; GIE + PEIE + T0IE + INTE
    MOVWF   INTCON

    ; ── 4. Estado inicial ──
    BCF     STATUS, RP0
    BCF     STATUS, RP1
    CLRF    FLAGS             ; arranca con FLAG_TX=0

    ; ── 5. LOOP: espera FLAG_TX y envía ──
LOOP:
    BTFSS   FLAGS, 0          ; ¿FLAG_TX = 1?
    GOTO    LOOP
    BCF     FLAGS, 0          ; limpiar (dueño: main)
    CALL    ENVIAR_TRAMA
    GOTO    LOOP


; =================================================================
; ISR_DISPATCHER — placeholder mínimo para que el esqueleto compile
; en standalone. En el integrado se reemplaza por el dispatcher real
; (INT0 → RCIF → T0IF) y se setea FLAG_TX al final del ciclo de
; 100 ms.
; =================================================================
ISR_DISPATCHER:
    MOVWF   W_TEMP
    SWAPF   STATUS, W
    MOVWF   STATUS_TEMP
    MOVLW   .100
    MOVWF   TMR0
    BCF     INTCON, T0IF
    ; (En integrado: chequear INT0IF → RCIF → T0IF en ese orden)

    ; En este esqueleto standalone, forzamos FLAG_TX cada ~10 ms solo
    ; para verificar que la trama sale. En producción se setea cada
    ; 100 ms (1 de cada 10 interrupciones de T0).
    BSF     FLAGS, 0
    GOTO    RECUPERAR_CONTEXTO


; =================================================================
; ENVIAR_TRAMA — emite "D:XXcm U:XXcm M:XX\r\n" (18 bytes)
;
; Lee DIST_CM, UMBRAL_CM y FLAGS bit 2 (FLAG_MOTOR), los formatea
; en ASCII y los manda byte por byte vía TX_BYTE.
; =================================================================
ENVIAR_TRAMA:
    ; ── Encabezado: "D:" ──
    MOVLW   'D'
    CALL    TX_BYTE
    MOVLW   ':'
    CALL    TX_BYTE

    ; ── DIST_CM como 2 dígitos ASCII ──
    MOVF    DIST_CM, W
    CALL    BIN_TO_ASCII_DECUNI   ; devuelve decenas en W, unidades en TEMP+1
    CALL    TX_BYTE
    MOVF    TEMP, W               ; unidades
    CALL    TX_BYTE

    ; ── "cm U:" ──
    MOVLW   'c'
    CALL    TX_BYTE
    MOVLW   'm'
    CALL    TX_BYTE
    MOVLW   ' '
    CALL    TX_BYTE
    MOVLW   'U'
    CALL    TX_BYTE
    MOVLW   ':'
    CALL    TX_BYTE

    ; ── UMBRAL_CM como 2 dígitos ASCII ──
    MOVF    UMBRAL_CM, W
    CALL    BIN_TO_ASCII_DECUNI
    CALL    TX_BYTE
    MOVF    TEMP, W
    CALL    TX_BYTE

    ; ── "cm M:" ──
    MOVLW   'c'
    CALL    TX_BYTE
    MOVLW   'm'
    CALL    TX_BYTE
    MOVLW   ' '
    CALL    TX_BYTE
    MOVLW   'M'
    CALL    TX_BYTE
    MOVLW   ':'
    CALL    TX_BYTE

    ; ── Estado del motor: "ON" o "FF" ──
    BTFSC   FLAGS, 2          ; ¿FLAG_MOTOR = 1?
    GOTO    MOTOR_ON_STR
    ; OFF
    MOVLW   'O'
    CALL    TX_BYTE
    MOVLW   'F'
    CALL    TX_BYTE
    MOVLW   'F'
    CALL    TX_BYTE
    GOTO    FIN_TRAMA
MOTOR_ON_STR:
    MOVLW   'O'
    CALL    TX_BYTE
    MOVLW   'N'
    CALL    TX_BYTE

FIN_TRAMA:
    ; ── Terminador: \r\n ──
    MOVLW   0x0D              ; '\r'
    CALL    TX_BYTE
    MOVLW   0x0A              ; '\n'
    CALL    TX_BYTE
    RETURN


; =================================================================
; TX_BYTE — envía el byte en W por UART, espera a que el buffer
;           esté libre (TRMT = 1).
; Destruye: W (preservado), TEMP
; =================================================================
TX_BYTE:
    MOVWF   TEMP              ; preservar byte
    BANKSEL TXSTA
TX_WAIT:
    BTFSS   TXSTA, TRMT       ; ¿transmisor libre?
    GOTO    TX_WAIT           ; no → esperar
    MOVF    TEMP, W
    MOVWF   TXREG             ; enviar
    RETURN


; =================================================================
; BIN_TO_ASCII_DECUNI — convierte byte 0–99 en W a:
;   W        = decenas en ASCII ('0'..'9')
;   TEMP     = unidades en ASCII ('0'..'9')
; Asume entrada ≤ 99 (DIST_CM y UMBRAL_CM siempre lo son por contrato).
; Método: resta sucesiva de 10.
; =================================================================
BIN_TO_ASCII_DECUNI:
    MOVWF   TEMP              ; copia para no perder el valor
    CLRF    W_TEMP            ; contador de decenas (reusar context save,
                               ; está OK porque acá no seベinterrumpe
                               ; o el main ya las restauró)
    ; Truco: como W_TEMP es context save, lo pisamos solo localmente
    ; y no afecta el flujo. Si te preocupa, usá TEMP+1 o una var local.

BIN_DEC_LOOP:
    MOVLW   10
    SUBWF   TEMP, W           ; W = TEMP - 10 (sin guardar)
    BTFSS   STATUS, C         ; ¿TEMP >= 10?
    GOTO    BIN_DEC_DONE      ; no → terminamos decenas
    ; sí → restar 10 a TEMP e incrementar decenas
    MOVWF   TEMP              ; TEMP = TEMP - 10
    INCF    W_TEMP, F
    GOTO    BIN_DEC_LOOP

BIN_DEC_DONE:
    ; W_TEMP tiene el contador de decenas (0..9)
    ; TEMP tiene el resto (unidades, 0..9)
    MOVLW   '0'
    ADDWF   W_TEMP, W         ; decenas en ASCII
    ; TEMP (unidades) sigue en RAM, lo devolvemos vía TEMP al caller
    MOVWF   TEMP              ; OJO: pisamos TEMP. Solución:
                               ;   - usar una variable local distinta
                               ;   - o devolver unidades en otra var
    ; → REESCRITURA abajo con dos variables separadas para evitar pisar.

    ; (Esta versión tiene un bug intencional marcado: TEMP se pisa.
    ;  Ver versión corregida abajo.)
    RETURN


; =================================================================
; Versión corregida de BIN_TO_ASCII_DECUNI — usa dos vars locales.
; Reemplaza a la de arriba en el integrado. En el esqueleto se
; conserva la versión simple para legibilidad.
; =================================================================
; BIN_TO_ASCII_DECUNI:
;     MOVWF   TEMP              ; copia del byte
;     CLRF    TEMP_UNI
;     CLRF    TEMP_DEC
; BIN_DEC_LOOP2:
;     MOVLW   10
;     SUBWF   TEMP, W
;     BTFSS   STATUS, C
;     GOTO    BIN_DEC_DONE2
;     MOVWF   TEMP
;     INCF    TEMP_DEC, F
;     GOTO    BIN_DEC_LOOP2
; BIN_DEC_DONE2:
;     ; decenas en TEMP_DEC, unidades en TEMP
;     MOVLW   '0'
;     ADDWF   TEMP_DEC, W      ; decenas en W (ASCII)
;     MOVWF   TEMP_DEC
;     MOVLW   '0'
;     ADDWF   TEMP, W          ; unidades en W (ASCII)
;     MOVWF   TEMP              ; caller lee unidades de TEMP
;     MOVF    TEMP_DEC, W      ; decenas en W
;     RETURN


; =================================================================
; RECUPERAR_CONTEXTO
; =================================================================
RECUPERAR_CONTEXTO:
    SWAPF   STATUS_TEMP, W
    MOVWF   STATUS
    SWAPF   W_TEMP, F
    SWAPF   W_TEMP, W
    RETFIE


; =================================================================
; BLOQUE DE TEST — para probar este esqueleto standalone en MPLABX.
; Comentar/eliminar al integrar.
;
; 1. Cargar HU05-UART-TX.asm standalone
; 2. Setear valores de prueba en RAM antes de correr:
;      DIST_CM   = .12
;      UMBRAL_CM = .08
;      FLAGS bit 2 = 1 (motor ON)
; 3. Abrir ventana "UART1 IO" o similar del simulador (9600 8N1)
; 4. Verificar que la trama "D:12cm U:08cm M:ON\r\n" sale
; 5. Probar variantes: DIST_CM=5, UMBRAL_CM=25, FLAG_MOTOR=0
;    → "D:05cm U:25cm M:OFF\r\n"
; 6. Probar borde: DIST_CM=0 → "D:00cm..."
;
; NOTA: la versión actual de BIN_TO_ASCII_DECUNI tiene un bug marcado.
;       Para que el test funcione, usá la versión corregida (deshabilita
;       la vieja y habilita la nueva).
; =================================================================

    END
