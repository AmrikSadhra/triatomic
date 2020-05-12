;---------------------------------------------------------------------
;		_general.inc		21:04:28  26-May-2002
;
;				collection of gerneral used proc`s
;---------------------------------------------------------------------
					    ; for CauseWay Extender
;---------------------------------------------------------------------

		.DATA

;---------------------------------------------------------------------

;---------------------------------------------------------------------

		.CODE

;---------------------------------------------------------------------

;==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-

read_file	PROC	    near	; Read some data from a file.

;On Entry:-

;BX	- Handle
;ECX	- Length
;EDI	- Position.

		mov	    edx,0
    read_file_again:
		push	    bx
		push	    ecx
		push	    edx
		push	    edi
		cmp	    ecx,65535	; size of chunks to load
		jc	    @@2
		mov	    ecx,65535	; as close to 64k as can get
    @@2:
		mov	    edx,edi
		mov	    ah,3fh
		int	    21h 	; read from the file
		pop	    edi
		pop	    edx
		pop	    ecx
		pop	    bx
		jc	    read_file_failed	; failed, ret
		movzx	    eax,ax	; get length read
		add	    edx,eax	; update length read counter
		sub	    ecx,eax	; update length counter
		add	    edi,eax	; move memory pointer
		or	    ecx,ecx
		jz	    read_file_end ; read as much as was wanted
		or	    eax,eax	; did we read anything ?
		jz	    read_file_end
		jmp	    read_file_again

    read_file_end:
		mov	    eax,edx	; get accumulated length read
		clc
		RET

    read_file_failed:
		stc

		RET
read_file	ENDP

;==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-
write_file	proc	near

;Write some data to a file.
;
;On Entry:-
;
;BX	- Handle
;ECX	- Length
;ESI	- Position.
;
	xor	edx,edx
@@0:
	push	bx
	push	ecx
	push	edx
	push	esi

	cmp	ecx,65535		;size of chunks to load.
	jc	@@2
	mov	ecx,65535		;as close to 64k as can get.
@@2:	mov	edx,esi
	mov	ah,40h
	int	21h		;read from the file.
	pop	esi
	pop	edx
	pop	ecx
	pop	bx

	jc	@@9
	movzx	eax,ax		;get length read.
	add	edx,eax		;update length read counter.
	sub	ecx,eax		;update length counter.
	add	esi,eax		;move memory pointer.
	or	ecx,ecx
	jz	@@8		;read as much as was wanted.
	or	eax,eax		;did we write anything?
	jz	@@9
	jmp	@@0
@@8:	mov	eax,edx		;get accumulated length read.
	clc
	ret
	;
@@9:	stc
	ret
write_file	endp

;--------------- from alib ------ CONV07.ASM -------------------------
;---------------------------------------------------------------------

wr_eax_dec	PROC	    near	; left aligned

		push	    edx
		push	    edi

		mov	    edx,eax
		shr	    edx,16	    ; to dx:ax

		mov	    edi,offset dec_string
		add	    edi,12	    ; to end
		call	    dd_to_dec_string ; convert to string

		call	    out_msg_edi

		pop	    edi
		pop	    edx

		RET
wr_eax_dec	ENDP

;---------------------------------------------------------------------

dec_string	db	    13 dup (0),0
ten		dw	    10
comma_count	db	    0

;---------------------------------------------------------------------
; dword_convert - convert dword to decimal ascii and store using EDI
;   inputs:  dx,ax = binary value
;	     edi   = storage point
;  output:  edi = pointer to start of decimal string
;
;---------------------------------------------------------------------

dd_to_dec_string PROC	    near

		push	    ax
		push	    bx
		push	    dx

		mov	    comma_count,4

; convert one character each loop.  The least significant digits are
; converted first.

    dd_loop:
		push	    ax
		mov	    ax,dx
		xor	    dx,dx
		div	    ten
		mov	    bx,ax
		pop	    ax
		div	    ten
		xchg	    bx,dx

    ; dx,ax = quotient	    bx = remainder


		dec	    comma_count
		jnz	    not_yet1		; jmp if not time for comma
		mov	    comma_count,3
		mov	    byte ptr [edi],"`"
		dec	    edi
    not_yet1:
		add	    bl,30h
		mov	    byte ptr [edi],bl
		dec	    edi

    ; dx,ax = quotient	    bx = remainder


		or	    ax,ax
		jnz	    dd_loop
		or	    dx,dx
		jnz	    dd_loop
		inc	    edi 	; point at last char. stored.

		pop	    dx
		pop	    bx
		pop	    ax

		RET

dd_to_dec_string ENDP

;---------------------------------------------------------------------
;=====================================================================

wr_float_string db	30 dup (0),0

;---------------------------------------------------------------------

wr_float	PROC	near	    ; 4-byte real in eax

		pushad

		mov	edx,eax     ; copy
		shr	edx,16	    ; high word to dx

		mov	edi,offset wr_float_string
		mov	cx,8		; precision = 8

		call	ftoa

	       ;chk flag remove zeros
	       ;jmp	wrflt_end2

;------- remove trailing zeros -----

		mov	edi,offset wr_float_string

		cmp	word ptr [edi],0030h	; "0",0  ? (bakwd)
		je	wrflt_end2

    wrfltagain1:
		cmp	byte ptr [edi],0    ; end ?
		je	wrflt_endfound
		add	edi,1
		jmp	wrfltagain1
    wrflt_endfound:

;------- overwrite 30h -----

    wrflt_again2:
		sub	edi,1		    ; 1 back

		cmp	byte ptr [edi],30h  ; trailing zero ?
		jne	wrflt_end2
		cmp	byte ptr [edi-1],2eh	; ".0" ?
		je	wrflt_end2
		mov	byte ptr [edi],0    ; write new end
		jmp	wrflt_again2

    wrflt_end2:

;-----------------------------------

		mov	edi,offset wr_float_string
		call	out_msg_edi

		popad

		RET
wr_float	ENDP

;---------------------------------------------------------------------
;----------------------------------------------------------
; FTOA -- version for use with assembly language programs
;
; Copyright Bob Kline 1988
;
; Purpose:
;	Convert floating point value to ASCII string
;
; Input:
;	DX:AX contain 4-byte real
;	DI points to space for new string
;	CX specifies precision
;
; Output:
;       String stored at address pointed to by DI
;
; Registers changed:
;       AX, BX, CX, DX, DI, SI, BP
;
; Other procedures called:
;	LDIV10
;	FBINTODEC
;
; Comments:
;	Calling procedure is responsible for making sure
;	that there is enough space for the new string; if
;	left side of decimal point would have more than
;	18 digits, the procedure uses scientific notation
;	with the precision found in the mantissa rather
;	than that specified in the parameter; to force
;	the use of scientific notation in all cases, use
;	the procedure FTOE instead
;----------------------------------------------------------

	PUBLIC	FTOA

;	EXTRN	FBINTODEC:NEAR
;	EXTRN	LDIV10:NEAR

;	 .MODEL SMALL

;STRING 	 EQU	 BYTE PTR [DI]
STRING		EQU	BYTE PTR [EDI]	    ; in PM
;POINTER	 EQU	 DI
POINTER 	EQU	EDI		    ; in PM
MAXPREC 	EQU	8
PRECISION	EQU	CX
EXPONENT	EQU	BX
DECPLACES	EQU	BP

	.DATA?
TEMPSTRING	DB	11 DUP(?)

	.DATA
ROUNDFACTOR	LABEL	WORD
		DD	5,50,500,5000,50000,500000,5000000,50000000

	.CODE

FTOA	PROC

; at the outset DX:AX = 4-byte real, DI points to start of output
;   string, and CX has the specified precision to use
;   begin by taking care of zero as a special case
	OR	AX,AX
	JNZ	L1
	OR	DX,DX
	JNZ	L1
	MOV	STRING,'0'
       ;INC	DI
	INC	EDI
	MOV	STRING,0
	RET

; bring precision into acceptable range
L1:	CMP	PRECISION,MAXPREC
	JLE	L2
	MOV	PRECISION,MAXPREC
	JMP	SHORT L3
L2:	OR	PRECISION,PRECISION
	JNS	L3
	XOR	PRECISION,PRECISION

; call fbintodec, which comes back with mantissa in DX:AX,
;   sign in low bit of CX, and exponent in BX -- we'll check
;   the sign immediately and take care of it so that CX will
;   be free to pop the precision back off the stack
L3:	PUSH	PRECISION
	PUSH	POINTER
	CALL	FBINTODEC
	POP	POINTER
	OR	CX,CX
	JZ	L4
	MOV	STRING,'-'
	INC	POINTER
L4:	POP	PRECISION

; use BP to hold number of decimal places required by the
;   exponent -- if exponent is negative, decplaces = abs(exponent),
;   otherwise decplaces = 0
	OR	EXPONENT,EXPONENT
	JS	L5
	XOR	DECPLACES,DECPLACES
	JMP	SHORT L6
L5:	MOV	DECPLACES,EXPONENT
	NEG	DECPLACES

; if we have more decimal places than called for by the precision,
;   we may have to round up the mantissa
L6:	CMP	DECPLACES,PRECISION
	JNA	L7

; use SI as index to point into table of amount to add to the
;  mantissa to round it up (SI = decplaces - precision - 1)

	mov	esi,0	; bugfix for PM
	MOV	SI,DECPLACES
	SUB	SI,PRECISION
	DEC	SI

; if the number is so small (that is, the absolute value of the
;   exponent was so much greater than the precision) that none
;   of the digits from the mantissa will be needed, don't bother
;   to round the mantissa; don't forget to multiply index (SI)
;   by 4 since the size of the table elements is 4 bytes
	CMP	SI,7
	JA	L7
	SHL	SI,1
	SHL	SI,1
	CMP	DX,ROUNDFACTOR[SI+2]
	JA	L8
	JB	L7
	CMP	AX,ROUNDFACTOR[SI]
	JB	L7

; passed all the criteria for rounding -- go ahead and do it
L8:	ADD	AX,ROUNDFACTOR[SI]
	ADC	DX,ROUNDFACTOR[SI+2]

; break down mantissa into a temporary string, using SI as the
;   index to the string: note that the digits of the string will
;   be stored backwards, that is, least significant first, so that
;   when we go to move the digits into the output string, we'll
;   pick them off from the end and work back to the beginning.
;   The algorithm here is:
;	while the mantissa is not zero
;		divide by 10 and move the remainder into the string
L7:	mov	esi,0	; bugfix for PM
	XOR	SI,SI
	PUSH	PRECISION
	PUSH	EXPONENT
	JMP	SHORT L9
L10:	CALL	LDIV10
	OR	BL,30h
	MOV	TEMPSTRING[SI],BL
	INC	SI
L9:	OR	AX,AX
	JNZ	L10
	OR	DX,DX
	JNZ	L10
	POP	EXPONENT
	POP	PRECISION

; get ready for some string moves -- note that we're finished
;   with the mantissa itself now, so DX & AX are free for other
;   uses
	MOV	AX,DS
	MOV	ES,AX
	CLD

; if the number is too large (that is, if exponent + digits > 18),
;   switch to scientific notation.  SI holds the number of digits in
;   the temporary string from the mantissa
	MOV	AX,EXPONENT
	ADD	AX,SI
	CMP	AX,18
	JNG	L11

; save the number of digits in tempstring so we can use SI to point
;   to the individual characters in the string, moving backwards
;   from the last digit toward the first
	PUSH	SI
	DEC	SI

; move one digit, then add a decimal point, followed by the rest
;   of the digits
	MOV	AL,TEMPSTRING[SI]
	STOSB
	MOV	AL,'.'
L13:	STOSB
	DEC	SI
	JS	L12
	MOV	AL,TEMPSTRING[SI]
	JMP	L13

; adjust the exponent: (exponent = exponent + digits - 1) and move
;   it into the string
L12:	POP	SI
	ADD	EXPONENT,SI
	DEC	EXPONENT
	MOV	AL,'e'
	STOSB
	MOV	AL,'+'
	STOSB
	MOV	AX,EXPONENT
	MOV	CL,10
	DIV	CL
	OR	AX,3030h
	STOSB
	XCHG	AH,AL
	STOSB

; terminate the string with a null byte and return from the procedure
	MOV	AL,0
	STOSB
	RET

; if we made it to here the number was not so big that we had to use
;   scientific notation.  At this point CX = precision, BX = exponent,
;   BP = decimal places, SI = number of digits in tempstring, and DI
;   points to next position in the output string -- remember DX and
;   AX are no longer needed for the mantissa so we can use them for
;   other things

; right now we'll use DX to hold the number of digits from the temporary
;   string which should go before the decimal point (digits - decplaces);
;   push the number of mantissa digits onto the stack since we'll need
;   it later and SI is going to be needed to point to the individual
;   digits in tempstring
L11:	MOV	DX,SI
	PUSH	SI
	DEC	SI
	SUB	DX,DECPLACES
	JG	L14

; if none of the digits from tempstring go on the left side of the
;   decimal point, stick a zero there just for show
	MOV	AL,'0'
	STOSB
	JMP	SHORT L15

; DX tells us how many of the digits in tempstring should go on the
;   left side of the decimal point: put them there
L16:    MOV     AL,TEMPSTRING[SI]
	STOSB
	DEC	SI
L14:	DEC	DX
        JNS     L16

; if we had a positive exponent we need to pad the integer portion
;   of the string with zeroes
	CMP	EXPONENT,0
	JNG	L15
	PUSH	CX
	MOV	CX,EXPONENT
	MOV	AL,'0'
	REP STOSB
	POP	CX

; if precision is not zero we need to add a decimal point; we'll need
;   to use DX to hold the number of digits the mantissa had, since SI
;   is still busy pointing to the digits
L15:	POP	DX
	OR	PRECISION,PRECISION
        JZ      L17
	MOV	AL,'.'
	STOSB

; pad decimal places with zeroes on left if necessary: the amount of
;   padding needed = decplaces - mantissa digits -- also check to
;   make sure we don't overshoot precision specified
	SUB	DECPLACES,DX
	MOV	AL,'0'
        JMP     SHORT L18
L20:	STOSB
L18:    DEC     DECPLACES
	JS	L19
	DEC	PRECISION
	JNS	L20

; now add the remaining digits from the mantissa, if any, and finish off
;   with zeroes if precision calls for more digits than we have
	JMP	SHORT L19
L22:    MOV     AL,'0'
	OR	SI,SI
        JS      L21
	MOV	AL,TEMPSTRING[SI]
	DEC	SI
L21:    STOSB
L19:	DEC	PRECISION
        JNS     L22

; finish off the string with a null byte and come back from procedure
L17:	MOV	AL,0
	STOSB
	RET

FTOA	ENDP

;---------------------------------------------------------------------


;----------------------------------------------------------
; FBINTODEC
;
; Copyright Bob Kline 1988
;
; Purpose:
;	convert binary float to decimal components
;
; Input:
;       DX:AX contains binary floating point value
;       in IEEE format
;
; Output:
;       DX:AX contains mantissa with decimal point
;       understood to be at end; good to 7-8 places
;       of precision; CX contains sign in low bit;
;       BX contains signed, unbiased decimal exponent
;
; Other registers changed:
;       DI, SI
;
; Example:
;       1.234567e6 (1,234,567) input in DX:AX as
;       32-bit value: bit 31 is sign, bits 30-23
;       are the 8-bit biased binary exponent, and
;       the lowest 23 bits are the mantissa, with
;       a 24th (high) bit understood to be set.
;
;       Output would be 1234567 in DX:AX, -4 in
;       BX, and 0 in CX.
;
; Other procedures called:
;       LDIV10 -- divide 32-bit unsigned integer by 10
;----------------------------------------------------------
;	PUBLIC	FBINTODEC
;	EXTRN	LDIV10:PROC

;	.MODEL	SMALL

	.CODE

FBINTODEC PROC

; isolate the sign flag and save it
        MOV     CX,DX
        ROL     CX,1
        AND     CX,1
        PUSH    CX

; keep the exponent in SI for now, and remove bias
        MOV     SI,DX
        AND     SI,7FFFH
        MOV     CL,7
        SHR     SI,CL
        SUB     SI,127

; isolate the mantissa and restore the high bit
        AND     DX,7FH
        OR      DX,80H

; start out the decimal exponent with 0
        XOR     DI,DI

; if this is a big number slide the mantissa up
        CMP     SI,32
	JL	LOWEXP
        MOV     CX,8
SHFT1:  SHL     AX,1
        RCL     DX,1
        LOOP    SHFT1

; while the exponent is greater than 31 divide by 10
        JMP     SHORT TEST1
LOOP1:  CALL    LDIV10
        XOR     CX,CX   ; shift count

; keep shifting the mantissa left until high bit set
        JMP     SHORT TEST2
LOOP2:  SHL     AX,1
        RCL     DX,1
        INC     CX      ; shift count
TEST2:  TEST    DX,8000H
        JZ      LOOP2

; fold the remainder (BX) back into the mantissa,
;   reduce the binary exponent by the number of
;   shifts we made, and bump up the decimal exponent
        OR      AX,BX
        SUB     SI,CX
        INC     DI

; is the exponent > 31 ?
TEST1:	CMP	SI,31
	JG	LOOP1

; normalize the mantissa
        MOV     CX,31
        SUB     CX,SI
	JZ	DONE
SHFT2:	SHR	DX,1
	RCR	AX,1
        LOOP    SHFT2
        JMP     SHORT DONE

LOWEXP:
; multiply by 10 and shift while exponent
;   is less than 23
        JMP     SHORT TEST3
LOOP3:  MOV     CX,10
        PUSH    AX
        MOV     AX,DX
        MUL     CX
        MOV     BX,AX
        POP     AX
        MUL     CX
        ADD     DX,BX
        XOR     CX,CX   ; shift counter
        JMP     SHORT TEST4
LOOP4:  SHR     DX,1
        RCR     AX,1
        INC     CX      ; shift count
TEST4:  TEST    DX,0F000H
        JNZ     LOOP4

; adjust binary (SI) and decimal (DI) exponents
        ADD     SI,CX
        DEC     DI

TEST3:  CMP     SI,23
	JL	LOOP3

; normalize mantissa
        SUB     SI,23
	JZ	DONE
        MOV     CX,SI
SHFT3:  SHL     AX,1
        RCL     DX,1
        LOOP    SHFT3

DONE:
; move the exponent to BX and get the sign back
        MOV     BX,DI
        POP     CX
        RET

FBINTODEC ENDP

;---------------------------------------------------------------------



;-------------------------------------------------------
; LDIV10
;
; Copyright Bob Kline 1988
;
; Purpose:
;       divide doubleword value by 10
;
; Input:
;       DX:AX contain dividend on entry
;
; Output:
;       DX:AX contain quotient on exit
;       BX contains remainder (0 - 9)
;
; Other registers affected:
;	CX
;-------------------------------------------------------

;	PUBLIC	LDIV10

;	.MODEL SMALL

	.CODE

LDIV10  PROC

        MOV     CX,10
        XCHG    DX,AX
        PUSH    DX
        XOR     DX,DX
        DIV     CX
        XCHG    AX,BX
        POP     AX
        DIV     CX
        XCHG    BX,DX
        RET

LDIV10  ENDP

;=====================================================================
;---------------------------------------------------------------------

wr_2_hex      PROC	  near		    ; wr value in al

		push	    ax

		mov	    ah,al	    ; copy value

		push	    ax
		shr	    al,4
		call	    xlat_al	    ; to ascii
		call	    writt_al
		pop	    ax

		mov	    al,ah	    ; restore
		and	    al,0fh
		call	    xlat_al	    ; to ascii
		call	    writt_al

		mov	    al,20h
	       ;call	    writt_al

		mov	    al,"h"
		call	    writt_al

		pop	    ax

		RET
wr_2_hex      ENDP

;---------------------------------------------------------------------

wr_4_hex      PROC	  near		    ; wr value in ax

		push	    ax
		push	    cx

		mov	    cx,4
    wr4hagain:
		rol	    ax,4
		push	    ax
		and	    al,0fh
		call	    xlat_al	    ; to ascii
		call	    writt_al
		pop	    ax
		loopw	    wr4hagain

		mov	    al,20h
	       ;call	    writt_al

		mov	    al,"h"
		call	    writt_al

		pop	    cx
		pop	    ax

		RET
wr_4_hex      ENDP


;---------------------------------------------------------------------

wr_8_hex      PROC	  near		    ; wr value in eax

		push	    eax
		push	    cx

		mov	    cx,8
    wr8hagain:
		rol	    eax,4
		push	    eax
		and	    al,0fh
		call	    xlat_al	    ; to ascii
		call	    writt_al
		pop	    eax
		loopw	    wr8hagain

		mov	    al,20h
	       ;call	    writt_al

		mov	    al,"h"
		call	    writt_al

		pop	    cx
		pop	    eax

		RET
wr_8_hex      ENDP

;----------------------------------------------------------------------

hexchars	db	    "0123456789ABCDEF"	; for xlat_al

;----------------------------------------------------------------------

xlat_al 	PROC	    near	; xlat al to hex char ascii

		push	    esi

		mov	    esi,offset hexchars ; table of chars
		and	    eax,0ffh
		add	    esi,eax
		mov	    al,byte ptr [esi]

		pop	    esi

		RET
xlat_al 	ENDP

;---------------------------------------------------------------------

wr_edi_esi	PROC	    near    ; write asciiz in edi to
				    ;	(screen) esi

		push	    ax
		push	    edi
		push	    esi

    wredesagain:
		mov	    al,byte ptr [edi]
		cmp	    al,0
		je	    wredesend
		mov	    byte ptr [esi],al
		add	    edi,1
		add	    esi,2
		jmp	    wredesagain
    wredesend:

		pop	    esi
		pop	    edi
		pop	    ax


		RET
wr_edi_esi	ENDP

;---------------------------------------------------------------------

out_msg_edi	PROC	    near    ; edi points to asciiz


		push	    eax
		push	    edi

    omsgediagain:
		mov	    al,byte ptr [edi]
		cmp	    al,0
		je	    omsgediend

		call	    writt_al
		add	    edi,1
		jmp	    omsgediagain

    omsgediend:

		pop	    edi
		pop	    eax


		RET
out_msg_edi	ENDP

;---------------------------------------------------------------------

out_msg_esi	PROC	    near    ; esi points to asciiz (altern.)


		push	    eax
		push	    esi

    omsgesiagain:
		mov	    al,byte ptr [esi]
		cmp	    al,0
		je	    omsgesiend

		call	    writt_al
		add	    esi,1
		jmp	    omsgesiagain

    omsgesiend:

		pop	    esi
		pop	    eax


		RET
out_msg_esi	ENDP

;---------------------------------------------------------------------

space		PROC	    near

		push	    ax

		mov	    al,20h
		call	    writt_al

		pop	    ax

		RET
space		ENDP

;----------------------------------------------------------------------

two_space	PROC	    near

		push	    ax

		mov	    al,20h
		call	    writt_al
		call	    writt_al

		pop	    ax

		RET
two_space	ENDP

;----------------------------------------------------------------------

four_space	PROC	    near

		push	    ax

		mov	    al,20h
		call	    writt_al
		call	    writt_al
		call	    writt_al
		call	    writt_al

		pop	    ax

		RET
four_space	ENDP

;----------------------------------------------------------------------

crlf		PROC	    near

		push	    eax

		mov	    al,0dh	    ; cr
		call	    writt_al

		mov	    al,0ah	    ; lf
		call	    writt_al


		pop	    eax

		RET
crlf		ENDP

;----------------------------------------------------------------------

writt_al	PROC	    near	; writt ascii in al to cursor
					; in VESA-Mode may only work
					; for page 0
		push	    ax
		push	    bx

		mov	    ah,0eh
		mov	    al,al
		mov	    bh,curpa
	       ;mov	    bl,color_fg
		mov	    bl,7
		int	    10h

		pop	    bx
		pop	    ax

		RET
writt_al	ENDP



;---------------------------------------------------------------------
;		end of _general.inc
;---------------------------------------------------------------------
