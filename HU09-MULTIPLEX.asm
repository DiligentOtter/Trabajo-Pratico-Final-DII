;---------------------------------------------------------------------
; HU-09 - Rutina de multiplexado de displays
; Proposito: RUTINA_DISPLAY se llama desde la ISR del Timer0
;            (cada ~10 ms) y alterna el digito activo. Usa DISP_SEL
;            para seleccionar decenas o unidades, aplica anti-ghosting
;            apagando ambos selectores antes de cambiar el bus, y
;            usa la tabla BCD_7SEG para convertir el digito a
;            segmentos.
; Integracion: al pegar en tpFinal.asm, borrar este __CONFIG y
;              CBLOCK. Llamar a RUTINA_DISPLAY al inicio de la ISR
;              (cada ~10 ms, antes del ciclo de 100 ms).
; ------------------------------------------------------------------
    LIST p=16F887
    #INCLUDE "P16F887.inc"
    RADIX HEX

    __CONFIG _CONFIG1, _FOSC_HS & _WDTE_OFF & _PWRTE_ON & _MCLRE_ON & _LVP_OFF
    __CONFIG _CONFIG2, _BOR4V_BOR40V & _WRT_OFF

; --- Variables (CONTRATO) ---
    CBLOCK 0x20
        DIST_CM         ; 0x20
        UMBRAL_CM       ; 0x21
        UMBRAL_DEC      ; 0x22  - lee (decenas del umbral)
        UMBRAL_UNI      ; 0x23  - lee (unidades del umbral)
        DISP_SEL        ; 0x24  - lee/escribe (bit 0 selector)
        CICLO_CNT       ; 0x25
        FLAGS           ; 0x26
        TEMP            ; 0x27
        W_TEMP          ; 0x28
        STATUS_TEMP     ; 0x29
    ENDC

; --- Vector Reset ---
    ORG     0
    GOTO    MAIN

; --- Vector ISR ---
    ORG     4
    GOTO    ISR_DISPATCHER


; =================================================================
; MAIN - configura puertos de display y setea valores de prueba
; =================================================================
MAIN
    ; --- COMPLETAR: configurar RD2-RD7 como salidas (segmentos) ---
    ; --- COMPLETAR: configurar RE0, RE1 como salidas (selectores) ---
    ; --- COMPLETAR: inicializar PORTD = 0, PORTE = 0, DISP_SEL = 0 ---

LOOP
    ; --- COMPLETAR: llamar a RUTINA_DISPLAY periodicamente ---
    GOTO    LOOP


; =================================================================
; ISR_DISPATCHER - placeholder. En integrado se llama cada ~10 ms
;                  desde la ISR del Timer0.
; =================================================================
ISR_DISPATCHER
    MOVWF   W_TEMP
    SWAPF   STATUS, W
    MOVWF   STATUS_TEMP

    ; --- COMPLETAR: llamar a RUTINA_DISPLAY ---

    GOTO    RECUPERAR_CONTEXTO


; =================================================================
; RUTINA_DISPLAY - multiplexado por software de 2 displays.
;
; Alterna el digito activo cada llamada:
;   DISP_SEL=0 -> muestra UMBRAL_DEC en RE0
;   DISP_SEL=1 -> muestra UMBRAL_UNI en RE1
;
; Antes de cambiar el bus de segmentos apaga AMBOS selectores
; (anti-ghosting) para evitar que se vea el digito anterior.
;
; Lee:    UMBRAL_DEC, UMBRAL_UNI, DISP_SEL
; Escribe: PORTD, PORTE (RE0, RE1), DISP_SEL
; =================================================================
RUTINA_DISPLAY
    ; --- COMPLETAR: anti-ghosting - apagar RE0 y RE1 ---
    ; --- COMPLETAR: si DISP_SEL = 0 ---
    ;       -> cargar UMBRAL_DEC, llamar BCD_7SEG, escribir PORTD
    ;       -> RE0 ON, DISP_SEL = 1
    ; --- COMPLETAR: si DISP_SEL = 1 ---
    ;       -> cargar UMBRAL_UNI, llamar BCD_7SEG, escribir PORTD
    ;       -> RE1 ON, DISP_SEL = 0
    RETURN


; =================================================================
; BCD_7SEG - lookup table: convierte digito 0-9 a patron 7 segmentos.
;
; Entrada: W = digito (0-9)
; Salida:  W = patron gfedcba (catodo comun, activo en alto)
; =================================================================
BCD_7SEG
    ; --- COMPLETAR: ADDWF PCL, F ---
    ; --- COMPLETAR: RETLW con patrones 0x3F, 0x06, ..., 0x6F ---
    ; --- (ver Anexo E de Requirements.md) ---
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


; =================================================================
; BLOQUE DE TEST - para probar este esqueleto standalone en MPLABX.
;
; 1. Cargar HU09-MULTIPLEX.asm standalone
; 2. Configurar puertos de display
; 3. Poner valores de prueba en UMBRAL_DEC y UMBRAL_UNI
; 4. Llamar a RUTINA_DISPLAY varias veces
; 5. Verificar que alterna entre RE0 (decenas) y RE1 (unidades)
; 6. Verificar anti-ghosting: ambos selectores OFF antes de cambiar PORTD
;
; Para integracion en tpFinal.asm:
;   - Borrar __CONFIG y CBLOCK
;   - Llamar a RUTINA_DISPLAY siempre al inicio de la ISR del Timer0
;     (cada ~10 ms, antes del ciclo de 100 ms)
;   - Asegurarse de que UMBRAL_DEC y UMBRAL_UNI esten actualizados
;     (HU-08 se encarga de convertirlos cada 100 ms)
; =================================================================

    END
