; ──────────────────────────────────────────────────────────────
; HU-03 — ADC + Display 7 segmentos
; Propósito: Leer potenciómetro (AN0), mapear a umbral (5-25 cm),
;            mostrar en dos displays multiplexados.
; Responsable: Ari
; ──────────────────────────────────────────────────────────────
    LIST p=16F887
    #INCLUDE "P16F887.inc"
    RADIX HEX

    __CONFIG _CONFIG1, _FOSC_HS & _WDTE_OFF & _PWRTE_ON & _MCLRE_ON & _LVP_OFF
    __CONFIG _CONFIG2, _BOR4V_BOR40V & _WRT_OFF

; ─── Variables ───
    CBLOCK 0x20
        UMBRAL_CM       ; 1 byte  — resultado ADC mapeado a cm
        UMBRAL_DEC      ; 1 byte  — dígito decenas
        UMBRAL_UNI      ; 1 byte  — dígito unidades
        DISP_SEL        ; 1 byte  — flag selector (bit0: 0=dec, 1=uni)
        ADC_RES         ; 1 byte  — raw del ADC (justificado derecha)
    ENDC

; ─── Vector Reset ───
    ORG     0
    GOTO    MAIN

; ─── Vector ISR ───
    ORG     4
    GOTO    ISR_TIMER0

; =================================================================
; MAIN
; =================================================================
MAIN:
    ; 1. Configurar puertos
    ;    - TRISA: RA0 como entrada (AN0)
    ;    - TRISD: RD2-RD7 como salidas (segmentos)
    ;    - TRISE: RE0, RE1 como salidas (selectores display)
    ; TODO

    ; 2. Configurar ADC
    ;    - ADCON1 = 0x80 (Vref=VDD, justificado derecha)
    ;    - ADCON0 = 0x01 (canal AN0, ADC ON)
    ; TODO

    ; 3. Configurar Timer0
    ;    - OPTION_REG = 0x04 (prescaler 1:32 -> ~10ms a 4MHz)
    ;    - TMR0 = 6 (cargar para ~10ms exactos)
    ; TODO

    ; 4. Inicializar displays apagados
    ;    - PORTE = 0 (RE0=0, RE1=0)
    ;    - PORTD = 0 (segmentos apagados)
    ; TODO

    ; 5. Inicializar variables
    CLRF    UMBRAL_CM
    CLRF    UMBRAL_DEC
    CLRF    UMBRAL_UNI
    CLRF    DISP_SEL
    CLRF    ADC_RES

    ; 6. Habilitar interrupciones
    ;    - INTCON = 0xB0 (GIE=1, TMR0IE=1)
    BANKSEL INTCON
    MOVLW   0xB0
    MOVWF   INTCON

; ─── LOOP principal ───
LOOP:
    ; Nada que hacer acá, toda la lógica corre en ISR
    GOTO    LOOP


; =================================================================
; ISR Timer0 (~10ms)
; =================================================================
ISR_TIMER0:
    ; Guardar contexto (W y STATUS)
    ; TODO: guardar W y STATUS en temporales

    ; Relanzar Timer0 para próximo ciclo
    BANKSEL TMR0
    MOVLW   6
    MOVWF   TMR0

    ; Limpiar flag de interrupción
    BCF     INTCON, TMR0IF

    ; ── Llamar a rutina de display ──
    CALL    RUTINA_DISPLAY

    ; ── Cada 10 ciclos (100ms): leer ADC y actualizar umbral ──
    ; Incrementar contador (variable propia, o usar CICLO_CNT)
    ; TODO: INC CICLO_CNT
    ; TODO: BTFSS CICLO_CNT, 3  -> si es 10?
    ;       O mejor: INC y cuando llegue a 10, resetear
    ;
    ; Cuando toca ciclo 10:
    ;   1. Iniciar conversión ADC: BSF ADCON0, GO_DONE
    ;   2. Esperar que termine: BTFSC ADCON0, GO_DONE
    ;   3. Leer ADRESH -> ADC_RES
    ;   4. Mapear ADC_RES (0-255) a UMBRAL_CM (5-25):
    ;      UMBRAL_CM = 5 + (ADC_RES * 20 / 256)
    ;      (aproximación: dividir ADC_RES entre ~13)
    ;   5. Convertir UMBRAL_CM a BCD:
    ;      - UMBRAL_DEC = UMBRAL_CM / 10
    ;      - UMBRAL_UNI = UMBRAL_CM % 10
    ; TODO

    ; Restaurar contexto
    ; TODO: restaurar W y STATUS
    RETFIE


; =================================================================
; RUTINA_DISPLAY — multiplexado de 2 dígitos
; Llama cada ~10ms (desde ISR). Alterna entre decenas y unidades.
; =================================================================
RUTINA_DISPLAY:
    ; 1. Anti-ghosting: apagar ambos selectores y bus
    BCF     PORTE, RE0
    BCF     PORTE, RE1
    ; No es necesario limpiar PORTD si vamos a sobrescribirlo

    ; 2. Decidir qué dígito mostrar según DISP_SEL
    BTFSS   DISP_SEL, 0
    GOTO    SHOW_DECENAS

SHOW_UNIDADES:
    ; Cargar UMBRAL_UNI, convertir a 7 segmentos, escribir PORTD,
    ; encender RE1, toggle DISP_SEL
    MOVF    UMBRAL_UNI, W
    CALL    BCD_7SEG
    MOVWF   PORTD
    BSF     PORTE, RE1
    BSF     DISP_SEL, 0      ; próximo: decenas
    RETURN

SHOW_DECENAS:
    ; Cargar UMBRAL_DEC, convertir a 7 segmentos, escribir PORTD,
    ; encender RE0, toggle DISP_SEL
    MOVF    UMBRAL_DEC, W
    CALL    BCD_7SEG
    MOVWF   PORTD
    BSF     PORTE, RE0
    BCF     DISP_SEL, 0      ; próximo: unidades
    RETURN


; =================================================================
; BCD_7SEG — tabla de conversión BCD a 7 segmentos
; Entrada: W = dígito (0-9)
; Salida: W = patrón 7 segmentos (gfedcba, activo en alto)
; =================================================================
BCD_7SEG:
    ADDWF   PCL, F
    RETLW   0x3F    ; 0
    RETLW   0x06    ; 1
    RETLW   0x5B    ; 2
    RETLW   0x4F    ; 3
    RETLW   0x66    ; 4
    RETLW   0x6D    ; 5
    RETLW   0x7D    ; 6
    RETLW   0x07    ; 7
    RETLW   0x7F    ; 8
    RETLW   0x6F    ; 9

    END
