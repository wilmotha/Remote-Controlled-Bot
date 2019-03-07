;***********************************************************
;*
;*  Transmit
;*
;*	Enter the description of the program here
;*
;*	This is the TRANSMIT skeleton file for Lab 8 of ECE 375
;*
;***********************************************************
;*
;*	 Author: Austin Wilmoth and Donald Joyce
;*	   Date: Enter Date
;*
;***********************************************************

.include "m128def.inc"			; Include definition file

;***********************************************************
;*	Internal Register Definitions and Constants
;***********************************************************
.def	mpr = r16				; Multi-Purpose Register
.def	address = r17
.def	transfer = r18

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

;***********************************************************
;*	Start of Code Segment
;***********************************************************
.cseg							; Beginning of code segment

;***********************************************************
;*	Interrupt Vectors
;***********************************************************
.org	$0000					; Beginning of IVs
		rjmp 	INIT			; Reset interrupt
.org	$0002
		rjmp	MoveForward
.org	$0004
		rjmp	MoveBackward
.org	$0006
		rjmp	TurnRight
.org	$000A
		rjmp	TurnLeft
.org	$000C
		rjmp	Halt_Sub
.org	$000E
		rjmp	Freeze

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

	;I/O Ports
	ldi mpr, (1<<PD3)
	out DDRD, mpr

	ldi mpr, $F7
	out PORTD, mpr

	ldi address, $2A;0b01010101


	;USART1
	;Set baudrate at 2400bps
	ldi mpr, $A0 ;$16 - idk where these came from
	sts UBRR1L, mpr
	ldi mpr, $01 ;$92 - idk where these came from
	sts UBRR1H, mpr

	;Enable transmitter
	ldi mpr, $00
	sts UCSR1A, mpr

	ldi mpr, $08
	sts UCSR1B, mpr
	
	;Set frame format: 8 data bits, 2 stop bits
	ldi mpr, 0b00001110
	sts UCSR1C, mpr

	;Buttons Interupts
	clr mpr
	ldi mpr, 0b00101010
	sts EICRA, mpr
	ldi mpr, 0b00101010
	out EICRB, mpr

	ldi mpr, 0b00110111
	out EIMSK, mpr

	sei
	;Other

;***********************************************************
;*	Main Program
;***********************************************************
MAIN:
		
	;TODO: ???
	rjmp	MAIN

;***********************************************************
;*	Functions and Subroutines
;***********************************************************
MoveForward:
	
	ldi transfer, MovFwd
	
	rcall Transmit

	ldi mpr, $FF
	out EIFR, mpr
	reti

MoveBackward:

	ldi transfer, MovBck
	
	rcall Transmit

	ldi mpr, $FF
	out EIFR, mpr
	reti

TurnRight:

	ldi transfer, TurnR
	
	rcall Transmit

	ldi mpr, $FF
	out EIFR, mpr
	reti

TurnLeft:
	ldi transfer, TurnL
	
	rcall Transmit

	ldi mpr, $FF
	out EIFR, mpr
	reti

Halt_Sub:
	ldi transfer, Halt
	
	rcall Transmit

	ldi mpr, $FF
	out EIFR, mpr
	reti

Freeze:

	reti

Transmit:
	LDS mpr, UCSR1A
	SBRS mpr, UDRE1
	rjmp Transmit
	STS UDR1, address
	
	LDS mpr, UCSR1A
	cbr mpr, TXC1
	sts UCSR1A, mpr

Loop:
	LDS mpr, UCSR1A
	SBRS mpr, UDRE1
	rjmp Loop
	STS UDR1, transfer

	LDS mpr, UCSR1A
	cbr mpr, TXC1
	sts UCSR1A, mpr

	ret

;***********************************************************
;*	Stored Program Data
;***********************************************************

;***********************************************************
;*	Additional Program Includes
;***********************************************************