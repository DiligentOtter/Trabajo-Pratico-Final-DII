;---------------------------------------------------------------------
; HU-06 — Control desde PC (UART RX)
; Propósito: Atender interrupciones RCIF. Acepta 'R' (reanudar,
;            limpia FLAG_EMERGENCY) y 'P' (parar, activa emergencia).
;            Cualquier otro carácter se ignora.
; Integración: al pegar en tpFinal.asm, borrar este __CONFIG y este
;              CBLOCK, y sumar el chequeo de RCIF al dispatcher
;              (entre INT0 y T0IF). Importante: el integrado debe
;              tener INTCON = 0xD0 (PEIE=1) y PIE1 RCIE = 1.
; ------------------------------------------------------------------
    LIST p=16F887
    #INCLUDE "P16F887.inc"
    RADIX HEX

    __CONFIG _CONFIG1, _FOSC_HS & _WDTE_OFF & _PWRTE_ON & _MCLRE_ON & _LVP_OFF
    __CONFIG _CONFIG2, _BOR4V_BOR40V & _WRT_OFF

; ─── Variables (CONTRATO + scratch) ───
    CBLOCK 0x20
        DIST_CM         ; 0x20
        UMBRAL_CM       ; 0x21
        UMBRAL_DEC      ; 0x22
        UMBRAL_UNI      ; 0x23
        DISP_SEL        ; 0x24
        CICLO_CNT       ; 0x25
        FLAGS           ; 0x26  — bit 1 = FLAG_EMERGENCY (este esqueleto lo limpia/consulta)
        TEMP            ; 0x27
        W_TEMP          ; 0x28
        STATUS_TEMP     ; 0x29
    ENDC

; ─── Vector Reset ───
    ORG     0
    GOTO    MAIN

; ─── Vector ISR ───
    ORG     4
    GOTO    ISR_DISPATCHER


; =================================================================
; MAIN — habilita RX por interrupción.
; =================================================================
MAIN:
    ; ── 1. Puertos UART ──
    BCF     STATUS, RP0
    BCF     STATUS, RP1       ; Bank 0
    BSF     TRISC, 7          ; RC7/RX = IN
    BCF     TRISC, 6          ; RC6/TX = OUT (lo usa HU-05)

    ; ── 2. UART (mismo config que HU-05, escrito acá para standalone) ──
    BANKSEL TXSTA
    MOVLW   0x24
    MOVWF   TXSTA
    MOVLW   0x19
    MOVWF   SPBRG

    BANKSEL RCSTA
    MOVLW   0x90              ; SPEN + CREN
    MOVWF   RCSTA

    ; ── 3. Habilitar RCIE (interrupción de RX) ──
    BANKSEL PIE1
    BSF     PIE1, RCIE        ; bit 5

    ; ── 4. INTCON con PEIE=1 (sin esto, RCIF no interrumpe) ──
    BANKSEL INTCON
    MOVLW   0xD0
    MOVWF   INTCON

    ; ── 5. Loop principal ──
    BCF     STATUS, RP0
    BCF     STATUS, RP1
LOOP:
    GOTO    LOOP              ; en el integrado se suma el chequeo de FLAG_TX


; =================================================================
; ISR_DISPATCHER — orden lógico:
;   1) INT0   (emergencia) — ver HU-04
;   2) RCIF   (este archivo)
;   3) T0IF   (flujo normal) — ver HU-01/02/03
; =================================================================
ISR_DISPATCHER:
    MOVWF   W_TEMP
    SWAPF   STATUS, W
    MOVWF   STATUS_TEMP

    ; Limpiar T0IF siempre (puede haber disparado T0)
    MOVLW   .100
    MOVWF   TMR0
    BCF     INTCON, T0IF

    ; 1. INT0 (alta prioridad lógica) — delegada a HU-04
    BTFSS   INTCON, INT0IF
    GOTO    CHECK_RCIF
    CALL    ISR_EMERGENCIA    ; viene de HU-04 (definida allá)
    GOTO    RECUPERAR_CONTEXTO

CHECK_RCIF:
    ; 2. UART RX
    BTFSS   PIR1, RCIF
    GOTO    FIN_ISR           ; no hay RX → seguir con T0 normal
    CALL    ISR_UART_RX
    GOTO    RECUPERAR_CONTEXTO

FIN_ISR:
    ; 3. T0IF — flujo normal (acá entra el código de HU-01/02/03)
    ; En este esqueleto no hay nada; volver.
    GOTO    RECUPERAR_CONTEXTO


; =================================================================
; ISR_EMERGENCIA — importada conceptualmente de HU-04. En el
; integrado se elimina este duplicado y se usa el original de HU-04.
; =================================================================
ISR_EMERGENCIA:
    BCF     INTCON, INT0IF
    BANKSEL CCPR1L
    CLRF    CCPR1L
    BCF     STATUS, RP0
    BCF     STATUS, RP1
    BCF     PORTD, 0
    BSF     PORTD, 1
    BSF     FLAGS, 1          ; FLAG_EMERGENCY = 1
    RETURN


; =================================================================
; ISR_UART_RX — lee RCREG y dispatchea según el carácter.
;   'R' (0x52) → limpiar FLAG_EMERGENCY
;   'P' (0x50) → parar motor + set FLAG_EMERGENCY
;   otro       → descartar
;
; IMPORTANTE: leer RCREG limpia RCIF automáticamente.
; Si hubo overrun (OERR=1), hay que resetear CREN para recuperar.
; =================================================================
ISR_UART_RX:
    BANKSEL RCSTA
    BTFSC   RCSTA, OERR      ; ¿overrun?
    GOTO    RX_RESET_OERR

    MOVF    RCREG, W         ; leer byte (limpia RCIF)
    BCF     STATUS, RP0      ; asegurar Bank 0 para comparaciones
    BCF     STATUS, RP1

    ; ── Comparar con 'R' ──
    MOVWF   TEMP
    MOVLW   'R'
    SUBWF   TEMP, W
    BTFSC   STATUS, Z
    GOTO    RX_RESUME         ; era 'R'

    ; ── Comparar con 'P' ──
    MOVF    TEMP, W
    MOVWF   TEMP
    MOVLW   'P'
    SUBWF   TEMP, W
    BTFSC   STATUS, Z
    GOTO    RX_STOP           ; era 'P'

    ; ── Otro: ignorar ──
    RETURN

RX_RESUME:
    ; Limpiar FLAG_EMERGENCY. Por decisión de diseño (sensores no
    ; permiten saber si hay obstrucción), 'R' siempre limpia. El
    ; próximo ciclo de 100 ms re-evaluará DIST_CM vs UMBRAL_CM y
    ; si la mano sigue cerca, volverá a cortar.
    BCF     FLAGS, 1          ; FLAG_EMERGENCY = 0
    RETURN

RX_STOP:
    ; Parar motor + setear emergencia. Reutiliza la lógica de HU-04.
    CALL    ISR_EMERGENCIA
    RETURN

RX_RESET_OERR:
    ; Recovery de overrun: toggle CREN para limpiar OERR
    BCF     RCSTA, CREN
    BSF     RCSTA, CREN
    BCF     PIR1, RCIF        ; por las dudas
    RETURN


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
; 1. Cargar HU06-UART-RX.asm standalone
; 2. Abrir "UART1 IO" del simulador
; 3. Forzar estado inicial: BSF FLAGS, 1 (emergencia activa)
; 4. Enviar 'R' desde la ventana UART1 → verificar FLAGS bit 1 = 0
; 5. Enviar 'P' → verificar FLAGS bit 1 = 1, PORTD bit 1 = 1,
;    CCPR1L = 0
; 6. Enviar 'X' (basura) → verificar que no cambia nada
; 7. Probar recovery de OERR: forzar bit y enviar varios bytes
;    seguidos sin leer RCREG
; =================================================================

    END
