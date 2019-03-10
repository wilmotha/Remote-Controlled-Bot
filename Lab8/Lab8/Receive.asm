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

.def	address = r17
.def	command = r18

.def	waitcnt = r19			; Wait Loop Counter
.def	ilcnt = r20				; Inner Loop Counter
.def	olcnt = r21				; Outer Loop Counter

.equ	FTime = 255
.equ	WTime = 100				; Time to wait in wait loop

.equ	WskrR = 0				; Right Whisker Input Bit
.equ	WskrL = 1				; Left Whisker Input Bit
.equ	EngEnR = 4				; Right Engine Enable Bit
.equ	EngEnL = 7				; Left Engine Enable Bit
.equ	EngDirR = 5				; Right Engine Direction Bit
.equ	EngDirL = 6				; Left Engine Direction Bit

.equ	BotAddress = $4D;(Enter your robot's address here (8 bits))

;/////////////////////////////////////////////////////////////
;These macros are the values to make the TekBot Move.
;/////////////////////////////////////////////////////////////
.equ	MovFwd =  (1<<EngDirR|1<<EngDirL)	;0b01100000 Move Forward Action Code
.equ	MovBck =  $00						;0b00000000 Move Backward Action Code
.equ	TurnR =   (1<<EngDirL)				;0b01000000 Turn Right Action Code
.equ	TurnL =   (1<<EngDirR)				;0b00100000 Turn Left Action Code
.equ	Halt =    (1<<EngEnR|1<<EngEnL)		;0b10010000 Halt Action Code

.equ	MovFwdC =  ($80|1<<(EngDirR-1)|1<<(EngDirL-1))		;0b10110000 Move Forward Action Code
.equ	MovBckC =  ($80|$00)								;0b10000000 Move Backward Action Code
.equ	TurnRC =   ($80|1<<(EngDirL-1))						;0b10100000 Turn Right Action Code
.equ	TurnLC =   ($80|1<<(EngDirR-1))						;0b10010000 Turn Left Action Code
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
		rjmp	Receive
		; some subroutine?
.org	$0046					; End of Interrupt Vectors
		;rjmp	Receive
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

	ldi mpr, $00
	out PortB, mpr
	

	;USART1
		;Set baudrate at 2400bps
	
	ldi mpr, high(832)
	sts UBRR1H, mpr
	ldi mpr, low(832)
	sts UBRR1L, mpr
	
	ldi mpr, (1<<U2X1)
	sts UCSR1A, mpr

	ldi mpr, (1<<RXCIE1)|(1<<RXEN1)|(1<<TXEN1)
	sts UCSR1B, mpr

	ldi mpr, (1<<USBS1)|(1<<UCSZ11)|(1<<UCSZ10)
	sts UCSR1C, mpr

	;ldi mpr, $A0
	;sts UBRR1L, mpr
	;ldi mpr, $01
	;sts UBRR1H, mpr
		;Enable receiver and enable receive interrupts
	;ldi mpr, 0b10010000
	;sts UCSR1C, mpr
		;Set frame format: 8 data bits, 2 stop bits
	;ldi mpr, 0b00001110
	
	;External Interrupts
		;Set the External Interrupt Mask
	ldi mpr, 0b00000011
	out EIMSK, mpr
		;Set the Interrupt Sense Control to falling edge detection
	ldi mpr, 0b00001010
	sts EICRA, mpr

	sei
	;Other
	ldi XL, low(BUFFER)
	ldi XH, high(BUFFER)
	ldi YL, low(BUFFER)
	ldi YH, high(BUFFER)
	ldi mpr, $00
	st x+, mpr
	st x, mpr
	rcall Resetx

	
;***********************************************************
;*	Main Program
;***********************************************************
MAIN:
	

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

;----------------------------------------------------------------
; Sub:	Wait
; Desc:	A wait loop that is 16 + 159975*waitcnt cycles or roughly 
;		waitcnt*10ms.  Just initialize wait for the specific amount 
;		of time in 10ms intervals. Here is the general eqaution
;		for the number of clock cycles in the wait loop:
;			((3 * ilcnt + 3) * olcnt + 3) * waitcnt + 13 + call
;----------------------------------------------------------------
Wait:
		push	waitcnt			; Save wait register
		push	ilcnt			; Save ilcnt register
		push	olcnt			; Save olcnt register

Loop:	ldi		olcnt, 224		; load olcnt register
OLoop:	ldi		ilcnt, 237		; load ilcnt register
ILoop:	dec		ilcnt			; decrement ilcnt
		brne	ILoop			; Continue Inner Loop
		dec		olcnt		; decrement olcnt
		brne	OLoop			; Continue Outer Loop
		dec		waitcnt		; Decrement wait 
		brne	Loop			; Continue Wait loop	

		pop		olcnt		; Restore olcnt register
		pop		ilcnt		; Restore ilcnt register
		pop		waitcnt		; Restore wait register
		reti				; Return from subroutine

GetFreezed:
	ldi	waitcnt, FTime	; Wait for 1 second
	rcall Wait
	ldi	waitcnt, FTime
	rcall Wait
	ret

Freezer:
	LDS mpr, UCSR1A
	SBRS mpr, UDRE1
	rjmp Freezer
	ldi mpr, 0b01010101
	STS UDR1, mpr

	Loop_2:
		LDS mpr, UCSR1A
		SBRS mpr, TXC1
		rjmp Loop_2
		
		cbr mpr, TXC1
		STS UCSR1A, mpr


	ret

RightBump:
		push	mpr			; Save mpr register
		push	waitcnt			; Save wait register
		in		mpr, SREG	; Save program state
		push	mpr			;

		; Move Backwards for a second
		ldi		mpr, MovBck	; Load Move Backward command
		out		PORTB, mpr	; Send command to port
		ldi		waitcnt, WTime	; Wait for 1 second
		rcall	Wait			; Call wait function

		; Turn left for a second
		ldi		mpr, TurnL	; Load Turn Left Command
		out		PORTB, mpr	; Send command to port
		ldi		waitcnt, WTime	; Wait for 1 second
		rcall	Wait			; Call wait function

		; Move Forward again	
		ldi		mpr, MovFwd	; Load Move Forward command
		out		PORTB, mpr	; Send command to port

		ldi mpr, $FF
		out EIFR, mpr

		pop		mpr		; Restore program state
		out		SREG, mpr	;
		pop		waitcnt		; Restore wait register
		pop		mpr		; Restore mpr
	reti

LeftBump:
	push	mpr			; Save mpr register
		push	waitcnt			; Save wait register
		in		mpr, SREG	; Save program state
		push	mpr			;

		; Move Backwards for a second
		ldi		mpr, MovBck	; Load Move Backward command
		out		PORTB, mpr	; Send command to port
		ldi		waitcnt, WTime	; Wait for 1 second
		rcall	Wait			; Call wait function

		; Turn right for a second
		ldi		mpr, TurnR	; Load Turn Left Command
		out		PORTB, mpr	; Send command to port
		ldi		waitcnt, WTime	; Wait for 1 second
		rcall	Wait			; Call wait function

		; Move Forward again	
		ldi		mpr, MovFwd	; Load Move Forward command
		out		PORTB, mpr	; Send command to port
		
		ldi mpr, $FF
		out EIFR, mpr

		pop		mpr		; Restore program state
		out		SREG, mpr	;
		pop		waitcnt		; Restore wait register
		pop		mpr		; Restore mpr
		reti

Receive:

	lds mpr, UDR1
	st X, mpr
	
	lds mpr, UCSR1A
	cbr mpr, RXC1
	STS UCSR1A, mpr
	
	ld r3, X
	ldi mpr, BotAddress

	cp mpr, r3
	brne Skip
	
Rec2:	
	lds   mpr,    UCSR1A
	sbrs  mpr,    RXC1
	rjmp  Rec2
	lds   mpr,    UDR1
	st    X,      mpr
	lds   mpr,    UCSR1A
	cbr   mpr,    RXC1
	sts   UCSR1A, mpr
	rcall Commands


Skip:
	ldi mpr, 0b01010101
	cp mpr, r3
	brne Skip3
	rcall GetFreezed

Skip3:
	reti
	
ResetX:
	;mov XL, YL
	;mov XH, XH
	ldi XL, low(BUFFER)
	ldi XH, high(BUFFER)
	ret

Commands:
	
	ld mpr, x

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
	brne Skip2
	rcall Halt_Sub
Skip2:
	rcall ResetX
ret
;***********************************************************
;*	Stored Program Data
;***********************************************************
.dseg
.org $0100
BUFFER:
.byte	4

;***********************************************************
;*	Additional Program Includes
;***********************************************************
