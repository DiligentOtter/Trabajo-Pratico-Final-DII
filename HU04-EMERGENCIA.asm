 LIST p=16F887
    #INCLUDE "P16F887.inc"
    RADIX HEX

    __CONFIG _CONFIG1, _FOSC_HS & _WDTE_OFF & _PWRTE_ON & _MCLRE_ON & _LVP_OFF
    __CONFIG _CONFIG2, _BOR4V_BOR40V & _WRT_OFF

    CBLOCK 0x20
        DIST_CM         ; 0x20  ? compartido, no se usa acá
        UMBRAL_CM       ; 0x21  ? compartido, no se usa acá
        UMBRAL_DEC      ; 0x22
        UMBRAL_UNI      ; 0x23
        DISP_SEL        ; 0x24
        CICLO_CNT       ; 0x25
        FLAG           ; 0x26  ? bit 1 = FLAG_EMERGENCY (dueño: HU-04 setea, HU-06 limpia)
        TEMP            ; 0x27
        W_TEMP          ; 0x28  ? context save
        STATUS_TEMP     ; 0x29
    ENDC

    ORG 0X00
    GOTO MAIN

    ORG 0X04
    GOTO ISR_DISPATCHER

MAIN
    ;Conf. RB0 como entrada
    BSF STATUS,RP0            ;BANCO 1
    BCF STATUS,RP1
  
    BSF TRISB,0          
    BSF WPUB,0

    BCF TRISD,0
    BCF TRISD,1
    ;Flanco descendente en INT0
    ;OPTION_REG bit 6 = INTEDG. 0 = descendente, 1 = ascendente.
    ;CUIDADO: El resto de OPTION_REG lo define HU-03 (prescaler T0),por eso usamos BCF sobre el bit, no MOVLW directo.

    BCF OPTION_REG,INTEDG
    BCF OPTION_REG,0
    
    ;Habilitar INT0 en INTCON
    ; GIE=1 + INTE=1 + T0IE=1 (+ PEIE=1 que pide HU-06)
    ; Ver CONTRATO.md: valor final 0xD0. 
    ;[REVISARRRRR ESTE BLOQUE]
    BCF STATUS,RP0           ;BANCO 0
    BCF STATUS,RP1
    
    BCF INTCON,INTF
    
    MOVLW b'11010000'
    MOVWF INTCON

    ;Estado inicial seguro
    ;Asumimos que HU-02 ya dejó motor OFF. Si este esqueleto corre standalone, forzar el estado seguro acá:
   
    BCF PORTD,1    ;Led rojo OFF
    BSF PORTD,0    ;Led verde ON
    BCF FLAG,1    ;Sin emergencia al arrancar

LOOP
    GOTO LOOP          
    
; ISR_DISPATCHER ? orden de prioridad lógica:
;   1) INT0  (emergencia)
;   2) (acá iría RCIF cuando se integre HU-06)
;   3) T0IF  (flujo normal)

ISR_DISPATCHER
    ;Guardado de contexto
    MOVWF W_TEMP
    SWAPF STATUS,W
    MOVWF STATUS_TEMP
    
    BTFSC INTCON,INTF
    GOTO ISR_EMERGENCIA

    GOTO RECUPERAR_CONTEXTO
    
ISR_NORMAL
    ;(En el integrado: acá se mete el chequeo de RCIF y luego el
    ;flujo de Timer0 que ya tienen HU-01/02/03.)
    ;Por ahora, solo return.
    GOTO RECUPERAR_CONTEXTO

; =================================================================
; ISR_EMERGENCIA ? se ejecuta con GIE=0 implícito (no se?afecta
;                  por INTE porque ya está dentro de la ISR).
;                  Limpia el flag, corta el motor, enciende LED rojo
;                  y setea FLAG_EMERGENCY.
; =================================================================
ISR_EMERGENCIA
 
    BCF INTCON,INTF

    CLRF CCPR1L
    BCF PORTD,0      ; verde OFF
    BSF PORTD,1      ; rojo ON

    BSF FLAG,1       ; FLAG_EMERGENCY = 1

    GOTO RECUPERAR_CONTEXTO           

    ; 5. (Opcional) forzar envío inmediato de trama UART para que la
    ;    PC se entere de la emergencia. Lo decide la integración.
    ;    BSF     FLAGS, 0      ; FLAG_TX = 1

RECUPERAR_CONTEXTO
    SWAPF STATUS_TEMP,W
    MOVWF STATUS
    SWAPF W_TEMP,F
    SWAPF W_TEMP,W
    
    RETFIE

; =================================================================
; BLOQUE DE TEST ? para probar este esqueleto standalone en MPLABX
; Simulator. Comentar/eliminar al integrar en tpFinal.asm.
; =================================================================
; Para activar:
;   1. Cargar HU04-EMERGENCIA.asm standalone en MPLABX
;   2. Poner stim en RB0 (pin stimulus, flanco descendente)
;   3. Simular ? verificar:
;       - CCPR1L = 0x00
;       - PORTD bit 1 = 1 (rojo ON), bit 0 = 0 (verde OFF)
;       - FLAGS bit 1 = 1
;   4. Simular otro flanco descendente (sin limpiar nada):
;       - El estado debe permanecer (es latch, no toggle)
;   5. Para "liberar" en el test, escribir manualmente:
;       - BCF FLAGS, 1
;       - BSF PORTD, 0 / BCF PORTD, 1
;       - MOVLW 0xFF / MOVWF CCPR1L
;      (En producción esto lo hace HU-06 con 'R')

    END