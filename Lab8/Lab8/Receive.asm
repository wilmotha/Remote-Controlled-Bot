;***********************************************************
;*
;*	Receive
;*
;*	Enter the description of the program here
;*
;*	This is the RECEIVE skeleton file for Lab 8 of ECE 375
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

.equ	WskrR = 0				; Right Whisker Input Bit
.equ	WskrL = 1				; Left Whisker Input Bit
.equ	EngEnR = 4				; Right Engine Enable Bit
.equ	EngEnL = 7				; Left Engine Enable Bit
.equ	EngDirR = 5				; Right Engine Direction Bit
.equ	EngDirL = 6				; Left Engine Direction Bit

.equ	BotAddress = 0b01010101;(Enter your robot's address here (8 bits))

;/////////////////////////////////////////////////////////////
;These macros are the values to make the TekBot Move.
;/////////////////////////////////////////////////////////////
.equ	MovFwd =  (1<<EngDirR|1<<EngDirL)	;0b01100000 Move Forward Action Code
.equ	MovBck =  $00						;0b00000000 Move Backward Action Code
.equ	TurnR =   (1<<EngDirL)				;0b01000000 Turn Right Action Code
.equ	TurnL =   (1<<EngDirR)				;0b00100000 Turn Left Action Code
.equ	Halt =    (1<<EngEnR|1<<EngEnL)		;0b10010000 Halt Action Code

.equ	MovFwdC =  ($80|1<<(EngDirR-1)|1<<(EngDirL-1))	;0b10110000 Move Forward Action Code
.equ	MovBckC =  ($80|$00)								;0b10000000 Move Backward Action Code
.equ	TurnRC =   ($80|1<<(EngDirL-1))					;0b10100000 Turn Right Action Code
.equ	TurnLC =   ($80|1<<(EngDirR-1))					;0b10010000 Turn Left Action Code
.equ	HaltC =    ($80|1<<(EngEnR-1)|1<<(EngEnL-1))		;0b11001000 Halt Action Code

;***********************************************************
;*	Start of Code Segment
;***********************************************************
.cseg							; Beginning of code segment

;***********************************************************
;*	Interrupt Vectors
;***********************************************************
.org	$0000					; Beginning of IVs
		rjmp 	INIT			; Reset interrupt

;Should have Interrupt vectors for:
;- Left whisker
.org	$0002
		rjmp	LeftBump
;- Right whisker
.org	$0004
		rjmp	RightBump
;- USART receive
.org	$003C
		; some subroutine?
.org	$0046					; End of Interrupt Vectors
		rjmp	Receive
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
	ldi mpr, (0<<PD0)|(0<<PD1)|(0<<PD2)
	out DDRD, mpr

	ldi mpr, $03
	out PORTD, mpr

	ldi mpr, $FF
	out DDRB, mpr
	

	;USART1
		;Set baudrate at 2400bps
	ldi mpr, $A0
	sts UBRR1L, mpr
	ldi mpr, $01
	sts UBRR1H, mpr
		;Enable receiver and enable receive interrupts
	ldi mpr, 0b10010000
	sts UCSR1C, mpr
		;Set frame format: 8 data bits, 2 stop bits
	ldi mpr, 0b00001110
	
	;External Interrupts
		;Set the External Interrupt Mask
	ldi mpr, 0b00000011
	out EIMSK, mpr
		;Set the Interrupt Sense Control to falling edge detection
	ldi mpr, 0b00001010
	sts EICRA, mpr

	;Other
	ldi XL, low(BUFFER)
	ldi XH, high(BUFFER)
	ldi YL, low(BUFFER)
	ldi YH, high(BUFFER)
	
;***********************************************************
;*	Main Program
;***********************************************************
MAIN:
	
	ld mpr, Y
	cpi mpr, BotAddress
	brne Main
	rcall ResetX
	ldd mpr, Y+1
	
	cpi mpr, MovFwdC
	brne Bck
	rcall MoveForward
Bck:
	cpi mpr, MovBckC
	brne TrnR
	rcall MoveBackward

TrnR:
	cpi mpr, TurnRC
	brne TrnL
	rcall TurnRight

TrnL:
	cpi mpr, TurnLC
	brne Hlt
	rcall TurnLeft

Hlt:
	cpi mpr, HaltC
	brne Main
	rcall Halt_Sub

	rjmp	MAIN

;***********************************************************
;*	Functions and Subroutines
;***********************************************************
MoveForward:
	ldi mpr, MovFwd
	out PORTB, mpr
	ret

MoveBackward:
	ldi mpr, MovBck
	out PORTB, mpr
	ret

TurnRight:
	ldi mpr, TurnR
	out PORTB, mpr
	ret

TurnLeft:
	ldi mpr, TurnL
	out PORTB, mpr
	ret

Halt_Sub:
	ldi mpr, Halt
	out PORTB, mpr
	ret

Freeze:

	ret

RightBump:

	reti

LeftBump:
	
	reti

Receive:
	push mpr
	
	lds mpr, UDR1
	st X+, mpr
;	cpi mpr, BotAddress
;	brne Skip
;	lds command, UDR1
;Skip:
	pop mpr
	reti
	
ResetX:
	ldi XL, low(BUFFER)
	ldi XH, high(BUFFER)
	ret
;***********************************************************
;*	Stored Program Data
;***********************************************************
.dseg
.org $0100
BUFFER:
.byte	2

;***********************************************************
;*	Additional Program Includes
;***********************************************************
