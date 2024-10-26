* Inicializa el SP y el PC
**************************
        ORG     $0
        DC.L    $8000           * Pila
        DC.L    INICIO          * PC

        ORG     $400
INCLUDE bib_aux.s

* Definicion de equivalencias
*********************************

MR1A    EQU     $effc01       * de modo A (escritura)
MR2A    EQU     $effc01       * de modo A (2 escritura)
SRA     EQU     $effc03       * de estado A (lectura)
CSRA    EQU     $effc03       * de seleccion de reloj A (escritura)
CRA     EQU     $effc05       * de control A (escritura)
TBA     EQU     $effc07       * buffer transmision A (escritura)
RBA     EQU     $effc07       * buffer recepcion A  (lectura)
ACR     EQU     $effc09       * de control auxiliar
IMR     EQU     $effc0B       * de mascara de interrupcion A (escritura)
ISR     EQU     $effc0B       * de estado de interrupcion A (lectura)
IVR 	EQU 	$effc19       *	del vector de interrupcion
MR1B    EQU     $effc11       * de modo B (escritura)
MR2B    EQU     $effc11       * de modo B (2 escritura)
CRB     EQU     $effc15       * de control A (escritura)
TBB     EQU     $effc17       * buffer transmision B (escritura)
RBB     EQU     $effc17       * buffer recepcion B (lectura)
SRB     EQU     $effc13       * de estado B (lectura)
CSRB    EQU     $effc13       * de seleccion de reloj B (escritura)

CR      EQU     $0D           * Carriage Return
LF      EQU     $0A           * Line Feed
FLAGT   EQU     2             * Flag de transmision
FLAGR   EQU     0             * Flag de recepcion


**************************** INIT *************************************************************
INIT:
        MOVE.B      #%00010000,CRA      * Reinicia el puntero MR1
        MOVE.B      #%00000011,MR1A     * 8 bits por caracter.
        MOVE.B      #%00000000,MR2A     * Eco desactivado.
        MOVE.B      #%11001100,CSRA     * Velocidad = 38400 bps.
        MOVE.B      #%00000000,ACR      * Velocidad = 38400 bps.
        MOVE.B      #%00000101,CRA      * Transmision y recepcion activados.

        MOVE.B      #%00010000,CRB      * Reinicia el puntero MR1
        MOVE.B      #%00000011,MR1B		* 8 bits por caracter.
        MOVE.B      #%00000000,MR2B 	* Eco desactivado.
        MOVE.B      #%11001100,CSRB     * Velocidad = 38400 bps.
        MOVE.B      #%00000101,CRB      * Transmision y recepcion activados. 

        MOVE.B  	#%00100010,IMR_Actual 	* Habilitacion de interrupciones de recepción
        MOVE.B  	#%00100010,IMR	* (TODO)
        MOVE.B  	#$40,IVR			* Vector de Interrucion = 0x40
        MOVE.L  	#RTI,256			* Estableciendo en la tabla de interrupciones
        BSR			INI_BUFS			* Inicializacion de los bufferes internos

        RTS
**************************** FIN INIT *********************************************************
IMR_Actual: 	DC.B 	0

**************************** PRINT ************************************************************
PRINT:	LINK		A6,#-2
		MOVEM.L 	A0/D1-D2,-(A7)
		* A6: -2 -> contador;        0 -> FP anterior;
		*	   4 -> return address;  8 -> buffer
		*     12 -> Descriptor;     14 -> Tamaño
		*; Verificar si descriptor es correcto
		CMPI.W		#$02,12(A6) *; descriptor >= 2 (sin signo)
		BHS 		PRERR   *; => error
		* Inicializamos contador:
		MOVE.W 		#0,-2(A6)
PRLOOP:
		MOVE.W 		-2(A6),D2 *; D2: contador
		CMP.W 		14(A6),D2 *; D2 >= Tamaño
		BHS 		PRENDLP
		*; Si contador < Tamaño:
		EOR.L		D0,D0
		MOVE.W 		12(A6),D0 * Debe ser 0 o 1
		ADD.L 		#%00000010,D0
		MOVE.L 		8(A6),A0
		MOVE.B  	(A0)+,D1 *; Obtenemos caracter
		MOVE.L 		A0,8(A6) *;
		BSR 		ESCCAR 
		*; D0 == 0xffffffff?
		CMP.L 		#-1,D0 *;
		BEQ 		PRENDLP *; Termina operacion
		*; 
		ADDI 		#1,-2(A6)
		JMP 		PRLOOP
PRENDLP:
		EOR.L 		D0,D0
		MOVE.W 		-2(A6),D0 
		CMP.W 		#0,D0 * Contador == 0?
		BEQ 		PRINTFIN * => no hacer nada
		* sino Debemos de activar TxRdyA o TxRdyB:
		*;
		MOVE.B		IMR_Actual,D2
		MOVE.W 		12(A6),D1
		BTST 		#0,D1 *; Si descriptor es cero
		BEQ 		PRDZ

		OR.B 		#$10,D2 *; Linea B se activa interrupcion
		JMP 		PRNEWIMR
PRDZ: *; Print_Descriptor Zero:
		OR.B 		#$01,D2 *; Linea A se activa interrupcion
PRNEWIMR: *; Actualizar interrupciones:
		MOVE.B 		D2,IMR_Actual
		MOVE.B 		D2,IMR

		JMP 		PRINTFIN
PRERR:
		MOVE.L 		#$FFFFFFFF,D0
PRINTFIN:
		MOVEM.L 	(A7)+,A0/D1-D2
		UNLK		A6
        RTS
**************************** FIN PRINT ********************************************************

**************************** SCAN *************************************************************
SCAN:	LINK		A6,#-2
		MOVEM.L 	A0/D2,-(A7)
		* A6: -2 -> contador;        0 -> FP anterior;
		*	   4 -> return address;  8 -> buffer
		*     12 -> Descriptor;     14 -> Tamaño
		*; verificamos que el descriptor no sea incorrecto (no es 0 o 1)
		CMP.W		#$02,12(A6) *; descriptor >= 2 (sin signo)
		BHS 		SCERR   *; => error
		*; En este punto, los unicos valores posibles en 12(A6) son 0 y 1
		MOVE.W		#$00,-2(A6) *; iniciamos contador
SCLOOP:
		MOVE.W 		-2(A6),D2
		CMP.W		14(A6),D2 *; Si contador >= tamaño(sin signo)
		BHS 		SCFINL   *; finaliza contador
		*; Leemos buffer desde LEECar:
		EOR.L 		D0,D0
		MOVE.W 		12(A6),D0 * Debe ser 0 o 1
		BSR 		LEECAR 
		*; Si D0 == 0xFFFFF
		CMP.L 		#-1,D0 *;
		BEQ 		SCFINL *; Termina operacion 
		*; sino es un numero entre 0 y 255 (byte). Copiamos byte
		MOVE.L 		8(A6),A0 *; Obtenemos direccion del buffer
		MOVE.B 		D0,(A0)+ *; Copiamos en buffer e incrementamos direccion
		MOVE.L		A0,8(A6) *; Actualizamos direccion en pila
		ADDI 		#$1,-2(A6) *; Incrementamos contador
		*; Saltamos
		BRA.S 		SCLOOP *;
		******** Fin SCAN_loop *******
SCFINL:
		EOR.L 		D0,D0
		MOVE.W 		-2(A6),D0
		JMP 		SCANEND
SCERR:
		MOVE.L 		#$FFFFFFFF,D0
SCANEND:
		MOVEM.L 	(A7)+,A0/D2
		UNLK 		A6
        RTS

**************************** FIN SCAN *********************************************************

**************************** RTI **************************************************************

RTI:
		MOVEM.L		A0/D0-D2,-(A7)
	*; Enmascarar ISR/IMR
		MOVE.B		ISR,D2
		AND.B 		IMR_Actual,D2
	*; Identificar el tipo de interrupcion
		BTST 		#1,D2 * RxRDYA
		BNE 		RTI_RxA
		BTST 		#5,D2 * RxRDYB
		BNE 		RTI_RxB
		BTST 		#0,D2 * TxRDYA
		BNE 		RTI_TxA
		BTST 		#4,D2 * TxRDYB
		BNE 		RTI_TxB
	*; No debería llegar a esta instruccion, pero:
		JMP 		RTI_FIN
RTI_RxA: ***************** Tratamiento Rx ******************
		MOVE.W 		#0,D0 	*; Cargar operacion en D0 
		MOVE.B 		RBA,D1 	*; Cargar Dato recibido en A
		JMP 		RTI_Rx
RTI_RxB:
		MOVE.W 		#1,D0 	*; Cargar operacion en D0 
		MOVE.B 		RBB,D1 	*; Cargar Dato recibido en B
RTI_Rx:
		BSR 		ESCCAR 	*; Llamar ESCCAR (leer)
	*; Si D0 == -1, el valor no se guardó y se pierde
		*CMP.L 		#-1,D0 *;
	*; D0 se ignora si
		JMP 		RTI_FIN
		 ***************** Fin Tratamiento Rx **************
RTI_TxA: ***************** Tratamiento Tx ******************
		MOVE.B 		#%11111110,-(A7) * Mascara
		MOVE.L 		#TBA,-(A7) * Direccion del buffer Tx
		MOVE.W 		#2,D0   *; Cargar operacion en D0
		JMP 		RTI_Tx
RTI_TxB:
		MOVE.B 		#%11101111,-(A7) * Mascara
		MOVE.L 		#TBB,-(A7) * Direccion del buffer Tx
		MOVE.W 		#3,D0   *; Cargar operacion en D0
RTI_Tx:
		BSR 		LEECAR	*; llamar LEECar

		MOVE.L 		(A7)+,A0 *;TBA o TBB
		MOVE.B 		(A7)+,D1 *; Obtener mascara de pila
		CMP.L 		#-1,D0	*; está vacio?
		BEQ 		RTI_NOINT *; Si es distinto, no hacer mas nada
		MOVE.B 		D0,(A0) *; Escribir en puerto TX
		* MOVE.B 		* Procesar
		JMP 		RTI_FIN
RTI_NOINT: *; Si buffer vacio:
	*; - Se desactiva la interrupcion TxRdy respectiva
		MOVE.B		IMR_Actual,D2
		AND.B		D1,D2 *; Enmascarado para desactivar
		MOVE.B		D2,IMR_Actual
		MOVE.B		D2,IMR
		 ***************** Fin Tratamiento Tx **************
RTI_FIN:
		MOVEM.L (A7)+,A0/D0-D2
		RTE
**************************** FIN RTI **********************************************************

**************************** PROGRAMA PRINCIPAL ***********************************************
BUFFER:	DS.B	2100 	* Buffer para lectura y escritura de caracteres
PARDIR:	DC.L 	0		* Dirección que se pasa como parámetro
PARTAM:	DC.W	0		* Tamaño que se pasa como parámetro
CONTC:	DC.W 	0		* Contador de caracteres a imprimir
DESA:	EQU 	0		* Descriptor lı́nea A
DESB:	EQU 	1		* Descriptor lı́nea B
TAMBS:	EQU 	30		* Tamaño de bloque para SCAN
TAMBP:	EQU 	7		* Tamaño de bloque para PRINT

		* Manejadores de excepciones
* Manejadores de excepciones
INICIO:	MOVE.L	#BUS_ERROR,8	* Bus error handler
		MOVE.L	#ADDRESS_ER,12	* Address error handler
		MOVE.L	#ILLEGAL_IN,16	* Illegal instruction handler
		MOVE.L	#PRIV_VIOLT,32	* Privilege violation handler
		MOVE.L	#ILLEGAL_IN,40	* Illegal instruction handler
		MOVE.L	#ILLEGAL_IN,44	* Illegal instruction handler
		
		BSR 	INIT 			* Inicia el controlador
		MOVE.W	#$2000,SR 		* Permite interrupciones

BUCPR:	MOVE.W	#TAMBS,PARTAM	* Inicializa parámetro de tamaño
		MOVE.L	#BUFFER,PARDIR	* Parámetro BUFFER = comienzo del buffer
OTRAL:	MOVE.W	PARTAM,-(A7)	* Tamaño de bloque
		MOVE.W 	#DESA,-(A7)		* Puerto A
		MOVE.L	PARDIR,-(A7)	* Dirección de lectura
ESPL:	BSR 	SCAN
		ADD.L	#8,A7			* Restablece la pila
		ADD.L	D0,PARDIR		* Calcula la nueva dirección de lectura
		SUB.W	D0,PARTAM		* Actualiza el número de caracteres leı́dos
		BNE 	OTRAL			* Si no se han leı́do todas los caracteres
								* del bloque se vuelve a leer
		MOVE.W	#TAMBS,CONTC	* Inicializa contador de caracteres a imprimir
		MOVE.L	#BUFFER,PARDIR	* Parámetro BUFFER = comienzo del buffer
OTRAE:	MOVE.W	#TAMBP,PARTAM	* Tamaño de escritura = Tamaño de bloque
ESPE:	MOVE.W	PARTAM,-(A7)	* Tamaño de escritura
		MOVE.W	#DESB,-(A7)		* Puerto B
		MOVE.L	PARDIR,-(A7) 	* Dirección de escritura
		BSR 	PRINT 			
		ADD.L	#8,A7			* Restablece la pila
		ADD.L	D0,PARDIR		* Calcula la nueva dirección del buffer
		SUB.W	D0,CONTC 		* Actualiza el contador de caracteres
		BEQ 	SALIR			* Si no quedan caracteres se acaba
		SUB.W	D0,PARTAM		* Actualiza el tamaño de escritura
		BNE 	ESPE			* Si no se ha escrito todo el bloque se insiste
		CMP.W	#TAMBP,CONTC	* Si el no de caracteres que quedan es menor que
								* el tamaño establecido se imprime ese número
		BHI 	OTRAE			* Siguiente bloque
		MOVE.W 	CONTC,PARTAM
		BRA 	ESPE			* Siguiente bloque

SALIR:  BRA 	BUCPR

BUS_ERROR:		BREAK			* Bus error handler
				NOP
ADDRESS_ER:		BREAK			* Address error handler
				NOP
ILLEGAL_IN:		BREAK			* Illegal instruction handler
				NOP
PRIV_VIOLT:		BREAK			* Privilege violation handler
				NOP




* OTRO:   MOVE.W        #TAMANO,-(A7)
* 		MOVE.L          #$5000,-(A7)        * Prepara la direccion del buffer
*         BSR             SCAN                * Recibe la linea
*         ADD.L           #6,A7               * Restaura la pila
*       MOVE.W          #TAMANO,-(A7)
*         MOVE.L          #$5000,-(A7)        * Prepara la direccion del buffer
*         BSR             PRINT               * Imprime linea
*         ADD.L           #6,A7               * Restaura la pila
*       BRA             OTRO

        BREAK
**************************** FIN PROGRAMA PRINCIPAL ******************************************
