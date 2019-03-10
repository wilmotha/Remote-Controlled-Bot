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
.org	$000A
		rjmp	TurnRight
.org	$000C
		rjmp	TurnLeft
.org	$000E
		rjmp	Halt_Sub
.org	$0010
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

	ldi mpr, $FF
	out DDRB, mpr

	ldi mpr, $00
	out DDRD, mpr

	ldi mpr, $FF
	out PortD, mpr

	ldi address, $4D;0b01010101


	;USART1
	;Set baudrate at 2400bps
	
	ldi mpr, high(832)
	sts UBRR1H, mpr
	ldi mpr, low(832)
	sts UBRR1L, mpr

	;Enable transmitter
	ldi mpr, (1<<U2X1)
	sts UCSR1A, mpr

	ldi mpr, (1<<TXEN1)
	sts UCSR1B, mpr

	
	;Set frame format: 8 data bits, 2 stop bits
	
	ldi mpr, (1<<USBS1)|(1<<UCSZ11)|(1<<UCSZ10)
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

	Loop_1:
		LDS mpr, UCSR1A
		SBRS mpr, UDRE1
		rjmp Loop_1
		STS UDR1, transfer
		;out portb, transfer; test

	Loop_2:
		LDS mpr, UCSR1A
		SBRS mpr, TXC1
		rjmp Loop_2
		
		cbr mpr, TXC1
		STS UCSR1A, mpr


	ret

;***********************************************************
;*	Stored Program Data
;***********************************************************

;***********************************************************
;*	Additional Program Includes
;***********************************************************