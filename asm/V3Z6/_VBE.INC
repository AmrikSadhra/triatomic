;---------------------------------------------------------------------
;		_vbe.inc		19:50:42  16-Jun-2002
;
;		    call    with:	mov	video_mode,xxx
;					call	setup_vbe
;
;		    some proc names changed to make them local
;			(f.e. writt_al -> v_writt_al)
;
;---------------------------------------------------------------------
;=========== vbe proc`s data =========================================
;---------------------------------------------------------------------

		.DATA

;---------------------------------------------------------------------

video_mode	dw	    0		; desired video-mode

display_base	dd	    0		; start of LFB

page_1_base	dd	    0		; base addr. of page 1
					; (for double fr.buffer)
					; init. from setup vbe

page_len	dd	    0		; len. of 1 display page
					; calc from setup vbe

;---------------------------------------------------------------------

rm_buf_seg	dw	    0		; (tmp. file buf.) (rm seg.)

rm_buf_addr	dd	    0		; calced from rm_buf_seg

;--- real-mode call structure (50 bytes) -----------------------------


rm_call_struc	Label	    dword
					; Name:     Offset:  d
					; -----     ----------
rm_edi		dd	    0		;   EDI     00h     00
rm_esi		dd	    0		;   ESI     04h     04
rm_ebp		dd	    0		;   EBP     08h     08
		dd	    0		;   res.    0Ch     12
rm_ebx		dd	    0		;   EBX     10h     16
rm_edx		dd	    0		;   EDX     14h     20
rm_ecx		dd	    0		;   ECX     18h     24
rm_eax		dd	    0		;   EAX     1Ch     28
		dw	    0		;   Flags   20h     32
rm_es		dw	    0		;   ES	    22h     34
rm_ds		dw	    0		;   DS	    24h     36
		dw	    0		;   FS	    26h     38
		dw	    0		;   GS	    28h     40
		dw	    0		;   IP	    2Ah     42
		dw	    0		;   CS	    2Ch     44
		dw	    0		;   SP	    2Eh     46
		dw	    0		;   SS	    30h     48

;----------------------------------------------------------------------

no_vbe_err	db	    "no VBE found",0
;no_vbe_err	 db	     "keine VBE vorhanden",0

vbe_err_1	db	    "VBE-1: failed",0
;vbe_err_1	 db	     "VBE-1: fehlgeschlagen",0

vbe_err_2	db	    "VBE-2: function not supported by "
		db	    "current hardware configuration",0
;vbe_err_2	 db	     "VBE-2: Funktion wird von Hardware nicht "
;		 db	     "untersttzt",0

vbe_err_3	db	    "VBE-3: function invalid in current "
		db	    "video mode",0
;vbe_err_3	 db	     "VBE-3: Funktion im aktuellen Videomodus "
;		 db	     "nicht erlaubt",0

vbe_err_unk	db	    "VBE-x: unknown error",0
;vbe_err_unk	 db	     "VBE-x: unbekannter Fehler",0

;-----------------------

vbe_not_2plus	db	    "VBE-Version below 2.0",0
;vbe_not_2plus	 db	     "VBE-Version unter 2.0",0

vbe_mode_n_avail db	    "selected video mode not "
		db	    "available",0
;vbe_mode_n_avail db	     "gewuenschter Video-Modus nicht "
;		 db	     "verfuegbar",0

err_lfb_n_avail db	    "linear frame buffer not available",0
;err_lfb_n_avail db	     "Linear Frame Buffer nicht verfuegbar",0


;---------------------------------------------------------------------
;--------------- VBE Data --------------------------------------------
;---------------------------------------------------------------------


VBEInfoBlock	Label	    byte

VBESignature	db  "VBE2"	; VBESignature	("VBE2" = VBE 2),
				;		( else = VBE 1.2)
				; "VBE2" forces extended Information

VBEVersion	dw	    0	; BCD
OEMStringPtr	dd	    0	;
Capabilities	db 4 dup (0)	;
VideoModePtr	dd	    0	;

TotalMemory	dw	    0	; (64 KB Blocks) , ab VBE 1.1

;--- VBE 2.0+ ------

OEMSoftwareRev	dw	    0
OEMVendorNamePtr dd	    0
OEMProductNamePtr dd	    0
OEMProductRevPtr dd	    0
		db	    0	; reserved
				;
				;   total len. = max. 200h Bytes
				;	       =      512 Bytes dez.

Info_block_space  db 200h  dup (0)	; space for OEM-Data


;---------------------------------------------------------------------

;-- ModeInfoBlock ------

     ; Mandatory information for all VBE revisions

ModeInfoBlock	Label	    word

ModeAttributes	dw	    0	; mode attributes
WinAAttributes	db	    0	; window A attributes
WinBAttributes	db	    0	; window B attributes
WinGranularity	dw	    0	; window granularity
WinSize 	dw	    0	; window size
WinASegment	dw	    0	; window A start segment
WinBSegment	dw	    0	; window B start segment
WinFuncPtr	dd	    0	; pointer to window function
BytesPerScanLine  dw	    0	; bytes per scan line

     ; Mandatory information for VBE 1.2 and above
XResolution	dw	0 ; horizontal resolution in pixels or chars
YResolution	dw	0 ; vertical resolution in pixels or chars
XCharSize	db	    0	; character cell width in pixels
YCharSize	db	    0	; character cell height in pixels
NumberOfPlanes	db	    0	; number of memory planes
BitsPerPixel	db	    0	; bits per pixel
NumberOfBanks	db	    0	; number of banks
MemoryModel	db	    0	; memory model type
BankSize	db	    0	; bank size in KB
NumberOfImagePages  db	    0	; number of images
_Reserved	db	    0	; reserved for page function

 ; Direct Color fields (required for direct/6 and YUV/7 memory models)
RedMaskSize	db	0   ; size of direct color red mask in bits
RedFieldPosition  db	0   ; bit position of lsb of red mask
GreenMaskSize	db	0   ; size of direct color green mask in bits
GreenFieldPosition  db	0	; bit position of lsb of green mask
BlueMaskSize	db	0   ; size of direct color blue mask in bits
BlueFieldPosition   db	0   ; bit position of lsb of blue mask
RsvdMaskSize	db	0 ; size of direct color reserved mask in bits
RsvdFieldPosition   db	0   ; bit position of lsb of reserved mask
DirectColorModeInfo db	0	; direct color mode attributes

     ; Mandatory information for VBE 2.0 and above
PhysBasePtr	dd	0   ; physical address for flat frame buffer
OffScreenMemOffset  dd	0   ; pointer to start of off screen memory
OffScreenMemSize    dw	0   ; amount of off screen memory in 1k units
__Reserved	db 206 dup (0)	; remainder of ModeInfoBlock


;---------------------------------------------------------------------

		.CODE

;=====================================================================
;------- vbe proc`s --------------------------------------------------
;=====================================================================

setup_vbe	PROC	near

;----------- DOS 32 --------------------------------------------------

	       ;mov	ax,0ee02h   ; DOS32 funct.
	       ;int	31h	    ; get DOS32 address info

	       ;mov	rm_buf_seg,ax	; only tmp. (file buf.)

	       ;mov	eax,0
	       ;mov	ax,rm_buf_seg	; get rm-seg-addr.
	       ;shl	eax,4		; set to pm size
	       ;mov	rm_buf_addr,eax

;----------- Causeway ------------------------------------------------

		mov	ax,0ff25h   ; GetDosTrans
		int	31h	    ; get DOS32 address info

		mov	rm_buf_seg,bx	; only tmp. (file buf.)

		mov	ebx,0
		mov	bx,rm_buf_seg	; get rm-seg-addr.
		shl	ebx,4		; set to pm size
		mov	rm_buf_addr,ebx

;---------------------------------------------------------------------

		call	vbe_get_info_block

		cmp	VBEVersion,200h     ; 2.0+
		jnb	isvbe2plus
		mov	edi,offset vbe_not_2plus
		call	v_out_msg_edi
		call	v_crlf
		call	prg_abort

    isvbe2plus:

;---------------------------------------------------------------------

					    ; mode is in video_mode
	       ;mov	video_mode,111h     ; 111h=640*480*64k
		call	chk_mode_avail
		jnc	modeisavail
		mov	edi,offset vbe_mode_n_avail
		call	v_out_msg_edi
		call	v_crlf
		call	prg_abort

    modeisavail:

;---------------------------------------------------------------------

		call	vbe_get_mode_info   ; mode in video_mode

;---------------------------------------------------------------------

		mov	ax,ModeAttributes   ; (ModeAttributes)
		and	al,10000000b
		cmp	al,10000000b	    ; 1=LFB available
		je	lfbisavail
		mov	edi,offset err_lfb_n_avail
		call	v_out_msg_edi
		call	v_crlf
		call	prg_abort
    lfbisavail:

;---------------------------------------------------------------------

		call	vbe_set_mode

;------- physical memory mapping -------------------------------------

	       ;int 3

		mov	ebx,PhysBasePtr
		mov	cx,bx
		shr	ebx,16		; = BX:CX

		mov	si,TotalMemory	; (64K Blocks)
		mov	di,0		; = SI:DI = Size

		mov	ax,800h
		int	31h

	       ;jnc

		mov	eax,0
		mov	ax,bx
		shl	eax,16
		mov	ax,cx
		mov	display_base,eax
;---------------------------

		mov	ax,BytesPerScanLine
		mov	bx,YResolution
		mul	bx
		shl	edx,16
		mov	dx,ax
		mov	page_len,edx	    ; calced len.

		mov	eax,display_base
		add	eax,edx 	    ; add len.
		mov	page_1_base,eax     ; init, assume: page 1
					    ; for dbl.frame.buffer


		RET
setup_vbe	ENDP

;---------------------------------------------------------------------

vbe_set_mode	PROC	near

		call	vbe_f2	    ; get vbe info
		jnc	vsmeiter1
		call	out_msg_vbe_err     ; return value in ax
		call	prg_abort   ; far jump
    vsmeiter1:

		RET
vbe_set_mode	ENDP

;---------------------------------------------------------------------

vbe_get_mode_info PROC	near

		call	vbe_f1	    ; get vbe info
		jnc	vgmieiter1
		call	out_msg_vbe_err     ; return value in ax
		call	prg_abort   ; far jump

    vgmieiter1:

;------- copy vbe-info-block -------

		mov	edi,rm_buf_addr
		mov	esi,offset ModeInfoBlock

		mov	cx,256		; size of Info-Block
    vgmiagain1:
		nop
		nop
		mov	al,byte ptr gs:[edi]	; 0-base seg.
		mov	byte ptr [esi],al
		add	edi,1
		add	esi,1
		loopw	vgmiagain1


		RET
vbe_get_mode_info ENDP

;---------------------------------------------------------------------

chk_mode_avail	PROC	near	    ; mode nr. in video_mode

		mov	eax,VideoModePtr    ; 16:16
		mov	ebx,eax
		and	ebx,0ffffh	    ; mask high off
		and	eax,0ffff0000h	    ; mask low off
		shr	eax,12		    ; 12, seg addr.
		add	eax,ebx
		mov	edi,eax

		mov	ax,video_mode	    ; desired mode
    cmavagain:
		cmp	word ptr gs:[edi],-1
		je	cmavend2	    ; end of list
		cmp	word ptr gs:[edi],ax
		je	cmavend1
		add	edi,2		    ; to next mode
		jmp	cmavagain

    cmavend1:
		clc			    ; mode found
		RET

    cmavend2:
		stc			    ; mode not found

		RET
chk_mode_avail	ENDP

;---------------------------------------------------------------------

vbe_get_info_block PROC near

		call	vbe_f0	    ; get vbe info
		jnc	vgibeiter1
		call	out_msg_vbe_err     ; return value in ax
		call	prg_abort   ; far jump

    vgibeiter1:

;------- copy vbe-info-block -------

		mov	edi,rm_buf_addr
		mov	esi,offset VBEInfoBlock

		mov	cx,512		; size of Info-Block
    vgibagain1:
		nop
		nop
		mov	al,byte ptr gs:[edi]	; 0-base seg.
		mov	byte ptr [esi],al
		add	edi,1
		add	esi,1
		loopw	vgibagain1


		mov	eax,dword ptr VBESignature
		mov	ebx,"ASEV"	; "VESA" bkwd.


		RET
vbe_get_info_block ENDP

;---------------------------------------------------------------------
;---------------------------------------------------------------------

vbe_f0		PROC	near	    ; vbe info
				    ; carry if fail

		mov	edi,rm_buf_addr
		mov	dword ptr gs:[edi],"2EBV"  ; "VBE2" bkwd.
					; force VBE 2.0 ret. format

;-------------------

		mov	eax,0
		mov	ah,4fh	    ; vbe
		mov	al,0	    ; funktion

		mov	rm_eax,eax

		mov	eax,0
		mov	ax,rm_buf_seg	; 8K file buffer
		mov	rm_es,ax

		mov	rm_edi,0    ; es:di -> struc. (f.buf.)

		call	dos_int_10h

		mov	eax,rm_eax
		cmp	ax,4fh	    ; ok ? (ah=0, al=4fh)
		jne	vbef0failed

		clc		    ; not failed (no carry)
		RET

    vbef0failed:
		stc		    ; failed (carry)

		RET
vbe_f0		ENDP

;---------------------------------------------------------------------

vbe_f1		PROC	near	    ; vbe info
				    ; carry if fail

		mov	eax,0
		mov	ah,4fh	    ; vbe
		mov	al,1	    ; funktion

		mov	rm_eax,eax	; funktion

		mov	ecx,0
		mov	cx,video_mode	; mode
		mov	rm_ecx,ecx

		mov	eax,0
		mov	ax,rm_buf_seg	; 8K file buffer
		mov	rm_es,ax

		mov	rm_edi,0    ; es:di -> struc. (f.buf.)

		call	dos_int_10h

		mov	eax,rm_eax
		cmp	ax,4fh		; ok ? (ah=0, al=4fh)
		jne	vbef1failed

		clc		    ; ok (not carry)
		RET

    vbef1failed:
		stc		    ; failed (carry)

		RET
vbe_f1		ENDP

;---------------------------------------------------------------------

vbe_f2		PROC	near	    ; set VBE video-mode
				    ; mode in video_mode

		mov	eax,0
		mov	ah,4fh	    ; vbe
		mov	al,2	    ; funktion

		mov	rm_eax,eax	; funktion

		mov	ebx,0
		mov	bx,video_mode	; mode
		or	bh,01000000b	; use LFB
		mov	rm_ebx,ebx


		call	dos_int_10h

		mov	eax,rm_eax
		cmp	ax,4fh		; ok ? (ah=0, al=4fh)
		jne	vbef2failed

		clc		    ; ok (not carry)
		RET

    vbef2failed:
		stc		    ; failed (carry)


		RET
vbe_f2		ENDP

;---------------------------------------------------------------------

dos_int_10h	PROC	near	    ;


		mov	ax,300h     ; simulate rm int
		mov	bl,10h	    ; int nr.
		mov	bh,0	    ; flags (0)
		mov	cx,0	    ; stack words to copy (0)
		mov	edi,offset rm_call_struc
		int	31h


;     If function was successful:
;     Carry flag is clear.
;     ES:(E)DI =  Selector:Offset of  modified real mode call
;		  structure
;
;     If function was not successful:
;      Carry flag is set.


		RET
dos_int_10h	ENDP

;---------------------------------------------------------------------

out_msg_vbe_err PROC	near	; return value in ax

		cmp	al,4fh	    ; vbe vorhanden
		je	omsvbereiter1
		mov	edi,offset no_vbe_err
		call	v_out_msg_edi
		call	v_crlf
		RET
    omsvbereiter1:
		cmp	ah,1	    ; fehlgeschlagen ?
		jne	omsvbereiter2
		mov	edi,offset vbe_err_1
		call	v_out_msg_edi
		call	v_crlf
		RET
    omsvbereiter2:

;------- vbe 2.0+ --------------------------

		cmp	ah,2	    ; not supported
		jne	omsvbereiter3
		mov	edi,offset vbe_err_2
		call	v_out_msg_edi
		call	v_crlf
		RET
    omsvbereiter3:
		cmp	ah,3	    ; not allowed
		jne	omsvbereiter4
		mov	edi,offset vbe_err_3
		call	v_out_msg_edi
		call	v_crlf
		RET
    omsvbereiter4:
		mov	edi,offset vbe_err_unk	; unknown error
		call	v_out_msg_edi
		call	v_crlf


		RET
out_msg_vbe_err ENDP

;---------------------------------------------------------------------

v_out_msg_edi	PROC	near	; edi points to asciiz


		push	eax
		push	edi

    vomsgediagain:
		mov	al,byte ptr [edi]
		cmp	al,0
		je	vomsgediend

		call	v_writt_al
		add	edi,1
		jmp	vomsgediagain

    vomsgediend:

		pop	edi
		pop	eax



		RET
v_out_msg_edi	  ENDP

;----------------------------------------------------------------------

v_crlf		PROC	near

		push	eax

		mov	al,0dh		; cr
		call	v_writt_al

		mov	al,0ah		; lf
		call	v_writt_al

		pop	eax

		RET
v_crlf		ENDP

;----------------------------------------------------------------------

v_writt_al	PROC	near	    ; writt ascii in al to cursor
				    ; in VESA-Mode may only work
				    ; for page 0
		push	ax
		push	bx

		mov	ah,0eh
		mov	al,al
		mov	bh,curpa
	       ;mov	bl,color_fg
		mov	bl,7
		int	10h

		pop	bx
		pop	ax

		RET
v_writt_al	ENDP

;----------------------------------------------------------------------
;		end of _vbe.inc
;----------------------------------------------------------------------
