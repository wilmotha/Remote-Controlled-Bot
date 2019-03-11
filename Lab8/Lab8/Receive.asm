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
.equ	FreezeC = 0b11111000
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
	ldi mpr, (0<<PD0)|(0<<PD1)|(0<<PD2)	;This sets up the buttons for input for the two interrupts and PD2 is for the Recieve interrupt for USART. 
	out DDRD, mpr	;the value is loaded into DDRD to set the port as input

	ldi mpr, $03	; This set the port for input
	out PORTD, mpr

	ldi mpr, $FF	;Sets DDRB as output
	out DDRB, mpr

	ldi mpr, $00	;sets Port b as output which lets the led be turned on
	out PortB, mpr
	

	;USART1
		;Set baudrate at 2400bps
	
	ldi mpr, high(832)	;set the baud rate using the double baud rate equation
	sts UBRR1H, mpr
	ldi mpr, low(832)
	sts UBRR1L, mpr
	
	ldi mpr, (1<<U2X1)	;sets the baud rate bit 
	sts UCSR1A, mpr

	ldi mpr, (1<<RXCIE1)|(1<<RXEN1)|(1<<TXEN1)	;sets the Receive enable and transmit enable and receive interrupt enable
	sts UCSR1B, mpr

	ldi mpr, (1<<USBS1)|(1<<UCSZ11)|(1<<UCSZ10)	;sets the 8 bit rate and 2 stop bits
	sts UCSR1C, mpr

	;External Interrupts
		;Set the External Interrupt Mask
	ldi mpr, 0b00000011		;set up the two buttons as inputs or as bumpers
	out EIMSK, mpr
		;Set the Interrupt Sense Control to falling edge detection
	ldi mpr, 0b00001010		;set up the two buttons interrupts as falling edge detection
	sts EICRA, mpr

	sei
	;Other
	ldi XL, low(BUFFER)		;set up X and Y to point to the buffer which stores the value that is received
	ldi XH, high(BUFFER)
	ldi YL, low(BUFFER)
	ldi YH, high(BUFFER)
	ldi mpr, $00
	st x+, mpr				;clears the value in the buffer
	st x, mpr
	rcall Resetx			;resets the value that x pointing to

	
;***********************************************************
;*	Main Program
;***********************************************************
MAIN:
	

	rjmp	MAIN			;infinity loops so that it waits for just the interrupts

;***********************************************************
;*	Functions and Subroutines
;***********************************************************
MoveForward:
	ldi mpr, MovFwd			;loads the value of the command into port B
	out PORTB, mpr
	ret

MoveBackward:				
	ldi mpr, MovBck			;loads the value of the command into port B
	out PORTB, mpr
	ret

TurnRight:
	ldi mpr, TurnR			;loads the value of the command into port B
	out PORTB, mpr
	ret

TurnLeft:
	ldi mpr, TurnL			;loads the value of the command into port B
	out PORTB, mpr
	ret

Halt_Sub:
	ldi mpr, Halt			;loads the value of the command into port B
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
	push address
	in address, PORTB
	rcall Halt_Sub

	ldi	waitcnt, FTime	; Wait for 1 second
	rcall Wait
	ldi	waitcnt, FTime
	rcall Wait

	out PORTB, address
	pop address
	ret

Freezer:		;this function transmits the freeze value is tranmitted to the other bots
	;ldi mpr, 0b11111111 ;remove this just for testing
	;out PORTB, mpr

	LDS mpr, UCSR1A			;loads the value UCSR1A into mpr
	SBRS mpr, UDRE1			;checks if the UDRE1 bit says that the buffer is cleared
	rjmp Freezer			;if it is not cleared then it keeps looping until the it is
	ldi mpr, 0b01010101		;if the buffer is cleared then the command is loaded into UDR1 to be transmitted
	STS UDR1, mpr			
	
	Loop_2:
		LDS mpr, UCSR1A		;checks if the transmit is done 
		SBRS mpr, TXC1
		rjmp Loop_2			; if the transmit is not done then it loops until it is
		
		cbr mpr, TXC1		;clears the transmit bit in UCSR1A
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

	lds mpr, UDR1		;loads the received value into the buffer
	st X, mpr
	
	lds mpr, UCSR1A		;clears the receive done bit in UCSR1A
	cbr mpr, RXC1
	STS UCSR1A, mpr
	
	ld r3, X			;checks if the botID is correct one
	ldi mpr, BotAddress

	cp mpr, r3			;if the other botID is not correct it jumps to Skip
	brne Skip
	
Rec2:	
	lds   mpr,    UCSR1A		;checks if the RXC1 bits which means it is done receive is done recieving
	sbrs  mpr,    RXC1
	rjmp  Rec2					;if it is not done then it loops until it is
	lds   mpr,    UDR1			;loads the value into the memory buffer
	st    X,      mpr
	lds   mpr,    UCSR1A
	cbr   mpr,    RXC1			;sets the bit so it is cleared meaning it is not done receiving
	sts   UCSR1A, mpr			
	rcall Commands				;calls command to see if which command was called


Skip:
	ldi mpr, 0b01010101			;if the wrong botID is received it checks if the freeze command was received
	cp mpr, r3
	brne Skip3					;if it was not received then it skips to Skip3
	rcall GetFreezed

Skip3:
	reti						;returns to main to wait again
	
ResetX:
	;mov XL, YL
	;mov XH, XH
	ldi XL, low(BUFFER)			;resets the X value to initial value that it was set to 
	ldi XH, high(BUFFER)
	ret

Commands:
	
	ld mpr, x					;loads the value in the memory buffer

	cpi mpr, MovFwdC			;checks if the value means MovFwd command is called
	brne Bck					;if it is not then skips to check the next one
	rcall MoveForward			
Bck:
	cpi mpr, MovBckC			;checks if the value means MovBck command is called
	brne TrnR					;if it is not then skips to check the next one
	rcall MoveBackward			

TrnR:
	cpi mpr, TurnRC				;checks if the value means TurnR command is called
	brne TrnL					;if it is not then skips to check the next one
	rcall TurnRight

TrnL:
	cpi mpr, TurnLC				;checks if the value means TurnL command is called
	brne Hlt					;if it is not then skips to check the next one
	rcall TurnLeft
Hlt:
	cpi mpr, HaltC				;checks if the value means Halt command is called
	brne Fre					;if it is not then it skips to check the next one
	rcall Halt_Sub
Fre:
	cpi mpr, FreezeC			;checks if the value means Freeze command is called
	brne Skip2					;if it is not then it skips to check the next one
	rcall Freezer
Skip2:
	rcall ResetX				;resets x to point to the memory buffer
ret
;***********************************************************
;*	Stored Program Data
;***********************************************************
.dseg
.org $0100
BUFFER:							;memory buffer
.byte	4

;***********************************************************
;*	Additional Program Includes
;***********************************************************
