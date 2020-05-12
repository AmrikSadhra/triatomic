		TITLE	v3.asm		23:26:07  20-Oct-2001

					; 3dfx voodoo 3 (avenger)
					; 2d register programming
					; with CauseWay Extender
					;
					; (8:8:8 mode)
		.386			;
		.MODEL	FLAT		;
					;
		.STACK	400h		; need at least 400h for
					;  some pci functions

		ASSUME	GS : NOTHING	; def.: assumed to error,
					; now GS is zero based
					; segment (for screen)

;---------------------------------------------------------------------
;	first steps with avenger
;
;   written by daniel hagmann
;    except loadgif+lzw decode written by John McCarthy
;
;	masm 6.0
;
;---------------------------------------------------------------------
;   unreleased:
;
;	+ register dump to screen
;	- register dump to disk (?)
;
;---------------------------------------------------------------------
;   bugs:
;	    - srcBaseAddr  in  a_wr_char   must be resetted
;		--> scroll_up
;	    - sometimes no readable text under Windows
;		(bug with monochrome src. screen-screen blit)
;		    19-Oct-2001 fixed -> addr_a_wr_char
;
;---------------------------------------------------------------------

		.DATA

;---------------------------------------------------------------------

	       ;EXTRN	_d_fs2_filespec:byte
	       ;EXTRN	_d_fs2_selected_name:byte

;---------------------------------------------------------------------
;avenger 2d registers	(prog. internally used as addresses)
;---------------------------------------------------------------------
;Memory Base 0: Offset 0x0100000   (prog. internally: _2dBase)
;---------------------------------------------------------------------
;Register Name Address	Bits  Description
;---------------------------------------------------------------------
status	       dd 0 ; (+0)  31:0 (read only)  Avenger status register
intCtrl        dd 0 ; (+4)  31:0  Interrupt control and status
clip0Min       dd 0 ; (+8)  28:0  Min X & Y clip values when clip select is 0
clip0Max       dd 0 ; (+12)  28:0  Max X & Y clip values when clip select is 0
dstBaseAddr    dd 0 ; (+16)  23:0  Destination base address
dstFormat      dd 0 ; (+20)  17:0  Destination stride and bits per pixel
srcColorkeyMin dd 0 ; (+24)  23:0  Source Colorkey range (min)
srcColorkeyMax dd 0 ; (+28)  23:0  Source Colorkey range (max)
dstColorkeyMin dd 0 ; (+32)  23:0  Destination Colorkey range (min)
dstColorkeyMax dd 0 ; (+36)  23:0  Destination Colorkey range (max)
bresError0     dd 0 ; (+40)  31:0  Initial error for lines, right edges
							  ; & stretch blt x
bresError1     dd 0 ; (+44)  31:0  Initial error for left poly edges
							  ; & stretch blt y
rop	       dd 0 ; (+48)  31:0  4 Ternary Raster operations
srcBaseAddr    dd 0 ; (+52)  23:0  Source base address
commandExtra   dd 0 ; (+56)  31:0  Extra control bits
lineStipple    dd 0 ; (+60)  31:0  Monochrome pattern for lines
lineStyle      dd 0 ; (+64)  28:0  Style register for lines
pattern0Alias  dd 0 ; (+68)  31:0  Alias to colorPattern(0)
pattern1Alias  dd 0 ; (+72)  31:0  Alias to colorPattern(1)
clip1Min       dd 0 ; (+76)  28:0  Min X & Y clip values when clip select is 1
clip1Max       dd 0 ; (+80)  28:0  Max X & Y clip values when clip select is 1
srcFormat      dd 0 ; (+84)  18:0  Source stride and bits per pixel
srcSize        dd 0 ; (+88)  28:0  Height and width of source for stretch blts
srcXY	       dd 0 ; (+92)  28:0  Starting pixel of blt source data
		    ;		   Starting position for lines
		    ;		   Top-most point for a polygon fill
colorBack      dd 0 ; (+96)  31:0  Background color
colorFore      dd 0 ; (+100)  31:0  Foreground color
dstSize        dd 0 ; (+104)  28:0  Destination width and height for blts and
		    ;					    rectangle fills
dstXY	       dd 0 ; (+108)  28:0  Starting X and Y of destination for blts
		    ;					End point for lines
command        dd 0 ; (+112)  31:0  2D command mode & control bits
RESERVED_116   dd 0 ; (+116)  31:0 Do not write
RESERVED_120   dd 0 ; (+120)  31:0 Do not write
RESERVED_124   dd 0 ; (+124)  31:0 Do not write
launchArea     dd 32 dup (0)
		    ; (+128) to (+255)	31:0 R Initiates 2D commands
colorPattern   dd 64 dup (0)
		    ; (+256) to (+508)	31:0  Pattern Registers (64 entries)

;---------------------------------------------------------------------

xs		dw	0	    ; x start
ys		dw	0	    ; y start
xe		dw	0	    ; x end
ye		dw	0	    ; y end

r		db	0	    ; red
g		db	0	    ; green
b		db	0	    ; blue

font_ptr_rom	dd	0	    ; pointer to rom-font (in rom)
font_ptr_video	dd	0	    ; pointer to copyed rom-font
				    ; in video memory  (for CPU)
font_ptr	dd	0	    ; pointer to copyed rom-font
				    ; in video memory  (for GPU)
				    ; (relative to display_base)

;---------------------------------------------------------------------

waitcount	dd	0	    ; xxx debug counter
				    ;	(waitloops until idle)

;---------------------------------------------------------------------

hexchars	db	"0123456789ABCDEF"  ; for xlat_al

curpa		db	0	    ; current page

video_mode	dw	0	    ; desired video-mode

display_base	dd	0	    ; start of LFB

draw_page_base	dd	0	    ; base addr. of other page
				    ; (for double fr.buffer)
				    ; init. from setup vbe

page_len	dd	0	    ; len. of 1 display page
				    ; calc from setup vbe

;------- from sprite setup ----- (assume we have enough screen mem.)

page_0_base	dd	0	    ; same as display_base
page_1_base	dd	0	    ; same as draw_pag_base
page_2_base	dd	0	    ; reserved (triple-buff ?)
page_3_base	dd	0	    ; sprite shadow
page_4_base	dd	0	    ; sprite data start

sprite_shadow_start dd	0	    ; same as page_3_base
sprite_data_start   dd	0	    ; same as page_4_base


;---------------------------------------------------------------------

curx		dw	0
cury		dw	0

;---------------------------------------------------------------------

pci_b_nfound	db	"pci bios not found",0
v3_nfound	db	"Voodoo 3 card not found",0
err_config_r	db	"error reading config dword",0
err_map_2d3d_r	db	"error mapping registers",0


msg_key_exit	db	"-> press a key to exit",0

msg_setup_ok	db	"setup ok, testing line,  -> key",0
msg_test_rect	db	"testing rectangle, -> key      ",0
msg_test_blit	db	"testing rect. + blit,    -> key",0
msg_text_blit	db	"testing text blit,  -> key     ",0

msg_text_test	db	"tested 20`000 ascii blit`s "
		db	"including line scroll up"
		db	"   -> key, end ",0

;---------------------------------------------------------------------

filename_read	db	"v3test.gif",0

filehandle_read dw	0

free_mem	dd	0

;------- returned from loadgif ---------------------------------------

gif_len 	dd	0
gif_loc 	dd	0   ; first 2 words are x and y size
pal_loc 	dd	0   ; if = gif_loc then no palette
gif_num_colors	dw	0

size_x		dw	0	; gif size x
size_y		dw	0	; gif size y

;---------------------------------------------------------------------

		.CODE

;---------------------------------------------------------------------

START:

;---------------------------------------------------------------------

		mov	ax,_DATA
		mov	ds,ax
		mov	es,ax
		mov	fs,ax
		mov	gs,ax

;---------------------------------------------------------------------

		call	loadgif     ; load and decomp. the exmpl.

	       ;mov	eax,offset loadgif
	       ;call	eax

;---------------------------------------------------------------------

		mov	video_mode,112h     ; 112h=640*480*16M
						;      (8:8:8)
		call	setup_vbe   ; all to setupvbe for lfb

;---------------------------------------------------------------------



;---------------------------------------------------------------------


;---------------------------------------------------------------------

		call	pci_check     ; search + get avenger adr.
		call	map_2d3dregs  ; memBaseAddr0 -> _2dBase, _3dBase
		call	set_all_2d_reg_addr

;---------------------------------------------------------------------

	       ;mov	eax,waitcount
	       ;call	reset_2d
	       ;mov	eax,waitcount

	       ;call	dump_2d_registers

	       ;mov	ah,0
	       ;int	16h

	       ;call	cls	    ; rectangle

;---------------------------------------------------------------------

		call	trans_gif   ; transfer the gif to screen
					; (CPU) without v3

;---------------------------------------------------------------------

		call	setup_640_24	; 640*480, 24 bpp

	       ;call	save_state	; xxxxx debug
	       ;xall	restore_state

		mov	ah,2	    ; function nr
		mov	bh,0	    ; curpa
		mov	dl,0	    ; pos_x
		mov	dh,28	    ; pos_y
		int	10h	    ; set cursor

		mov	edi,offset msg_setup_ok
		call	out_msg_edi

;---------------------------------------------------------------------

		call	trans_gif_to_sprite ; to sprite_data_start
					    ; !! after setup_640_24

;---------------------------------------------------------------------


	       ;jmp	l_text_test	; xxxxx debug

;------- line --------------

		mov	edi,_2dbase


		mov	eax,0
			  ;00000000rrrrrrrr
		mov	ax,0000000011101111b
		shl	eax,16
			  ;ggggggggbbbbbbbb
		mov	ax,1001111010111000b
		mov	edi,colorFore
		mov	[edi],eax     ; fg color

		mov	eax,0
			  ;rrrrrggggggbbbbb
		mov	ax,33h
		mov	edi,colorBack
		mov	[edi],eax     ; bg color


		mov	eax,100010h
		mov	edi,srcXY
		mov	[edi],eax     ; srcXY

		mov	eax,01000100h
		mov	edi,dstXY
		mov	[edi],eax     ; end point

		mov	ax,1100110000000000b
		shl	eax,16
		mov	ax,6			    ; line
		or	ah,1			    ; immediate

		mov	edi,command
		mov	[edi],eax     ; cmd reg.

;-----------------------

		mov	ah,0
		int	16h

;------- rectangle ---------

		mov	eax,0500050h		    ; x,y
		mov	edi,dstSize
		mov	[edi],eax     ; dstSize

		mov	eax,5			    ; rectangle
		or	ah,1			    ; immediate
		mov	eax,0cc000105h
		mov	edi,command
		mov	[edi],eax     ; cmd reg.

;------- write pixel -------

		mov	eax,display_base
		mov	edi,eax
		mov	dword ptr [edi+4060h],0ffffffffh

;---------------------------

		call	cr
		mov	edi,offset msg_test_rect
		call	out_msg_edi

		mov	ah,0
		int	16h

		call	rectangle2
		call	line2

		mov	r,100
		mov	g,0
		mov	b,80
		call	set_color

		mov	xs,400
		mov	ys,110
		mov	xe,630
		mov	ye,400
		call	rectangle



		mov	r,140
		mov	g,140
		call	set_color

		mov	xs,300
		mov	ys,300
		mov	xe,380
		mov	ye,380
		call	line

;---------------------------------------------------------------------

		call	screen_blt2

		mov	ah,0
		int	16h

		call	screen_stretch_blt2

		call	host_blt2		; text

		call	host_blt3		; text

		call	host_stretch_blt2	; text

;-------------------

		mov	ah,0
		int	16h

		mov	eax,display_base
		add	eax,0fff000h

						; xxxx debug
		mov	text_char,"E"
		call	a_wr_char

		mov	ah,0
		int	16h


;---------------------------------------------------------------------

		call	cr
		mov	edi,offset msg_test_blit
		call	out_msg_edi

		mov	ah,0
		int	16h



		call	cr
		mov	edi,offset msg_text_blit
		call	out_msg_edi

		call	text_blit

		call	text_stretch_blit

		mov	ah,0
		int	16h
    l_text_test:

		call	cls

		call	text_test

		mov	ah,0
	       ;int	16h

		call	sprite_test


		mov	ah,0
		int	16h



;---------------------------------------------------------------------

    prg_exit:

		mov	ah,0	    ; set video mode
		mov	al,3	    ; mode 3 (80*25)
		int	10h	    ; Return to TEXT mode


    prg_abort:

		mov	ah,4ch
		mov	al,0		; DOS exit
		int	21h		;   kein fehler

;---------------------------------------------------------------------
;-------------- E N D E ----------------------------------------------
;---------------------------------------------------------------------

;---------------------------------------------------------------------
; wait_retrace
;
; pauses the computer until the next vertical retrace starts
;
; entry: no parameters are passed
;
; exit:  no meaningful values returned
;---------------------------------------------------------------------

input_1 	equ 03dah      ; input status #1 register
vert_retrace	equ 08h        ; input_1: vertical retrace bit

;---------------------------------------------------------------------

wait_retrace	PROC	near

         mov dx, input_1                    ; input status #1 register

; wait for any current retrace to end

@sd_wait0:
         in al, dx                          ; get vga status
         and al, vert_retrace               ; in display mode yet?
         jnz @sd_wait0                      ; if not, wait for it

; wait for the start of the next vertical retrace

@sd_wait1:
         in al, dx                          ; get vga status
         and al, vert_retrace               ; vertical retrace start?
         jz @sd_wait1                       ; if not, wait for it

	 ret

wait_retrace	ENDP



;---------------------------------------------------------------------
;============== SPRITE ===============================================
;---------------------------------------------------------------------

sprite_pos_x	dw	10
sprite_pos_y	dw	20

;---------------------------------------------------------------------

sprite_test	PROC	near


		mov	eax,0
		mov	edi,srcBaseAddr
		mov	[edi],eax	    ; !!  bugfix

;-----------------------

		mov	edi,commandExtra
		mov	eax,[edi]
		or	al,00000000b	; set bit 2, wait vsync
		mov	[edi],eax


	       ;call	sprite_on
	       ;call	sprite_off

    sprtestagain:
;call	     wait_retrace      ; xxxxx	   ; xx where/why ?
		call	sprite_on

		mov	ah,0
		int	16h
		cmp	ah,1		; esc ?
		je	sprtestend

;-------------------
 call	     wait_retrace      ; xxxxx	   ; xx where/why ?
		call	sprite_off

		mov	ah,0
	       ;int	16h
		cmp	ah,1		; esc ?
		je	sprtestend

		add	sprite_pos_x,40
		add	sprite_pos_y,80
		cmp	sprite_pos_y,478
		jae	sprtestend

		jmp	sprtestagain


    sprtestend:


		RET
sprite_test	ENDP

;---------------------------------------------------------------------

sprite_on	PROC	near	; screen to screen blit


		mov	ax,4			; 24 bpp RGB
		shl	eax,16
		mov	ax,BytesPerScanLine
		mov	edi,srcFormat
		mov	dword ptr [edi],eax


		mov	ax,0		    ; y
		shl	eax,16
		mov	ax,0		    ; x
		mov	edi,srcXY
		mov	[edi],eax

		mov	ax,size_y	    ; gif y
		shl	eax,16
		mov	ax,size_x	    ; gif x
		mov	edi,dstSize
		mov	[edi],eax

		mov	ax,sprite_pos_y     ; y
		shl	eax,16
		mov	ax,sprite_pos_x     ; x
		mov	edi,dstXY
		mov	[edi],eax

		call	sprite_save_shadow

		mov	eax,sprite_data_start
		sub	eax,display_base
		mov	edi,srcBaseAddr 	    ; !! changed
		mov	[edi],eax

	       ;mov	eax,0cc000101h	    ; immed. / screen blt.
	       ;mov	ah,11001100b	    ; = 0cch
		mov	ah,11001100b
		mov	al,0
		shl	eax,16
		mov	ax,101h
		mov	edi,command
		mov	[edi],eax     ; cmd reg.

		mov	waitcount,0
		call	_2dWaitIdle
		mov	eax,waitcount	    ; xxx debug

		mov	eax,0
		mov	edi,srcBaseAddr
		mov	[edi],eax	    ; reset


		RET
sprite_on	ENDP

;---------------------------------------------------------------------

sprite_save_shadow PROC near	; screen to screen blit
				; called from sprite_on

		mov	edi,srcXY
		mov	eax,[edi]
		push	eax		; save

;-------
		mov	esi,dstXY
		mov	eax,[esi]
		mov	[edi],eax	; srcXY = dstXY

		mov	eax,sprite_shadow_start
		sub	eax,display_base
		mov	edi,dstBaseAddr 	    ; !! changed
		mov	[edi],eax

		mov	eax,0cc000101h	    ; immed. / screen blt.
		mov	edi,command
		mov	[edi],eax     ; cmd reg.

		mov	waitcount,0
		call	_2dWaitIdle
		mov	eax,waitcount	    ; xxx debug

		mov	eax,0
		mov	edi,dstBaseAddr
		mov	[edi],eax	    ; reset

;-------

		pop	eax
		mov	edi,srcXY
		mov	[edi],eax	    ; restore


		RET
sprite_save_shadow ENDP


;---------------------------------------------------------------------

sprite_off	PROC	near	; screen to screen blit
				; sprite_restore_shadow

		mov	ax,4			; 24 bpp RGB
		shl	eax,16
		mov	ax,BytesPerScanLine
		mov	edi,srcFormat
		mov	dword ptr [edi],eax


		mov	ax,sprite_pos_y     ; y
		shl	eax,16
		mov	ax,sprite_pos_x     ; x
		mov	edi,srcXY
		mov	[edi],eax

		mov	ax,size_y	    ; gif y
		shl	eax,16
		mov	ax,size_x	    ; gif x
		mov	edi,dstSize
		mov	[edi],eax

		mov	ax,sprite_pos_y     ; y
		   ;sub     ax,1	; xxx ?
		shl	eax,16
		mov	ax,sprite_pos_x     ; x
		mov	edi,dstXY
		mov	[edi],eax

		mov	eax,sprite_shadow_start
		sub	eax,display_base
		mov	edi,srcBaseAddr 	    ; !! changed
		mov	[edi],eax


		mov	eax,0cc000101h	    ; immed. / screen blt.
		mov	edi,command
		mov	[edi],eax     ; cmd reg.

		mov	waitcount,0
		call	_2dWaitIdle
		mov	eax,waitcount	    ; xxx debug

		mov	eax,0
		mov	edi,srcBaseAddr
		mov	[edi],eax	    ; reset

		RET
sprite_off	ENDP


;---------------------------------------------------------------------
;============== TEXT =================================================
;---------------------------------------------------------------------

text_blit	PROC	near	; screen to screen text blit
				; rom-font copy is in video-mem

		mov	ax,0			; 1 bpp mono
		shl	eax,16
		mov	ax,1			; stride 1 byte
		mov	edi,srcFormat
		mov	dword ptr [edi],eax

		mov	eax,font_ptr	    ; rel. in screen buf.
		mov	edi,srcBaseAddr
		mov	[edi],eax

		mov	ax,30h		; char num.
		shl	ax,4		    ; y   (*16)
		shl	eax,16
		mov	ax,0		    ; x
		mov	edi,srcXY
		mov	[edi],eax

		mov	ax,16		    ; y
		shl	eax,16
		mov	ax,8		    ; x
		mov	edi,dstSize
		mov	[edi],eax

		mov	ax,300		    ; y
		shl	eax,16
		mov	ax,10		    ; x
		mov	edi,dstXY
		mov	[edi],eax

;---------------------------

		mov	cx,70

		mov	eax,0cc000101h	    ; immed. / screen blt.
		or	ah,00000100b	    ; inc x dest.
		mov	edi,command

    tblitagain:
		mov	[edi],eax     ; cmd reg.

		loopw	tblitagain



		RET
text_blit	ENDP

;---------------------------------------------------------------------

text_stretch_blit PROC	near	; screen to screen text blit
				    ; rom-font copy is in video-mem

		mov	ax,0			; 1 bpp mono
		or	al,00000000b
		shl	eax,16
		mov	ax,1			; stride 1 byte
		mov	edi,srcFormat
		mov	dword ptr [edi],eax

		mov	eax,font_ptr	    ; rel. in screen buf.
		mov	edi,srcBaseAddr
		mov	[edi],eax

		mov	ax,6ah		; char num.
		shl	ax,4		    ; y   (*16)
		shl	eax,16
		mov	ax,0		    ; x
		mov	edi,srcXY
		mov	[edi],eax

		mov	ax,16		    ; y
		shl	eax,16
		mov	ax,8		    ; x
		mov	edi,srcSize
		mov	[edi],eax

		mov	ax,64		    ; y
		shl	eax,16
		mov	ax,32		    ; x
		mov	edi,dstSize
		mov	[edi],eax

		mov	ax,300		    ; y
		shl	eax,16
		mov	ax,40		    ; x
		mov	edi,dstXY
		mov	[edi],eax

		mov	eax,0cc000102h	    ; immed./ scr.str.blt.
		mov	edi,command
		mov	[edi],eax     ; cmd reg.

		RET
text_stretch_blit ENDP

;---------------------------------------------------------------------

host_stretch_blt2 PROC	near	; host to screen stretch blit

		mov	ax,160
		shl	eax,16
		mov	ah,160
		mov	al,160
		mov	edi,colorFore
		mov	[edi],eax


		mov	ax,120
		shl	eax,16
		mov	ah,60
		mov	al,40
		mov	edi,colorBack
		mov	[edi],eax

		mov	ax,16		    ; y
		shl	eax,16
		mov	ax,8		    ; x
		mov	edi,srcSize
		mov	[edi],eax

		mov	ax,10		; y
		shl	eax,16
		mov	ax,150		; x
		mov	edi,dstXY
		mov	[edi],eax



		mov	eax,400000h	; mono, byte aligned
		mov	edi,srcFormat
		mov	dword ptr [edi],eax

		mov	ax,16
		shl	eax,16
		mov	ax,16
		mov	edi,dstSize
		mov	[edi],eax

		mov	eax,0
		mov	edi,srcXY
		mov	[edi],eax

		mov	eax,0cc000004h	; host strtch blt, launch
		mov	edi,command
		mov	[edi],eax


;------- 1.-----------------

		mov	edi,launchArea
		mov	esi,font_ptr_rom
		add	esi,16*65	    ; 65


		mov	ax,[esi+2]
		shl	eax,16
		mov	ax,[esi]
		mov	[edi],eax
		mov	[edi],eax
		mov	[edi],eax
		mov	[edi],eax

		mov	ax,[esi+6]
		shl	eax,16
		mov	ax,[esi+4]
		mov	[edi],eax
		mov	[edi],eax
		mov	[edi],eax
		mov	[edi],eax

		mov	ax,[esi+10]
		shl	eax,16
		mov	ax,[esi+8]
		mov	[edi],eax
		mov	[edi],eax
		mov	[edi],eax
		mov	[edi],eax

		mov	ax,[esi+14]
		shl	eax,16
		mov	ax,[esi+12]
		mov	[edi],eax
		mov	[edi],eax
		mov	[edi],eax
		mov	[edi],eax


		RET
host_stretch_blt2 ENDP

;---------------------------------------------------------------------

host_blt3	PROC	near	; host to screen blit

		mov	ax,160
		shl	eax,16
		mov	ah,160
		mov	al,160
		mov	edi,colorFore
		mov	[edi],eax


		mov	ax,120
		shl	eax,16
		mov	ah,60
		mov	al,40
		mov	edi,colorBack
		mov	[edi],eax

		mov	ax,10		; y
		shl	eax,16
		mov	ax,100		; x
		mov	edi,dstXY
		mov	[edi],eax

		mov	eax,0cc000003h	; host blt, launch
	       ;	    rrrrrrrrcyyyxxxtddpsiirirrrrcccc
		or	eax,00000000000000000000110000000000b
	       ;			    (ii=inc dst xy)
		mov	edi,command
		mov	[edi],eax

		mov	eax,400000h	; mono, byte aligned
		mov	edi,srcFormat
		mov	dword ptr [edi],eax

		mov	ax,16
		shl	eax,16
		mov	ax,8
		mov	edi,dstSize
		mov	[edi],eax

		mov	eax,0
		mov	edi,srcXY
		mov	[edi],eax


;------- 1.-----------------

		mov	edi,launchArea
		mov	esi,font_ptr_rom
		add	esi,16*65	    ; 65

		mov	ax,[esi+2]
		shl	eax,16
		mov	ax,[esi]
		mov	[edi],eax

		mov	ax,[esi+6]
		shl	eax,16
		mov	ax,[esi+4]
		mov	[edi],eax

		mov	ax,[esi+10]
		shl	eax,16
		mov	ax,[esi+8]
		mov	[edi],eax

		mov	ax,[esi+14]
		shl	eax,16
		mov	ax,[esi+12]
		mov	[edi],eax

;-------2.--------------

		mov	ax,10		; y
		shl	eax,16
		mov	ax,108		; x
		mov	edi,dstXY
	       ;mov	[edi],eax

		add	esi,16

		mov	eax,0cc000003h	; host blt, launch
		mov	edi,command
		mov	[edi],eax


		mov	edi,launchArea

		mov	ax,[esi+2]
		shl	eax,16
		mov	ax,[esi]
		mov	[edi],eax

		mov	ax,[esi+6]
		shl	eax,16
		mov	ax,[esi+4]
		mov	[edi],eax

		mov	ax,[esi+10]
		shl	eax,16
		mov	ax,[esi+8]
		mov	[edi],eax

		mov	ax,[esi+14]
		shl	eax,16
		mov	ax,[esi+12]
		mov	[edi],eax


		RET
host_blt3	ENDP

;---------------------------------------------------------------------

host_blt2	PROC	near	; host to screen blit

		mov	ax,120
		shl	eax,16
		mov	ah,60
		mov	al,40
		mov	edi,colorBack
		mov	[edi],eax

		mov	ax,10		; y
		shl	eax,16
		mov	ax,50		; x
		mov	edi,dstXY
		mov	[edi],eax

		mov	eax,0cc000003h	; host blt, launch
		mov	edi,command
		mov	[edi],eax

		mov	eax,400000h	; mono, byte aligned
		mov	edi,srcFormat
		mov	dword ptr [edi],eax

		mov	ax,7
		shl	eax,16
		mov	ax,0bh
		mov	edi,dstSize
		mov	[edi],eax

		mov	eax,0
		mov	edi,srcXY
		mov	[edi],eax

		mov	edi,launchArea
	       ;mov	eax,0c0608020h
	       ;mov	[edi],eax
	       ;mov	eax,0c460c060h
	       ;mov	[edi],eax
	       ;mov	eax,3b806ec0h
	       ;mov	[edi],eax
	       ;mov	eax,1100h
	       ;mov	[edi],eax


			; 00000000000b
			; 00001110000b
			; 00011011000b
			; 00110001100b
			; 00111111100b
			; 01100000110b
			; 01100000110b


		mov	edi,launchArea
		mov	ax,00001110000b
		shl	eax,16
		mov	ax,00000000000b
		mov	[edi],eax

		mov	ax,00110001100b
		shl	eax,16
		mov	ax,00011011000b
		mov	[edi],eax

		mov	ax,01100000110b
		shl	eax,16
		mov	ax,00111111100b
		mov	[edi],eax

		mov	ax,0
		shl	eax,16
		mov	ax,01100000110b
		mov	[edi],eax


		RET
host_blt2	ENDP

;---------------------------------------------------------------------

screen_stretch_blt2 PROC    near    ; screen to screen stretch blit

		mov	ax,4			; 24 bpp RGB
		shl	eax,16
		mov	ax,BytesPerScanLine
		mov	edi,srcFormat
		mov	dword ptr [edi],eax

		mov	ax,100		    ; y
		shl	eax,16
		mov	ax,100		    ; x
		mov	edi,srcXY
		mov	[edi],eax

		mov	ax,90		    ; y
		shl	eax,16
		mov	ax,90		    ; x
		mov	edi,srcSize
		mov	[edi],eax

		mov	ax,100		    ; y
		shl	eax,16
		mov	ax,100		    ; x
		mov	edi,dstSize
		mov	[edi],eax

		mov	ax,300
		shl	eax,16
		mov	ax,310
		mov	edi,dstXY
		mov	[edi],eax


		mov	eax,0cc000102h	    ; immed. / screen blt.
		mov	edi,command
		mov	[edi],eax     ; cmd reg.


		RET
screen_stretch_blt2 ENDP

;---------------------------------------------------------------------

screen_blt2	PROC	near	; screen to screen blit


		mov	ax,4			; 24 bpp RGB
		shl	eax,16
		mov	ax,BytesPerScanLine
		mov	edi,srcFormat
		mov	dword ptr [edi],eax


		mov	ax,100		    ; y
		shl	eax,16
		mov	ax,100		    ; x
		mov	edi,srcXY
		mov	[edi],eax

		mov	ax,160		    ; y
		shl	eax,16
		mov	ax,200		    ; x
		mov	edi,dstSize
		mov	[edi],eax

		mov	ax,300
		shl	eax,16
		mov	ax,310
		mov	edi,dstXY
		mov	[edi],eax


		mov	eax,0cc000101h	    ; immed. / screen blt.
		mov	edi,command
		mov	[edi],eax     ; cmd reg.


		RET
screen_blt2	ENDP

;---------------------------------------------------------------------

rectangle	PROC	near

		mov	ax,ys
		shl	eax,16
		mov	ax,xs
		mov	edi,dstXY
		mov	[edi],eax

		mov	ax,ye
		sub	ax,ys
		mov	bx,ax
		shl	eax,16
		mov	ax,xe
		sub	ax,xs
		mov	edi,dstSize
		mov	[edi],eax     ; dstSize

		mov	eax,5			    ; rectangle
		or	ah,1			    ; immediate
	       ;mov	eax,0cc000105h


	       ;	   pattern format-----::----stipple line
	       ;	  direction lrtb-----::: :--inc.dst.start xy
	       ;	transp.mono -------: ::: ::--------rev.lines
	       ;     xy patt.offs.-----:   : ::: :::-------initiate
	       ;     clip reg 0/1---:  :   : ::: :::  :----reserved
	       ;     rop0-------:   :  ::  : ::: :::  :  :----cmd
	       ;	    rrrrrrrrcyyyxxxtddpsiirirrrrcccc
	       ;or	eax,11001100000000000000000000000000b
		or	eax,11001100000000000000000000000000b
		mov	edi,command
		mov	[edi],eax     ; cmd reg.

	       ;mov	eax,5			    ; rectangle
	       ;mov	dword ptr [edi+112],eax     ; cmd reg.
	       ;mov	dword ptr [edi+128],0c0016h ; launch



		RET
rectangle	ENDP

;---------------------------------------------------------------------

rectangle2	PROC	near

		mov	eax,0
			  ;00000000rrrrrrrr
		mov	ax,0000000000011111b
		shl	eax,16
			  ;ggggggggbbbbbbbb
		mov	ax,0001111001111000b
		mov	edi,colorFore
		mov	[edi],eax     ; fg color


		mov	eax,0c00100h		    ; x,y
		mov	edi,dstSize
		mov	[edi],eax     ; dstSize


		mov	eax,5			    ; rectangle
		or	ah,1			    ; immediate
	       ;mov	eax,0cc000105h


	       ;	   pattern format-----::----stipple line
	       ;	  direction lrtb-----::: :--inc.dst.start xy
	       ;	transp.mono -------: ::: ::--------rev.lines
	       ;     xy patt.offs.-----:   : ::: :::-------initiate
	       ;     clip reg 0/1---:  :   : ::: :::  :----reserved
	       ;     rop0-------:   :  ::  : ::: :::  :  :----cmd
	       ;	    rrrrrrrrcyyyxxxtddpsiirirrrrcccc
	       ;or	eax,11001100000000000000000000000000b
		or	eax,11001100000000000000000000000000b
		mov	edi,command
		mov	[edi],eax     ; cmd reg.

	       ;mov	eax,5			    ; rectangle
	       ;mov	dword ptr [edi+112],eax     ; cmd reg.
	       ;mov	dword ptr [edi+128],0c0016h ; launch


		RET
rectangle2	ENDP

;---------------------------------------------------------------------

line		PROC	near

		mov	ax,ys
		shl	eax,16
		mov	ax,xs
		mov	edi,srcXY
		mov	[edi],eax     ; srcXY

		mov	ax,ye
		shl	eax,16
		mov	ax,xe
		mov	edi,dstXY
		mov	[edi],eax     ; end point

	       ;mov	ax,6			    ; line
	       ;or	ah,1			    ; immediate
	       ;or	eax,0cc000000h
		mov	eax,0cc000106h
		mov	edi,command
		mov	[edi],eax     ; cmd reg.

		RET
line		ENDP

;---------------------------------------------------------------------

line2		PROC	near


		mov	eax,0
			  ;00000000rrrrrrrr
		mov	ax,0000000000000001b
		shl	eax,16
			  ;ggggggggbbbbbbbb
		mov	ax,0000111011111000b
		mov	edi,colorFore
		mov	[edi],eax     ; fg color

		mov	eax,0
			  ;rrrrrggggggbbbbb
		mov	ax,33h
		mov	edi,colorBack
		mov	[edi],eax     ; bg color


		mov	eax,200010h
		mov	edi,srcXY
		mov	[edi],eax     ; srcXY

		mov	eax,01100220h
		mov	edi,dstXY
		mov	[edi],eax     ; end point

		mov	ax,1100110000000000b
		shl	eax,16
		mov	ax,6			    ; line
		or	ah,1			    ; immediate
	       ;mov	eax,0cc000106h
		mov	edi,command
		mov	[edi],eax     ; cmd reg.


		RET
line2		ENDP

;---------------------------------------------------------------------

set_color	PROC	near	; r,g,b

		mov	ah,0
		mov	al,r
		shl	eax,16
		mov	ah,g
		mov	al,b
		mov	edi,colorFore
		mov	[edi],eax

		RET
set_color	ENDP

;---------------------------------------------------------------------

cls		PROC	near	    ; clear screen (640*480)

		mov	r,0
		mov	g,0
		mov	b,0
		call	set_color

		mov	xs,0
		mov	ys,0
		mov	xe,639
		mov	ye,479
		call	rectangle

		RET
cls		ENDP


;=====================================================================
;---------------------------------------------------------------------

		.DATA

;------- for accelerated text ----------------------------------------

text_char	db	0		; cur ascii

text_x		dw	0		; text cursor x
text_y		dw	0

text_x_start	dw	0
text_y_start	dw	0

text_x_end	dw	79	; 79  for 640*480
text_y_end	dw	29	; 29  for 640*480

text_fore_r	db	140	; text color fore  r
text_fore_g	db	140	; text color fore  g
text_fore_b	db	140	; text color fore  b

text_back_r	db	120	; text color back  r
text_back_g	db	0	; text color back  g
text_back_b	db	0	; text color back  b


;---------------------------------------------------------------------

		.CODE

;---------------------------------------------------------------------

text_test	PROC	near

		jmp	tt2		; jump over debug

		mov	text_x,0	; set cursor
		mov	text_y,0

		mov	al,"*"
		call	a_writt_al

		mov	al,"#"
		mov	text_x,2
		mov	text_y,1
		call	a_writt_al

		mov	text_y,29

    tsttxtagain:
		mov	ah,0
		int	16h
		cmp	ah,1		; esc ?
		je	tsttxtend
		call	a_writt_al
		jmp	tsttxtagain
    tsttxtend:

;----------------------------------------

    tt2:

		mov	text_x,0	; set cursor
		mov	text_y,0

		mov	al,0

		mov	cx,255
    ttagain2:
		push	cx
		mov	cx,80
    ttagain1:
		call	a_writt_al
		loopw	ttagain1

		pop	cx
		add	al,1
		loopw	ttagain2


		mov	edi,offset msg_text_test
		call	a_out_msg_edi

		mov	ah,0
		int	16h


		RET
text_test	ENDP

;---------------------------------------------------------------------

a_out_msg_edi	PROC	near	; accelerated, using text_x, _y
				    ; edi points to asciiz

		push	eax
		push	edi

    aomsgediagain:
		mov	al,byte ptr [edi]
		cmp	al,0
		je	aomsgediend

		call	a_writt_al

		add	edi,1
		jmp	aomsgediagain

    aomsgediend:

		pop	edi
		pop	eax

		RET
a_out_msg_edi	ENDP

;---------------------------------------------------------------------

a_writt_al	PROC	near	; accelerated writt, ascii in al

		push	eax
		push	edi

		mov	text_char,al

		cmp	al,0dh		    ; cr ?
		jne	awanocr
		mov	text_x,0
		pop	edi
		pop	eax
		RET
    awanocr:
		cmp	al,0ah		    ; lf ?
		jne	awanolf
		jmp	awalf
    awanolf:

		call	set_text_color
	       ;call	a_wr_char
		call	dword ptr addr_a_wr_char    ; bugfix

		mov	ax,text_x
		cmp	ax,text_x_end
		jnae	awaeiter1
    awalf:
		mov	text_x,-1

		mov	ax,text_y
		cmp	ax,text_y_end
		jnae	awaeiter2
		call	a_scroll_up
		add	text_back_r,80	    ; xxx debug
		jmp	awaeiter1
    awaeiter2:
		add	text_y,1
    awaeiter1:
		add	text_x,1

		pop	edi
		pop	eax

		RET
a_writt_al	ENDP

;---------------------------------------------------------------------

addr_a_wr_char	dd	offset a_wr_char

  ; normally a_wr_char, if setup finds "dos under windows" it sets
  ; the address to a_wr_char_hst to fix the bug that sometimes occured
  ;						    (text not readable)

;---------------------------------------------------------------------

a_wr_char	PROC	near	; accelerated, ascii in text_char

		mov	ax,0			; 1 bpp mono
		shl	eax,16
		mov	ax,1			; stride 1 byte
		mov	edi,srcFormat
		mov	dword ptr [edi],eax
				    ; xxxx ev. src format= 400000h ?


		mov	eax,font_ptr	    ; rel. in screen buf.
		mov	edi,srcBaseAddr
		mov	[edi],eax

		mov	ax,0		; char num.
		mov	al,text_char
		shl	ax,4		    ; y   (*16)
		shl	eax,16
		mov	ax,0		    ; x
		mov	edi,srcXY
		mov	[edi],eax

		mov	ax,16		    ; y
		shl	eax,16
		mov	ax,8		    ; x
		mov	edi,dstSize
		mov	[edi],eax

		mov	ax,text_y	    ; y
		shl	ax,4		    ; *16
		shl	eax,16
		mov	ax,text_x	    ; x
		shl	ax,3		    ; *8
		mov	edi,dstXY
		mov	[edi],eax

		mov	eax,0cc000101h	    ; immed. / screen blt.
		or	ah,00000100b	    ; inc x dest.
		mov	edi,command
		mov	[edi],eax     ; cmd reg.

		mov	eax,0
		mov	edi,srcBaseAddr
		mov	[edi],eax	    ; reset to 0

		RET
a_wr_char	ENDP

;---------------------------------------------------------------------

a_wr_char_hst	PROC	near	; accelerated, ascii in text_char
				; host to screen blit

		push	esi

	       ;mov	ax,0			; 1 bpp mono
	       ;shl	eax,16
	       ;mov	ax,1			; stride 1 byte
		mov	eax,400000h
		mov	edi,srcFormat
		mov	dword ptr [edi],eax

		mov	ax,text_y	    ; y
		shl	ax,4		    ; *16
		shl	eax,16
		mov	ax,text_x	    ; x
		shl	ax,3		    ; *8
		mov	edi,dstXY
		mov	[edi],eax

		mov	ax,16		    ; y
		shl	eax,16
		mov	ax,8		    ; x
		mov	edi,dstSize
		mov	[edi],eax

		mov	eax,0
		mov	edi,srcXY
		mov	[edi],eax


		mov	esi,font_ptr_rom

		mov	eax,0
		mov	al,text_char	; char num.
		shl	ax,4		    ; y   (*16)
		add	esi,eax


		mov	eax,0cc000003h	; host blt, launch
		mov	edi,command
		mov	[edi],eax


		mov	edi,launchArea

		mov	ax,[esi+2]
		shl	eax,16
		mov	ax,[esi]
		mov	[edi],eax

		mov	ax,[esi+6]
		shl	eax,16
		mov	ax,[esi+4]
		mov	[edi],eax

		mov	ax,[esi+10]
		shl	eax,16
		mov	ax,[esi+8]
		mov	[edi],eax

		mov	ax,[esi+14]
		shl	eax,16
		mov	ax,[esi+12]
		mov	[edi],eax


		pop	esi

		RET
a_wr_char_hst	ENDP

;---------------------------------------------------------------------

a_scroll_up	PROC	near	; for text

		mov	ax,4		    ; 24 bpp RGB  xxxx!
		shl	eax,16
		mov	ax,BytesPerScanLine
		mov	edi,srcFormat
		mov	dword ptr [edi],eax

		mov	ax,16		    ; y  (16)
		shl	eax,16
		mov	ax,0		    ; x
		mov	edi,srcXY
		mov	[edi],eax

		mov	ax,464		    ; y  (480-16)
		shl	eax,16
		mov	ax,640		    ; x  (640)
		mov	edi,dstSize
		mov	[edi],eax

		mov	ax,0		    ; y     448 (-18)
		shl	eax,16
		mov	ax,0		    ; x
		mov	edi,dstXY
		mov	[edi],eax

		mov	eax,0cc000101h	    ; immed. / screen blt.
		mov	edi,command
		mov	[edi],eax     ; cmd reg.

;------- del. last line ------------------------


		mov	ax,text_y_end
		shl	ax,4		    ; *16
		shl	eax,16
		mov	ax,text_x_start
		shl	ax,3		    ; *8
		mov	edi,dstXY
		mov	[edi],eax

		mov	ax,text_y_end
		sub	ax,text_y_start
		shl	eax,16
		mov	ax,text_x_end
		sub	ax,text_x_start
		add	ax,1
		shl	ax,3		    ; *8
		mov	edi,dstSize
		mov	[edi],eax     ; dstSize

		mov	eax,000000105h	    ; rect. immed.
						; rop0=0
		mov	edi,command
		mov	[edi],eax     ; cmd reg.

		RET
a_scroll_up	ENDP

;---------------------------------------------------------------------

set_text_color	PROC	near	; text r,g,b   fore + back
				; colorFore +back destroyed

		mov	ah,0
		mov	al,text_fore_r
		shl	eax,16
		mov	ah,text_fore_g
		mov	al,text_fore_b
		mov	edi,colorFore
		mov	[edi],eax

		mov	ah,0
		mov	al,text_back_r
		shl	eax,16
		mov	ah,text_back_g
		mov	al,text_back_b
		mov	edi,colorBack
		mov	[edi],eax

		RET
set_text_color	ENDP

;=====================================================================
;---------------------------------------------------------------------

msg_dump	db	"hello, this is dump  ",0

dump_reg_count	db	0

;---------------------------------------------------------------------

dump_2d_registers PROC	near	; dump all 2d register contents
				;  to the screen

		mov	ah,2	    ; function nr
		mov	bh,0	    ; curpa
		mov	dl,0	    ; pos_x
		mov	dh,0	    ; pos_y
		int	10h	    ; set cursor


		mov	edi,offset msg_dump
	       ;call	out_msg_edi

		mov	dump_reg_count,0    ; init register count
		mov	edi,_2dBase

;-----------------------

		mov	cx,9
    dmp2dragain2:
		push	cx

		mov	cx,4

    dmp2dragain1:

		mov	al,dump_reg_count
		call	wr_2_hex
		call	space
		mov	al,":"
		call	writt_al
		call	space

	       ;mov	eax,12345678h	    ; xxx debug
		mov	eax,[edi]
		call	wr_8_hex

		call	four_space
		add	dump_reg_count,1
		add	edi,4

		loopw	dmp2dragain1

		pop	cx
		call	crlf

		loopw	dmp2dragain2

;---------




		RET
dump_2d_registers ENDP

;=====================================================================
;---------------------------------------------------------------------

reset_2d	PROC	near	    ; 2d graphics reset

		mov	edi,_ioBase
		add	edi,10h 	; to miscInit0 register
		mov	eax,[edi]
		or	ax,00100000b	; set 2d reset Bit
		mov	[edi],eax
		and	ax,11011111b	; clear 2d reset Bit
		mov	[edi],eax

		call	_2dwaitIdle

		RET
reset_2d	ENDP

;---------------------------------------------------------------------

_2dwaitIdle	PROC	near	; wait until 2d engine is idle

		push	edi

		mov	edi,status
		sub	waitcount,1	; xxx debug
    _2dbusy:
		add	waitcount,1	; xxx debug
		test	dword ptr [edi],400h
					    ; test bit 10 (2d idle)
		jnz	_2dbusy

		pop	edi

		RET
_2dwaitIdle	ENDP

;---------------------------------------------------------------------

setup_640_24	PROC	near	; 640*480, 24 bpp (8:8:8)

;------- set srcFormat -----

		mov	ax,4			; 24 bpp RGB
		shl	eax,16
		mov	ax,BytesPerScanLine
		mov	edi,srcFormat
		mov	dword ptr [edi],eax


;------- set dstFormat -----

		mov	ax,4			; 24 bpp RGB
		shl	eax,16
		mov	ax,BytesPerScanLine
		mov	edi,dstFormat
		mov	dword ptr [edi],eax

;------- set clip ----------

		mov	ax,0		    ; min. y
		shl	eax,16
		mov	ax,0		    ; min. x
		mov	edi,clip0Min
		mov	[edi],eax	    ; clip0Min

		mov	ax,480		    ; max. y +1
		shl	eax,16
		mov	ax,640		    ; max. x +1

		mov	edi,clip0Max
		mov	[edi],eax	    ; clip0Max

;------- srcBase = 0 -------

		mov	eax,0
		mov	edi,srcBaseAddr
		mov	[edi],eax      ; srcBaseAddr

;------- dstBase = 0 -------

		mov	eax,0
		mov	edi,dstBaseAddr
		mov	[edi],eax      ; dstBaseAddr

;------- commandExtra = 0 --

		mov	eax,0
		mov	edi,commandExtra
		mov	[edi],eax      ; commandExtra


;------- load rom font -----

		call	load_font	; to screen mem + set ptr

;------- setup for sprites -

		call	setup_sprites	; set ptrs for sprite sys.

;------- bugfix text -------

		call	chk_win_or_dos
		cmp	win_flag,1
		jne	stup64024_dos	    ; xxxx deactivated

		mov	eax,offset a_wr_char_hst    ; host to screen
	       mov     addr_a_wr_char,eax      ; change def. addr.
    stup64024_dos:			; no change needed for dos

		RET
setup_640_24	ENDP

;---------------------------------------------------------------------

win_flag	db	0	; 0 = dos only, 1 = dos under windows

cur_dir_n_buffer db	260 dup (0),0

;---------------------------------------

chk_win_or_dos	PROC	near	;


		mov	ax,7147h	; LFN, get current dir
		mov	dl,0		; drive (0=current)
		mov	si,offset cur_dir_n_buffer  ; for return
		clc
		int	21h
		jc	DosOnly

		mov	win_flag,1

		RET

    DosOnly:
		mov	win_flag,0


		RET
chk_win_or_dos	ENDP

;---------------------------------------------------------------------

setup_sprites	PROC	near	; called from setup_640_24
				; set ptrs for sprite sys.

		mov	eax,display_base	; LFB start
		mov	ebx,page_len

		mov	page_0_base,eax     ; same as display_base
		add	eax,ebx
		mov	page_1_base,eax     ; same as draw_pag_base
		add	eax,ebx
		mov	page_2_base,eax     ; reserved (3-buff ?)
		add	eax,ebx
		mov	page_3_base,eax     ; sprite shadow
		mov	sprite_shadow_start,eax     ; same
		add	eax,ebx
		mov	page_4_base,eax     ; sprite data start
		mov	sprite_data_start,eax


		RET
setup_sprites	ENDP

;---------------------------------------------------------------------

load_font	PROC	near	; called from setup_640_24
				; from rom to screen mem
				; for screen - blit

;------- get font ptr ------

		mov	rm_eax,1130h	; funct.
		mov	rm_ebx,600h	; (6) rom 8*16
					; (1) int 43 ptr

		mov	ax,300h     ; simulate rm int
		mov	bl,10h	    ; int nr.
		mov	bh,0	    ; flags (0)
		mov	cx,0	    ; stack words to copy (0)
		mov	edi,offset rm_call_struc
		int	31h

		;jnc

		mov	eax,0
		mov	ax,rm_es
		shl	eax,4
		mov	ebx,rm_ebp
		and	ebx,0ffffh	; mask high off
		add	eax,ebx
		mov	font_ptr_rom,eax

;------- copy font to video mem ----

		mov	eax,font_ptr_rom
		mov	edi,eax 	    ; from

		mov	ax,TotalMemory	  ; from vbe (64k blocks)
		shl	eax,16
		sub	eax,16*256	; font size 8*16
		mov	font_ptr,eax		; for GPU
		add	eax,display_base
		mov	font_ptr_video,eax	; for CPU
		mov	esi,eax 	    ; to

		mov	cx,16*256	; font size
    s63fagain:
		mov	al,byte ptr [edi]
		mov	byte ptr [esi],al
		add	edi,1
		add	esi,1
		loopw	s63fagain


		RET
load_font	ENDP

;=====================================================================
;---------------------------------------------------------------------

		.DATA

;---------------------------------------------------------------------

bus_num 	db	0		; bus number
dev_func_num	db	0		; device/function number

memBaseAddr0	dd	0		; (init/2d/3d regs.)
memBaseAddr1	dd	0		; (LFB)
ioBaseAddr	dd	0		; (IO)

;---------------------------------------

_ioBase 	dd	0		; mapped memBaseAddr0
					    ; = io register remap
_2dBase 	dd	0		; 2d registers
_3dBase 	dd	0		; 3d registers

;---------------------------------------------------------------------

		.CODE

;---------------------------------------------------------------------

pci_check	PROC	near

;---------------------------------------------------------------------

		mov	ax,0b101h	; installation check
		mov	edi,0
		int	1ah

		jnc	noerr
		mov	edi,offset pci_b_nfound
		call	out_msg_edi_exit
		jmp	prg_exit
    noerr:
		cmp	edx," ICP"	; signature
		cmp	edi,0		; PM entry point if not 0
		cmp	bh,2		; level major (bcd)
		cmp	bl,0		; level minor (bcd

;---------------------------------------------------------------------

		mov	ax,0b102h	; find pci device
		mov	cx,5		; device id (5 = avenger)
		mov	dx,121ah	; vendor id (121ah = 3dfx)
		mov	si,0		; device index
		int	1ah

		jnc	fpnoerr
		mov	edi,offset v3_nfound
		call	out_msg_edi_exit
		jmp	prg_exit
    fpnoerr:
		mov	bus_num,bh
		mov	dev_func_num,bl

;---------------------------------------------------------------------

		mov	ax,0b10ah	; read config dword
		mov	bh,bus_num
		mov	bl,dev_func_num
		mov	di,16		; register num (addr)
		int	1ah

		jnc	ra0noerr
		mov	edi,offset err_config_r
		call	out_msg_edi_exit
		jmp	prg_exit
    ra0noerr:
		mov	memBaseAddr0,ecx

;---------------------------------------------------------------------

		mov	ax,0b10ah	; read config dword
		mov	bh,bus_num
		mov	bl,dev_func_num
		mov	di,20		; register num (addr)
		int	1ah

		jnc	ra1noerr
		mov	edi,offset err_config_r
		call	out_msg_edi_exit
		jmp	prg_exit
    ra1noerr:
		mov	memBaseAddr1,ecx

;---------------------------------------------------------------------

		mov	ax,0b10ah	; read config dword
		mov	bh,bus_num
		mov	bl,dev_func_num
		mov	di,24		; register num (addr)
		int	1ah

		jnc	ioanoerr
		mov	edi,offset err_config_r
		call	out_msg_edi_exit
		jmp	prg_exit

    ioanoerr:
		mov	ioBaseAddr,ecx

		RET
pci_check	ENDP

;---------------------------------------------------------------------

map_2d3dregs	PROC	near	; memBaseAddr0 -> _2dBase, _3dBase
				; (physical memory mapping)
				; + _ioBase

		mov	ebx,memBaseAddr0
		mov	cx,bx
		shr	ebx,16		; = BX:CX

		mov	eax,2000000h	; 32 M (32M, 2 + 6*`0)
		shr	eax,16
		mov	si,ax		; (64K Blocks)
		mov	di,0		; = SI:DI = Size

		mov	ax,800h
		int	31h

		jnc	mapr_noerr
		mov	edi,offset err_map_2d3d_r
		call	out_msg_edi_exit
		jmp	prg_exit

    mapr_noerr:

		mov	eax,0
		mov	ax,bx
		shl	eax,16
		mov	ax,cx
		mov	_ioBase,eax
					; cmd/AGP transfer/Misc
		add	eax,100000h
		mov	_2dBase,eax
		add	eax,100000h
		mov	_3dBase,eax
					; TMU0 texture download
					; TMU1 texture download
					    ; reserved
					    ; YUV
					    ; 3dLFB space

		RET
map_2d3dregs	ENDP

;---------------------------------------------------------------------

set_all_2d_reg_addr PROC    near    ; set all 2d register addresses
				    ; for easy text adressing (?)

		mov	eax,_2dBase	    ; base address
		mov	ebx,4		    ; adder

		mov	status,eax	    ; (+0)
		add	eax,ebx
		mov	intCtrl,eax	    ; (+4)
		add	eax,ebx
		mov	clip0Min,eax	    ; (+8)
		add	eax,ebx
		mov	clip0Max,eax	    ; (+12)
		add	eax,ebx
		mov	dstBaseAddr,eax     ; (+16)
		add	eax,ebx
		mov	dstFormat,eax	    ; (+20)
		add	eax,ebx
		mov	srcColorkeyMin,eax  ; (+24)
		add	eax,ebx
		mov	srcColorkeyMax,eax  ; (+28)
		add	eax,ebx
		mov	dstColorkeyMin,eax  ; (+32)
		add	eax,ebx
		mov	dstColorkeyMax,eax  ; (+36)
		add	eax,ebx
		mov	bresError0,eax	    ; (+40)
		add	eax,ebx
		mov	bresError1,eax	    ; (+44)
		add	eax,ebx
		mov	rop,eax 	    ; (+48)
		add	eax,ebx
		mov	srcBaseAddr,eax     ; (+52)
		add	eax,ebx
		mov	commandExtra,eax    ; (+56)
		add	eax,ebx
		mov	lineStipple,eax     ; (+60)
		add	eax,ebx
		mov	lineStyle,eax	    ; (+64)
		add	eax,ebx
		mov	pattern0Alias,eax   ; (+68)
		add	eax,ebx
		mov	pattern1Alias,eax   ; (+72)
		add	eax,ebx
		mov	clip1Min,eax	    ; (+76)
		add	eax,ebx
		mov	clip1Max,eax	    ; (+80)
		add	eax,ebx
		mov	srcFormat,eax	    ; (+84)
		add	eax,ebx
		mov	srcSize,eax	    ; (+88)
		add	eax,ebx
		mov	srcXY,eax	    ; (+92)
		add	eax,ebx
		mov	colorBack,eax	    ; (+96)
		add	eax,ebx
		mov	colorFore,eax	    ; (+100)
		add	eax,ebx
		mov	dstSize,eax	    ; (+104)
		add	eax,ebx
		mov	dstXY,eax	    ; (+108)
		add	eax,ebx
		mov	command,eax	    ; (+112)
		add	eax,ebx
		mov	RESERVED_116,eax      ; (+116)
		add	eax,ebx
		mov	RESERVED_120,eax      ; (+120)
		add	eax,ebx
		mov	RESERVED_124,eax      ; (+124)
		add	eax,ebx
		mov	launchArea,eax	    ; (+128) to (+255)
		add	eax,128
		mov	colorPattern,eax    ; (+256) to (+508)


		RET
set_all_2d_reg_addr ENDP

;=====================================================================
;---------------------------------------------------------------------

trans_gif	PROC	near

		mov	curx,100
		mov	cury,100
		call	calc_esi	    ; (for 8:8:8 modes)

		mov	edi,gif_loc
		mov	ax,word ptr [edi]   ; size_x
		mov	size_x,ax
		mov	ax,word ptr [edi+2] ; size_y
		mov	size_y,ax
		add	edi,4		    ; to pic start

		mov	ebp,pal_loc

;-------------------

		mov	cx,size_y

    trgifagain2:
		push	esi

;------- line ------
		push	cx

		mov	cx,size_x

		mov	eax,0
    trgifagain1:
		mov	ax,0
		mov	al,byte ptr [edi]
		mov	bx,ax
		shl	ax,1
		add	ax,bx

		mov	bl,byte ptr [ebp+eax]	; palette  red
		shl	bl,2
		mov	bh,byte ptr [ebp+eax+1]   ; palette  green
		shl	bh,2
		mov	dl,byte ptr [ebp+eax+2]   ; palette  blue
		shl	dl,2
		mov	byte ptr [esi+2],bl	; red
		mov	byte ptr [esi+1],bh	; green
		mov	byte ptr [esi+0],dl	; blue
		add	edi,1
		add	esi,3
		loopw	trgifagain1

		pop	cx

;-------------------
		pop	esi
		mov	eax,0
		mov	ax,BytesPerScanLine
		add	esi,eax
		loopw	trgifagain2

		RET
trans_gif	ENDP

;---------------------------------------------------------------------

trans_gif_to_sprite PROC    near    ; (v3) first sprite at
				    ;  sprite_data_start (page 3)
				    ;	8:8:8 mode

		mov	curx,100
		mov	cury,100
		mov	esi,sprite_data_start

		mov	edi,gif_loc
		mov	ax,word ptr [edi]   ; size_x
		mov	size_x,ax
		mov	ax,word ptr [edi+2] ; size_y
		mov	size_y,ax
		add	edi,4		    ; to pic start

		mov	ebp,pal_loc

;-------------------

		mov	cx,size_y

    trgiftsagain2:
		push	esi

;------- line ------
		push	cx

		mov	cx,size_x

		mov	eax,0
    trgiftsagain1:
		mov	ax,0
		mov	al,byte ptr [edi]
		mov	bx,ax
		shl	ax,1
		add	ax,bx

		mov	bl,byte ptr [ebp+eax]	; palette  red
		shl	bl,2
		mov	bh,byte ptr [ebp+eax+1]   ; palette  green
		shl	bh,2
		mov	dl,byte ptr [ebp+eax+2]   ; palette  blue
		shl	dl,2
		mov	byte ptr [esi+2],bl	; red
		mov	byte ptr [esi+1],bh	; green
		mov	byte ptr [esi+0],dl	; blue
		add	edi,1
		add	esi,3
		loopw	trgiftsagain1

		pop	cx

;-------------------
		pop	esi
		mov	eax,0
		mov	ax,BytesPerScanLine
		add	esi,eax
		loopw	trgiftsagain2

		RET
trans_gif_to_sprite ENDP

;---------------------------------------------------------------------

loadgif 	PROC	    near    ; other proc`s name is _loadgif

;--------------- open gif ------------------------------

		mov	    edx,offset filename_read
		mov	    al,0	    ; read access
		mov	    ah,3dh
		int	    21h 	    ; open file
		jnc	    open_ok
	       ;mov	    edi,offset msg_open_err ; error code in al
	       ;call	    out_msg_edi
		call	    prg_abort
    open_ok:
		mov	    filehandle_read,ax	     ; insert handle

;---------------------------------------------------------------------
	    ; alloc mem

		mov	    ax,0ff11h		; GetMemLinear32
		mov	    ecx,100000
		int	    31h
		jnc	    alloc_r_ok
	       ;mov	    edi,offset msg_alloc_r_err
	       ;call	    out_msg_edi
		call	    prg_abort
    alloc_r_ok:
		mov	    free_mem,esi


;---------------------------------------------------------------------

; Loadgif - simple GIF decoder
; In:
;    EDX - location of free memory to put palette and decoded GIF string
;    EAX - stream input routine (In:ECX=len,EDX->buf, Out:EAX=len,CF=1 error)
;    ECX - temp storage for LZW prefixs (4096*2*3=24576 length)
; Out:
;   CF=1 - Error decoding file
;   CF=0 - File decoded succesfully
;    EBX - location of palette - if EBX = EDX, then there is no palette in GIF
;    ECX - length of decoded GIF   - might not equal x*y (should,but might not)
;    EDX - location of decoded GIF - first two words are x and y size
;     AX - number of colours in GIF

;---------------------------------------------------------------------

	    mov     ecx,free_mem		    ; mem
	    mov     eax,offset read_file_spez
	    mov     edx,ecx
	    add     edx,8000h

	    call	_loadgif

	    jnc 	loadok

	    call    prg_abort


    loadok:

		mov	    gif_num_colors,ax
		mov	    pal_loc,ebx
		mov	    gif_len,ecx
		mov	    gif_loc,edx



		RET
loadgif 	ENDP

;---------------------------------------------------------------------

calc_esi	PROC	    near    ; display_base, curx, cury
				    ; for set_pixel,...
				    ; esi changed, eax destroyed
				    ; (for 8:8:8 modes)
		push	    bx
		push	    edx

		mov	    esi,display_base
		mov	    eax,0
		mov	    ax,BytesPerScanLine
		mov	    bx,cury
		mul	    bx
		shl	    edx,16
		mov	    dx,ax
		add	    esi,edx
		mov	    eax,0
		mov	    ax,curx
		shl	    ax,1	; *2
		add	    ax,curx	; =*3
		add	    esi,eax

		pop	    edx
		pop	    bx

		RET
calc_esi	ENDP


;---------------------------------------------------------------------
;+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;---------------------------------------------------------------------
; Filename     : Loadgif.asm
; Included from: Main Assembley Module
; Description  : Gif and LZW decoding routines.  Written based on Rich
;                Geldreich's QBasic version.
;
; Written by: John McCarthy

;---------------------------------------------------------------------

; define externals

;	 include pmode.ext		; protected mode externals
;	 include file.ext
;	 include macros.inc

         public _loadgif
         public _loadgif_lzw
         public _loadgif_getdword
         public _loadgif_getword
         public _loadgif_getbyte
         public _loadgif_input

_loadgif_input dd 0
gifmem         dd 0
palettemem     dd 0
prefixmem      dd 0
numcolours     dw 0                         ; number of colours in GIF
nopalette      db 0                         ; global or local colour map
_background    db 0                         ; _background indexer in GIF
xlength        dw 0                         ; x and y size of GIF
ylength        dw 0

buflen   = 128
bufleft  dd 0                               ; number of bytes left in byte buffer
bufptr   dd 0                               ; current buffer pointer
bytebuffer db buflen dup (0)                ; buffers for load (speeds disk loading alot)

;같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같
;
; Loadgif - simple GIF decoder
; In:
;    EDX - location of free memory to put palette and decoded GIF string
;    EAX - stream input routine (In:ECX=len,EDX->buf, Out:EAX=len,CF=1 error)
;    ECX - temp storage for LZW prefixs (4096*2*3=24576 length)
; Out:
;   CF=1 - Error decoding file
;   CF=0 - File decoded succesfully
;    EBX - location of palette - if EBX = EDX, then there is no palette in GIF
;    ECX - length of decoded GIF   - might not equal x*y (should, but might not)
;    EDX - location of decoded GIF - first two words are x and y size
;     AX - number of colours in GIF
;
;같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같

_loadgif:
         mov _loadgif_input,eax
         mov gifmem,edx
         mov palettemem,edx
         mov prefixmem,ecx
kkjj:
         call _loadgif_getdword
         jc error_in_gif

         cmp eax,"8FIG"                     ; check GIF8
         jne error_in_gif

         call _loadgif_getword              ; skip "7a" part of GIF
         jc error_in_gif

         call _loadgif_getword              ; skip totalx
         jc error_in_gif

         call _loadgif_getword              ; skip totaly
         jc error_in_gif

         call _loadgif_getbyte              ; numcolours
         jc error_in_gif

         push ax

         and al,7
         mov cl,al
         inc cl
         mov ax,1
         shl ax,cl
         mov numcolours,ax

         pop ax
         and al,128
         xor al,128
         mov nopalette,al

         call _loadgif_getbyte
         jc error_in_gif
         mov _background,al

         call _loadgif_getbyte
         jc error_in_gif
         cmp al,0                           ; ? "Bad screen descriptor in GIF":end
         jne error_in_gif

         cmp nopalette,0
         jne do05

         mov cx,numcolours
         mov ax,3
         mul cx                             ; ax = numcolours*3
         movzx ecx,ax
         mov edx,gifmem
         add gifmem,ecx
         push ecx
         push edx
morepal:
         call _loadgif_getbyte
         mov [edx],al
         inc edx
         loop morepal
         pop esi
         pop ecx
         jc error_in_gif
divloop:
         shr byte ptr [esi],2               ; adjust palette from 8 bit to 6 bit
         inc esi
         loop divloop
do05:
         call _loadgif_getbyte
         jc error_in_gif
         cmp al,44
         je exitdo
         cmp al,33
         jne error_in_gif                   ; ? "Unknown extension type":end

         call _loadgif_getbyte
         jc error_in_gif
do10:
         call _loadgif_getbyte
         jc error_in_gif
         movzx ecx,al
         jcxz do05
do20:
         push ecx
         call _loadgif_getbyte
         pop ecx
         jc error_in_gif
         loop do20

         jmp do10
exitdo:
         call _loadgif_getword              ; skip image left and top
         jc error_in_gif
         call _loadgif_getword
         jc error_in_gif

         call _loadgif_getword
         jc error_in_gif
         mov xlength,ax
         call _loadgif_getword
         jc error_in_gif
         mov ylength,ax

         call _loadgif_getbyte
         jc error_in_gif
         test al,128+64
         jnz error_in_gif                   ; ? "Can't handle local colormaps or interlaced GIFs":end

         mov edx,gifmem
         mov ax,xlength                     ; set x and y size as first two words in decoded file
         mov [edx],ax
         mov ax,ylength
         mov [edx+2],ax

         add edx,4
         mov eax,_loadgif_input
         mov ecx,prefixmem
         call _loadgif_lzw

         mov edx,gifmem
         mov ebx,palettemem
         mov ax,numcolours
         ret

error_in_gif:
         mov bufleft,0
         mov bufptr,0
         stc
         ret

;같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같
;
; Decode_LZW - simple LZW decoder
; In:
;    ECX - temp storage for LZW prefixs (4096*2*3=24576 length)
;    EDX - memory location for decoded file
;    EAX - stream input routine (In:ECX=len,EDX->buf, Out:EAX=len,CF=1 error)
; Out:
;   CF=1 - Error decoding file
;   CF=0 - File decoded succesfully
;    ECX - length of decoded file
;    EDX - memory location of decoded file
;
;같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같

clearcode     dd 0
eoscode       dd 0
firstcode     dd 0
nextcode      dd 0
startmaxcode  dd 0
maxcode       dd 0
startcodesize dd 0
codesize      dd 0
curcode       dd 0
lastcode      dd 0
lastpixel     dd 0
lastchar      dd 0
stackpointer  dd 0
codex         dd 0

bitsin        dd 0
blocksize     dd 0
blockpointer  dd 0
decodemem     dd 0
decodememsav  dd 0

prefix   dd 0
suffix   dd 0
outstack dd 0
ybase    dd 0
workcode dd 0
spaces   db 256 dup (0)

_loadgif_lzw:
         mov _loadgif_input,eax
         mov decodemem,edx
         mov decodememsav,edx               ; save starting code location

         mov prefix,ecx
         add ecx,4096*2
         mov suffix,ecx
         add ecx,4096*2
         mov outstack,ecx

         call init_decode
         jc error_in_decode

         call decode0
         jc error_in_decode

         mov edx,decodememsav
         mov ecx,decodemem
         sub ecx,edx
         clc
         mov bufleft,0
         mov bufptr,0
         ret

error_in_decode:
         mov bufleft,0
         mov bufptr,0
         stc
         ret

shiftout dd 128
         dd 64
         dd 32
         dd 16
         dd 8
         dd 4
         dd 2
         dd 1

powersof2 dd 1
         dd 2
         dd 4
         dd 8
         dd 16
         dd 32
         dd 64
         dd 128
         dd 256
         dd 512
         dd 1024
         dd 2048

init_decode:
         call _loadgif_getbyte
         jc error_in_decode
         mov edx,eax
         mov eax,powersof2[eax*4]
         mov clearcode,eax
         mov eoscode,eax
         add eoscode,1
         mov firstcode,eax
         add firstcode,2
         mov nextcode,eax
         add nextcode,2
         mov startcodesize,edx
         inc startcodesize
         mov codesize,edx
         inc codesize
         mov ebx,powersof2[edx*4+4]
         dec ebx
         mov startmaxcode,ebx
         mov maxcode,ebx

         mov bitsin,0
         mov blocksize,0
         mov blockpointer,1

         ret
decode0:
         call getcode
         jc error_in_decode

         mov eax,codex
         cmp eax,eoscode
         je end_of_decode

         mov eax,codex
         cmp eax,clearcode
         jne else0

         mov ebx,firstcode
         mov nextcode,ebx
         mov ebx,startcodesize
         mov codesize,ebx
         mov ebx,startmaxcode
         mov maxcode,ebx
         call getcode
         jc error_in_decode
         mov eax,codex
         mov curcode,eax
         mov lastcode,eax
         mov lastpixel,eax

         mov edx,decodemem
         mov [edx],al
         inc decodemem

         jmp level0

else0:
         mov curcode,eax
         mov stackpointer,0

         cmp eax,nextcode
         ja error_in_decode
         jne dowhile1

         mov ebx,lastcode
         mov curcode,ebx

         mov ecx,stackpointer
         mov ebx,lastpixel
         mov edi,outstack
         mov [edi+ecx*2],bx                 ; outstack(stackpointer)=lastpixel

         inc stackpointer

dowhile1:
         mov ebx,curcode
         cmp ebx,firstcode
         jl doneloop1

         mov ebp,curcode
         mov edi,suffix
	;mov bx,[ebp*2+edi]
	 mov bx,word ptr [ebp*2+edi]
         mov ebp,stackpointer
         mov edi,outstack
         mov [edi+ebp*2],bx

         inc stackpointer

         mov ebp,curcode
         mov edi,prefix
         xor ebx,ebx
	;mov bx,[ebp*2+edi]
	 mov bx,word ptr [ebp*2+edi]
         mov curcode,ebx

         jmp dowhile1

doneloop1:
         mov ebx,curcode
         mov lastpixel,ebx

         mov ebx,lastpixel
         mov edi,decodemem
         mov [edi],bl
         inc decodemem

         mov ecx,stackpointer
         dec ecx
         cmp ecx,-1
         je outfornext

fornextloop:
         mov esi,outstack
         mov bx,[esi+ecx*2]
         mov edi,decodemem
         mov [edi],bl
         inc decodemem

         dec ecx
         cmp ecx,-1
         jne fornextloop

outfornext:
         cmp nextcode,4096
         jae endif2

         mov ebx,lastcode
         mov ecx,nextcode
         mov edi,prefix
         mov [edi+ecx*2],bx
         mov ebx,lastpixel
         mov edi,suffix
         mov [edi+ecx*2],bx

         inc nextcode

         cmp codesize,12
         jae endif2

         mov ecx,nextcode
         cmp ecx,maxcode
         jbe endif2

         inc codesize
         shl maxcode,1
         inc maxcode
endif2:

         mov ebx,codex
         mov lastcode,ebx

level0:
         mov eax,codex
         cmp eax,eoscode
         jne decode0

end_of_decode:
         clc
         ret

getcode:
         cmp bitsin,0
         jne nogetbuf

         call getbufferedbyte
         jc error_in_decode

         mov lastchar,eax
         mov bitsin,8
nogetbuf:
         mov edx,bitsin
         mov ecx,shiftout[edx*4-4]
         mov eax,lastchar
         cdq
         div ecx
         mov workcode,eax
dowhile3:
         mov eax,codesize
         cmp eax,bitsin
         jle exitdo2

         call getbufferedbyte
         jc error_in_decode

         mov lastchar,eax

         mov ecx,bitsin
         mov ebx,powersof2[ecx*4]
         mul ebx
         or workcode,eax

         add bitsin,8
         jmp dowhile3

exitdo2:
         mov eax,codesize
         sub bitsin,eax

         mov eax,maxcode
         and eax,workcode
         mov codex,eax

         clc
         ret

getbufferedbyte:
         mov eax,blockpointer
         cmp eax,blocksize
         jle endif3

         call _loadgif_getbyte
         jc error_in_decode

         mov blocksize,eax

         mov ecx,eax
         mov edx,offset spaces
getmorepal:
         call _loadgif_getbyte
         mov [edx],al
         inc edx
         loop getmorepal

         mov blockpointer,1
endif3:
         xor eax,eax
         mov ecx,blockpointer
         mov al,spaces[ecx-1]
         inc blockpointer
         clc
         ret

;같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같
;
; Getdword - get dword from open file (self buffered)
; Getword  - get  word from open file (self buffered)
; Getbyte  - get  byte from open file (self buffered)
;
; In:
;    _loadgif_input - stream input routine (In:ECX=len,EDX->buf, Out:EAX=len,CF=1 error)
; Out:
;   CF=1 - Error reading file
;     EAX - ?
;   CF=0 - Read went fine
;     EAX - dword from file
;
;같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같

_loadgif_getdword:
         push ecx
         xor ecx,ecx
         call _loadgif_getbyte
         jc retpopx
         mov cl,al
         call _loadgif_getbyte
         jc retpopx
         mov ch,al
         call _loadgif_getbyte
         jc retpopx
         shl eax,16
         or ecx,eax
         call _loadgif_getbyte
         jc retpopx
         shl eax,24
         or eax,ecx
         pop ecx
         ret

_loadgif_getword:
         push ecx
         xor ecx,ecx
         call _loadgif_getbyte
         jc retpopx
         mov cl,al
         call _loadgif_getbyte
         jc retpopx
         mov ch,al
         mov ax,cx
retpopx:
         pop ecx
         ret

_loadgif_getbyte:
         dec bufleft
         cmp bufleft,0
         jg gb_ok
	;push ecx edx
	 push	ecx
	 push	edx
         mov edx,offset bytebuffer
         mov ecx,buflen
         mov bufptr,0
         call [_loadgif_input]
         mov bufleft,ecx
	;pop edx ecx
	 pop	edx
	 pop	ecx
gb_ok:
         mov eax,bufptr
         movzx eax,byte ptr bytebuffer[eax]
         inc bufptr
         clc
         ret

;+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

read_file_spez	PROC	    near    ; translation
				    ;	In:ECX=len,EDX->buf

				    ; BX     - Handle
				    ; ECX    - Length	    ; same
				    ; EDI    - Position.


		push	    bx
		push	    edi

		mov	    bx,filehandle_read
		mov	    edi,edx		    ; set buf position

;-----------------------

		push	    ecx

		call	    read_file

		pop	    ecx

;-----------------------

		pop	    edi
		pop	    bx


		RET
read_file_spez	ENDP

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

;--- xxx debug -------------------------------------------------------

filename_state	db  "v3state.bin",0

filehandle_state    dw	0

;---------------------------------------------------------------------

restore_state	PROC	    near

		mov	    edx,offset filename_state
		mov	    al,0	    ; read access
		mov	    ah,3dh
		int	    21h 	    ; open file
		jnc	    rs_open_ok
		RET
    rs_open_ok:
		mov	    filehandle_state,ax     ; insert handle

		mov	    bx,ax	;BX	- Handle
		mov	    ecx,512	;ECX	- Length
		mov	    edi,status	;EDI	- Position.

		call	    read_file


		RET
restore_state	ENDP

;---------------------------------------------------------------------

save_state	PROC	    near

		;create or truncate
		; -> handle

;DS:EDX - File name pointer as normal.

	mov	edx,offset filename_state

	mov	ah,3ch		;Create function.
	xor	cx,cx		;normal attributes.
	int	21h
	jnc	ss_write
	RET

;If carry clear,
;AX	- Handle for file.

    ss_write:
		mov	filehandle_state,ax

		;handle -> bx

		mov	    bx,ax

		mov	    ecx,512	; buffer_size
		mov	    esi,status
		call	    WriteFile
		jnc	    ss_close
		RET
    ss_close:

	mov	    bx,filehandle_state
	mov	ah,3eh		;close file function.
	int	21h


		RET
save_state	ENDP

;==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==
WriteFile	proc	near	    ; xxx debug, needed for save 2d state
;
;Write some data to a file.
;
;On Entry:-
;
;BX	- Handle
;ECX	- Length
;ESI	- Position.
;
	xor	edx,edx
@@0:	push	bx
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
WriteFile	endp



;==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-
;--------- not needed ------------------------------------------------
;--------------- set palette -----------------------------------------

	mov	esi,pal_loc
	mov	al,0
	mov	ecx,0
	mov	cx,gif_num_colors
	shl	cx,1
	add	cx,gif_num_colors



;같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같�
; _PutPal - put new palette to video card
; In:
;   ESI - destination location
;    AL - start pel
;   ECX - number of pels to write (max 768)
; Out: ?
;같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같�

;_put_palette:
         pushad
	 mov edx,3c8h		    ; equ 03c8h  vga dac write addr register
         out dx, al
	 mov edx,3c9h		    ; equ 03c9h  vga dac/pel data register r/w
         rep outsb
         popad
	;ret

;---------------------------------------------------------------------


;---------------------------------------------------------------------
;=========== vbe proc`s data =========================================
;---------------------------------------------------------------------

		.DATA

;---------------------------------------------------------------------

rm_buf_seg	dw	0	    ; (tmp. file buf.) (rm seg.)

rm_buf_addr	dd	0	    ; calced from rm_buf_seg

;--- real-mode call structure (50 bytes) -----------------------------


rm_call_struc	Label	dword
				    ; Name:	Offset:  d
				    ; -----	----------
rm_edi		dd	0	    ;	EDI	00h	00
rm_esi		dd	0	    ;	ESI	04h	04
rm_ebp		dd	0	    ;	EBP	08h	08
		dd	0	    ;	res.	0Ch	12
rm_ebx		dd	0	    ;	EBX	10h	16
rm_edx		dd	0	    ;	EDX	14h	20
rm_ecx		dd	0	    ;	ECX	18h	24
rm_eax		dd	0	    ;	EAX	1Ch	28
		dw	0	    ;	Flags	20h	32
rm_es		dw	0	    ;	ES	22h	34
rm_ds		dw	0	    ;	DS	24h	36
		dw	0	    ;	FS	26h	38
		dw	0	    ;	GS	28h	40
		dw	0	    ;	IP	2Ah	42
		dw	0	    ;	CS	2Ch	44
		dw	0	    ;	SP	2Eh	46
		dw	0	    ;	SS	30h	48

;----------------------------------------------------------------------

no_vbe_err	db	"keine VBE vorhanden",0

vbe_err_1	db	"VBE-1:fehlgeschlagen",0
vbe_err_2	db	"VBE-2:Funktion wird von Hardware nicht "
		db	"unterst걎zt",0
vbe_err_3	db	"VBE-3:Funktion im aktuellen Videomodus "
		db	"nicht erlaubt",0
vbe_err_unk	db	"VBE-x:unbekannter Fehler",0

;-----------------------

vbe_not_2plus	db	"VBE-Version unter 2.0",0

vbe_mode_n_avail db	"gewuenschter Video-Modus nicht "
		db	"verfuegbar",0

err_lfb_n_avail db	"Linear Frame Buffer nicht verfuegbar",0

;---------------------------------------------------------------------
;--------------- VBE Data --------------------------------------------
;---------------------------------------------------------------------


VBEInfoBlock	Label	byte

VBESignature	db  "VBE2"  ; VBESignature  ("VBE2" = VBE 2),
			    ;		    ( else = VBE 1.2)
			    ; "VBE2" forces extended Information

VBEVersion	dw	0   ; BCD
OEMStringPtr	dd	0   ;
Capabilities	db 4 dup (0)	;
VideoModePtr	dd	0   ;

TotalMemory	dw	0   ; (64 KB Blocks) , ab VBE 1.1

;--- VBE 2.0+ ------

OEMSoftwareRev	dw	0
OEMVendorNamePtr dd	0
OEMProductNamePtr dd	0
OEMProductRevPtr dd	0
		db	0   ; reserved
			    ;
			    ;	total len. = max. 200h Bytes
			    ;		   =	  512 Bytes dez.

Info_block_space  db 200h  dup (0)	; space for OEM-Data


;---------------------------------------------------------------------

;-- ModeInfoBlock ------

     ; Mandatory information for all VBE revisions

ModeInfoBlock	Label	word

ModeAttributes	dw	0   ; mode attributes
WinAAttributes	db	0   ; window A attributes
WinBAttributes	db	0   ; window B attributes
WinGranularity	dw	0   ; window granularity
WinSize 	dw	0   ; window size
WinASegment	dw	0   ; window A start segment
WinBSegment	dw	0   ; window B start segment
WinFuncPtr	dd	0   ; pointer to window function
BytesPerScanLine  dw	0   ; bytes per scan line

     ; Mandatory information for VBE 1.2 and above
XResolution	dw	0 ; horizontal resolution in pixels or chars
YResolution	dw	0 ; vertical resolution in pixels or chars
XCharSize	db	0   ; character cell width in pixels
YCharSize	db	0   ; character cell height in pixels
NumberOfPlanes	db	0   ; number of memory planes
BitsPerPixel	db	0   ; bits per pixel
NumberOfBanks	db	0   ; number of banks
MemoryModel	db	0   ; memory model type
BankSize	db	0   ; bank size in KB
NumberOfImagePages  db	0   ; number of images
_Reserved	db	0   ; reserved for page function

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
		call	out_msg_edi
		call	crlf
		call	prg_abort

    isvbe2plus:

;---------------------------------------------------------------------

	       ;mov	video_mode,111h     ; 111h=640*480*64k
		call	chk_mode_avail
		jnc	modeisavail
		mov	edi,offset vbe_mode_n_avail
		call	out_msg_edi
		call	crlf
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
		call	out_msg_edi
		call	crlf
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
		mov	draw_page_base,eax  ; init, assume: page 1
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

vbe_get_info_block PROC     near

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
		cmp	ax,4fh		; ok ? (ah=0, al=4fh)
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

		clc		    ; failed (carry)
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

		clc		    ; failed (carry)
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
		call	out_msg_edi
		call	crlf
		RET
    omsvbereiter1:
		cmp	ah,1	    ; fehlgeschlagen ?
		jne	omsvbereiter2
		mov	edi,offset vbe_err_1
		call	out_msg_edi
		call	crlf
		RET
    omsvbereiter2:

;------- vbe 2.0+ --------------------------

		cmp	ah,2	    ; not supported
		jne	omsvbereiter3
		mov	edi,offset vbe_err_2
		call	out_msg_edi
		call	crlf
		RET
    omsvbereiter3:
		cmp	ah,3	    ; not allowed
		jne	omsvbereiter4
		mov	edi,offset vbe_err_3
		call	out_msg_edi
		call	crlf
		RET
    omsvbereiter4:
		mov	edi,offset vbe_err_unk	; unknown error
		call	out_msg_edi
		call	crlf


		RET
out_msg_vbe_err ENDP

;---------------------------------------------------------------------

out_msg_edi_exit PROC	near	; output msg and wait for a key
						    ; to exit

		call	out_msg_edi

		call	crlf
		mov	edi,offset msg_key_exit ; "key to exit"
		call	out_msg_edi

		mov	ah,0
		int	16h

		RET
out_msg_edi_exit ENDP

;---------------------------------------------------------------------

out_msg_edi_wait PROC	near	; output msg and wait for a key

		call	out_msg_edi

		mov	ah,0
		int	16h

		RET
out_msg_edi_wait ENDP

;---------------------------------------------------------------------

out_msg_edi	PROC	near	; edi points to asciiz


		push	eax
		push	edi

    omsgediagain:
		mov	al,byte ptr [edi]
		cmp	al,0
		je	omsgediend

		call	writt_al
		add	edi,1
		jmp	omsgediagain

    omsgediend:

		pop	edi
		pop	eax



		RET
out_msg_edi	ENDP

;---------------------------------------------------------------------

wr_2_hex	PROC	near		  ; wr value in al

		push	ax

		mov	ah,al		; copy value

		push	ax
		shr	al,4
		call	xlat_al 	; to ascii
		call	writt_al
		pop	ax

		mov	al,ah		; restore
		and	al,0fh
		call	xlat_al 	; to ascii
		call	writt_al

		mov	al,20h
	       ;call	writt_al

		mov	al,"h"
		call	writt_al

		pop	ax

		RET
wr_2_hex	ENDP

;---------------------------------------------------------------------

wr_8_hex	PROC	near		  ; wr value in eax

		push	eax
		push	cx

		mov	cx,8
    wr8hagain:
		rol	eax,4
		push	eax
		and	al,0fh
		call	xlat_al 	; to ascii
		call	writt_al
		pop	eax
		loopw	wr8hagain

		mov	al,20h
	       ;call	writt_al

		mov	al,"h"
		call	writt_al

		pop	cx
		pop	eax

		RET
wr_8_hex	ENDP

;----------------------------------------------------------------------

xlat_al 	PROC	near	    ; xlat al to hex char ascii

		push	esi

		mov	esi,offset hexchars ; table of chars
		and	eax,0ffh
		add	esi,eax
		mov	al,byte ptr [esi]

		pop	esi

		RET
xlat_al 	ENDP

;----------------------------------------------------------------------

space		PROC	near

		push	ax

		mov	al,20h
		call	writt_al

		pop	ax

		RET
space		ENDP

;----------------------------------------------------------------------

four_space	PROC	near

		push	ax

		mov	al,20h
		call	writt_al
		call	writt_al
		call	writt_al
		call	writt_al

		pop	ax

		RET
four_space	ENDP

;----------------------------------------------------------------------

cr		PROC	near

		push	eax

		mov	al,0dh		; cr
		call	writt_al

		pop	eax

		RET
cr		ENDP

;----------------------------------------------------------------------

crlf		PROC	near

		push	eax

		mov	al,0dh		; cr
		call	writt_al

		mov	al,0ah		; lf
		call	writt_al

		pop	eax

		RET
crlf		ENDP

;----------------------------------------------------------------------

writt_al	PROC	near	    ; writt ascii in al to cursor
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
writt_al	ENDP

;---------------------------------------------------------------------

		END	START
