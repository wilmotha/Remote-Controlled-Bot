;***********************************************************
;*
;*  Transmit
;*
;*	This Program is used to send commands from one AVR board
;*
;*	to another that is programed to controll a robot
;*
;***********************************************************
;*
;*	 Author: Austin Wilmoth and Donald Joyce
;*	   Date: March 11, 2019
;*
;***********************************************************

.include "m128def.inc"			; Include definition file

;***********************************************************
;*	Internal Register Definitions and Constants
;***********************************************************
.def	mpr = r16				; Multi-Purpose Register
.def	address = r17			; holds the bot address
.def	transfer = r18			; holds the command to be transfered

.equ	EngEnR = 4				; Right Engine Enable Bit
.equ	EngEnL = 7				; Left Engine Enable Bit
.equ	EngDirR = 5				; Right Engine Direction Bit
.equ	EngDirL = 6				; Left Engine Direction Bit


; Use these action codes between the remote and robot
; MSB = 1 thus:
; control signals are shifted right by one and ORed with 0b10000000 = $80
.equ	MovFwd =  ($80|1<<(EngDirR-1)|1<<(EngDirL-1))	;0b10110000 Move Forward Action Code
.equ	MovBck =  ($80|$00)								;0b10000000 Move Backward Action Code
.equ	TurnR =   ($80|1<<(EngDirL-1))					;0b10100000 Turn Right Action Code
.equ	TurnL =   ($80|1<<(EngDirR-1))					;0b10010000 Turn Left Action Code
.equ	Halt =    ($80|1<<(EngEnR-1)|1<<(EngEnL-1))		;0b11001000 Halt Action Code
.equ	Freeze =  0b11111000		                    ;0b11111000 Freeze Action Code
;***********************************************************
;*	Start of Code Segment
;***********************************************************
.cseg							; Beginning of code segment

;***********************************************************
;*	Interrupt Vectors
;***********************************************************
.org	$0000					; Beginning of IVs
		rjmp 	INIT			; Reset interrupt

.org	$0046					; End of Interrupt Vectors

;***********************************************************
;*	Program Initialization
;***********************************************************
INIT:
	;Stack Pointer (VERY IMPORTANT!!!!)
	ldi mpr, high(RAMEND)
	out sph, mpr
	ldi mpr, low(RAMEND)
	out spl, mpr

	;Ports
	ldi mpr, $FF	; B is set up for output to be able to control 
	out DDRB, mpr	; the lights, for testing

	ldi mpr, $00	; D is set up for input to both take in button
	out DDRD, mpr	; presses and to recive the TXD1 interupt

	ldi mpr, $FF	; PortD is set to all ones as the buttons are
	out PortD, mpr	; passive

	ldi address, $4D	; this is the bot address


	;USART1
	;Set baudrate at 2400bps
	ldi mpr, high(832)
	sts UBRR1H, mpr
	ldi mpr, low(832)
	sts UBRR1L, mpr

	;Enable transmitter 
	ldi mpr, (1<<U2X1)	; sets to double boadrate
	sts UCSR1A, mpr

	ldi mpr, (1<<TXEN1) ; set to enable transmition
	sts UCSR1B, mpr

	;Set frame format: 8 data bits, 2 stop 
	ldi mpr, (1<<USBS1)|(1<<UCSZ11)|(1<<UCSZ10)
	sts UCSR1C, mpr

	sei					; enable interupts
	
;***********************************************************
;*	Main Program
;***********************************************************
MAIN
	in mpr, PIND			; read in from the buttons
	cpi mpr, 0b11111110		; check if the button 0 is pressed
	brne Bck
	rcall MoveForward		
	rjmp	MAIN
Bck:
	cpi mpr, 0b11111101		; check if button 1 is pressed
	brne TrnR
	rcall MoveBackward
	rjmp	MAIN

TrnR:
	cpi mpr, 0b11101111		; check if button 4 is pressed
	brne TrnL				; skip 2 and 3 as the are used by USART
	rcall TurnRight
	rjmp	MAIN
TrnL:
	cpi mpr, 0b11011111		; check if button 5 is pressed
	brne Hlt
	rcall TurnLeft
	rjmp	MAIN
Hlt:
	cpi mpr, 0b10111111		; check if button 6 is pressed
	brne Fre
	rcall Halt_Sub
	rjmp	MAIN
Fre:
	cpi mpr, 0b01111111		; check if button 7 is pressed
	brne Skip2
	rcall Freeze_sub
	rjmp Main				
Skip2:
	
	rjmp	MAIN			; otherwise start over

;***********************************************************
;*	Functions and Subroutines
;***********************************************************
;----------------------------------------------------------------
; Sub: MoveForward
; Desc: Sets the code to be transfered to be the code to move the
;       the bot forward	
;----------------------------------------------------------------
MoveForward:
	ldi transfer, MovFwd		
	rcall Transmit
	
	ret

;----------------------------------------------------------------
; Sub: MoveBackwards
; Desc: Sets the code to be transfered to be the code to move the
;       the bot backwards	
;----------------------------------------------------------------
MoveBackward:
	ldi transfer, MovBck
	rcall Transmit

	ret

;----------------------------------------------------------------
; Sub: TurnRight
; Desc: Sets the code to be transfered to be the code to make the
;       bot turn right 	
;----------------------------------------------------------------
TurnRight:
	ldi transfer, TurnR
	rcall Transmit

	ret

;----------------------------------------------------------------
; Sub: TurnLeft
; Desc: Sets the code to be transfered to be the code to make the
;       bot turn Left 	
;----------------------------------------------------------------
TurnLeft:
	ldi transfer, TurnL
	rcall Transmit

	ret
;----------------------------------------------------------------
; Sub: Halt_Sub
; Desc: Sets the code to be transfered to be the code to make the
;       bot stop moving	
;----------------------------------------------------------------
Halt_Sub:
	ldi transfer, Halt
	rcall Transmit
	
	ret

;----------------------------------------------------------------
; Sub: Freeze_Sub
; Desc: Sets the code to be transfered to be the code to make the
;       bot send out the freeze command to other bots 	
;----------------------------------------------------------------
Freeze_sub:
	ldi transfer, Freeze
	rcall Transmit

	ret

;----------------------------------------------------------------
; Sub: Transmit
; Desc: Sends both the address of the bot and the command that is
;       to be done by the bot
;----------------------------------------------------------------
Transmit:
	LDS mpr, UCSR1A		; check that the transmit buffer is empty
	SBRS mpr, UDRE1
	rjmp Transmit		; if not loop 
	
	STS UDR1, address	; if so put the address into UDR1 to be sent

	Loop_1:
		LDS mpr, UCSR1A		; check again that the transmit buffer if
		SBRS mpr, UDRE1		; empty meaning that the first thing is sent
		rjmp Loop_1
		
		STS UDR1, transfer	; if it is send that command

	Loop_2:
		LDS mpr, UCSR1A		; check if the data has finished transmiting
		SBRS mpr, TXC1
		rjmp Loop_2
		
		cbr mpr, TXC1		; if so clear the finished bit 
		STS UCSR1A, mpr


	ret

;***********************************************************
;*	Stored Program Data
;***********************************************************

;***********************************************************
;*	Additional Program Includes
;***********************************************************