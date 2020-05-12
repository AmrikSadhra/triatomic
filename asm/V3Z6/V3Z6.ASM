		TITLE	v3z6.asm	19:46:43  26-Aug-2003

					; 3dfx voodoo 3 (avenger)
					; 3d register programming
					; with CauseWay Extender
					;
					;   flat-shading, z-buffer
					;   double frame buffer
					;
					;  5:6:5 mode
					;     (not 8:8:8 mode)
		.486			;   (using bswap)
		.MODEL	FLAT		;
					;
		.STACK	400h		; need at least 400h for
					;  some pci functions

		ASSUME	GS : NOTHING	; def.: assumed to error,
					; now GS is zero based
					; segment (for screen)

;---------------------------------------------------------------------
				    ; .inc source not visible in cwd
		INCLUDE _vbe.inc
		INCLUDE _v3_regs.inc	; voodoo 3 register defs.
		INCLUDE _3d6.inc	; ! 6, sixth version
					; rot normals
		INCLUDE _3dsr.inc	; .3ds reader
		INCLUDE _general.inc

;---------------------------------------------------------------------
;
;   written by daniel hagmann
;	rot.asm (part of _3d6.inc) originally written by Abe of space
;	ftoa written by Bob Kline
;	_sqrt written by TRAN
;	dd_to_dec_string from alib, the .asm library
;
;
;	masm 6.0	ml /c /Zd /Zi  %1.asm
;	(cw linker)	wl32 /i /sy %1
;---------------------------------------------------------------------
;   new:
;	26-Aug-2003	added err. msg if no voodoo 3, pci or vbe err.
;
;	15-Aug-2003	added text_y_offset, now a_writt_al can write
;			to all pages. need: set_all_io_addr, in setup
;			clip0Max is set to 0ffffh
;
;
;	25-May-2002	enabled subpixel correction in fbzColorPath
;		sometimes there were errors when triangles are
;		putted together (line ore some pixels between)
;	26-May-2002	divided into several include files
;
;---------------------------------------------------------------------
;   to do:
;
;---------------------------------------------------------------------
;   bugs:
;	    -	no 486 and no FPU check
;
;   15-Aug-2003     bug fix: in _3d6.inc changed DIST for projection
;			    from 256 to 512 to look more realistic
;
;	    - sometimes no readable text under Windows
;		(bug with monochrome src. screen-screen blit)
;		    19-Oct-2001 fixed -> addr_a_wr_char
;---------------------------------------------------------------------
;   limitations:
;	    - max. 65535 points (nr_of_points dw)
;			(:3 = 21k, -> alloc)
;
;---------------------------------------------------------------------

		.DATA

;---------------------------------------------------------------------

	       ;EXTRN	_d_fs2_filespec:byte
	       ;EXTRN	_d_fs2_selected_name:byte

;---------------------------------------------------------------------

;filename_read	 db	    "duck.3ds",0	; 0/0 chunks
filename_read	db	   "teapot.3ds",0      ; single object
;filename_read	 db	    "discov.3ds",0	; multi objects
;filename_read	 db	    "1tri.3ds",0	; a single triangle
;filename_read	 db	    "berg0.3ds",0	; simple
;filename_read	 db	    "berg8.3ds",0
;filename_read	 db	    "terr1.3ds",0	 ; terrain
;filename_read	 db	    "font.3ds",0	; long
;filename_read	 db	    "tank2.3ds",0
;filename_read	 db	    "darts.3ds",0	 ; deep extruded
;filename_read	 db	    "plant.3ds",0	;
;filename_read	 db	    "face.3ds",0       ;
;filename_read	 db	     "h_sphere.3ds",0	 ; half sphere
;filename_read	 db	     "mesh.3ds",0	 ; 1 plane mesh ->err
;filename_read	 db	    "hello3d.3ds",0
;filename_read	 db	    "shade.3ds",0

;---------------------------------------------------------------------

vertex_normals_ptr	   dd	0   ; unused but needed for _3d6.inc
rotated_vertex_normals_ptr dd	0   ; unused but needed for _3d6.inc

;---------------------------------------------------------------------

xs		dw	0	    ; x start
ys		dw	0	    ; y start
xe		dw	0	    ; x end
ye		dw	0	    ; y end

r		db	0	    ; red
g		db	0	    ; green
b		db	0	    ; blue

;---------------------------------------------------------------------

font_ptr_rom	dd	0	    ; pointer to rom-font (in rom)
font_ptr_video	dd	0	    ; pointer to copyed rom-font
				    ; in video memory  (for CPU)
font_ptr	dd	0	    ; pointer to copyed rom-font
				    ; in video memory  (for GPU)
				    ; (relative to display_base)


;---------------------------------------------------------------------

;d   equ dword ptr

;---------------------------------------------------------------------

;curpa		 db	 0	     ; current page

;--- defined in _vbe.inc -----------

;video_mode	 dw	 0	     ; desired video-mode
;display_base	 dd	 0	     ; start of LFB
;draw_page_base  dd	 0	     ; base addr. of other page
				    ; (for double fr.buffer)
				    ; init. from setup vbe
;page_len	 dd	 0	     ; len. of 1 display page
				    ; calc from setup vbe

;---------------------------------------------------------------------
;-- for double frame buffering:

;display_base	dd  0	; defined in _vbe.inc  (start of page 0)

draw_page_base	dd	0	; for double frame buffering
				; can be: (0)= display_base    or
				;	  (1)= display_base + page_len

graph_page	db	0	; current page in graphic mode
				; (visible page)  can be 0 or 1

bb_flag 	db	0	; 0 = write to visible page
				; 1 = write to backbuffer
				; (checked in calc_esi)

;---------------------------------------------------------------------

;curx		 dw	 0
;cury		 dw	 0

;---------------------------------------------------------------------

msg_title	db	"v3z6       use  "
		db	"x,y,z,up,down,left,right,num+,num-,ESC",0

msg_setup_ok	db	"setup ok   -> key",0

msg_page_1	db	" - page 1 -",0
msg_page_2	db	" - page 2 - (z-Buffer)",0
msg_page_3	db	" - page 3 -",0
msg_page_4	db	" - page 4 -",0


;---------------------------------------------------------------------

err_msg_pci	db	"PCI init error",0
err_msg_device	db	"Voodoo3 not found - device 5, vendor 121ah "
		db	"- `avenger`, 3dfx  not found",0
err_msg_vbe	db	"VBE init error",0

;---------------------------------------------------------------------
;---------------------------------------------------------------------

;vector_t view={0, 0, -1};	 //view vector
;vector_t lv={.5, .5, -1};	 //original light vector

light_vector	dw	0,0,1000	  ; x,y,z  (ratio)


n_light_vector	dw	0,0,0	; normalized from light_vector

ambient 	db	30	; (30) offset (never complete dark)

draw_color_base db     80,100,80     ; before calc_intensity   (grey)

draw_color	db	45,0,100    ; after calc_intensity

;---------------------------------------------------------------------

		.CODE

;---------------------------------------------------------------------

SwapNum 	MACRO	Num1,Num2   ; used in draw triangle
				    ; for cwd this is placed here
		MOV	AX,Num1
		MOV	BX,Num2
		MOV	Num2,AX
		MOV	Num1,BX

		ENDM

;---------------------------------------------------------------------

START:

;---------------------------------------------------------------------

		mov	ax,_DATA
		mov	ds,ax
		mov	es,ax
		mov	fs,ax
		mov	gs,ax

;---------------------------------------------------------------------

		finit			; copro for conv_ax_real

;---------------------------------------------------------------------

		call	main_3ds_text
			    ; .3ds load,setup,display(text)+get vars

;------ 3d init -------------

		    ;.3ds is loaded  (pointlist)

		;scale+create pointlist_w (words,world coords.)
		; from pointlist (real4)

		call	normalize_lv	; normalize light vector

		call	sc_cr_pointlist_w   ; -> pointlist_w_ptr



		call	init_3d_arrays	; alloc for rotated_xyz
					;  and screen_xyzc
					; and set rotated_xyz_ptr
					;     and screen_xyzc_ptr
					; (nr_of_points)
		call	init_normal_arrays  ; additional for flat sh.
					; alloc for normals (array)
					;   and rotated_normals
					; and set normals_ptr
					;   and rotated_normals_ptr
		call	calc_normals	; init, calc normals array

;----------------------------

		call	insert_colors	; to screen_xyzc array


		mov	eax,pointlist_w_ptr	; xxx debug
		mov	eax,rotated_xyz_ptr
		mov	eax,screen_xyzc_ptr

;---------------------------------------------------------------------

		call	setup_3d    ; (set video_mode=111h) 640_16

		call	misc_screen ; deco. etc.

;---------------------------------------------------------------------

		call	main_3d     ; the main rotation proc

;---------------------------------------------------------------------

    prg_exit:
		mov	ah,0	    ; set video mode
		mov	al,3	    ; mode 3 (80*25)
		int	10h	    ; Return to TEXT mode

    prg_abort:
		mov	ah,4ch
		mov	al,0		; DOS exit
		int	21h		;   no error

;---------------------------------------------------------------------
;-------------- E N D ------------------------------------------------
;---------------------------------------------------------------------

;--------------- error exit ------------------------------------------

    prg_exit_pci:
		mov	esi,offset err_msg_pci
		jmp	prg_exit_err_msg
    prg_exit_device:
		mov	esi,offset err_msg_device
		jmp	prg_exit_err_msg
    prg_exit_vbe:
		mov	esi,offset err_msg_vbe
		jmp	prg_exit_err_msg


    prg_exit_err_msg:
		mov	ah,0	    ; set video mode
		mov	al,3	    ; mode 3 (80*25)
		int	10h	    ; Return to TEXT mode

		call	out_msg_esi
		call	crlf
		jmp	prg_abort

;=====================================================================
;---------------------------------------------------------------------

main_3d 	PROC	near

		mov	rotx,128    ; init (else(0) we see backface)
	       ;mov	roty,16
    rotagain:
	       ;call	draw_z_plane		; to test z-clipping

		call	displ_3d_flat	; flat shaded

		call	a_wr_debug	; acc. wr. debug registers

		call	flip_page

		mov	ah,0
		int	16h

		push	ax

		call	fastfill	; clear clip window

		pop	ax

		cmp	ah,1	    ; ESC ?
		je	@@end

		call	keys
		jmp	rotagain

;-----------------------

    @@end:

		RET
main_3d 	ENDP

;---------------------------------------------------------------------

;	    dstBaseAddr     for 2d  write
;	    colBufferAddr   for 3d  write
;
;	    vidDesktopStartAddr (io)	for visible on screen

;-------------------------------

page_1_offset	dd	640*480*2

;-------------------------------

flip_page	PROC	near	;   xxxx first version

		mov	edi,colBufferAddr	    ; 3d
		mov	eax,[edi]
		cmp	eax,0
		je	@@s_wr_1

		mov	edi,dstBaseAddr
		mov	eax,0
		mov	[edi],eax		; set 2d write page 0

		mov	edi,colBufferAddr	; 3d
		mov	eax,0
		mov	[edi],eax		; set 3d write page 0

		mov	edi,vidDesktopStartAddr
		movzx	eax,YResolution
		movzx	ebx,BytesPerScanLine
		mul	ebx
		mov	[edi],eax		; set visible page 1

		jmp	@@end
    @@s_wr_1:
		mov	edi,dstBaseAddr
		mov	eax,640*480*2
		mov	[edi],eax		; set 2d write page 1

		mov	edi,colBufferAddr	    ; 3d
		mov	eax,page_1_offset
		mov	[edi],eax		; set 3d write page 1

		mov	edi,vidDesktopStartAddr
		mov	eax,0
		mov	[edi],eax		; set visible page 0

    @@end:


		RET
flip_page	ENDP

;---------------------------------------------------------------------

draw_z_plane	PROC	near	; to test z-clipping


		mov	x1,320
		mov	y1,100
		mov	x2,400
		mov	y2,300
		mov	x3,20
		mov	y3,300

		mov	r_value,60
		mov	g_value,60
		mov	b_value,60
		mov	z_value,32000	    ; offset (32000)
				    ; put in mid z (far=65535, near=0)

		call	drw_tri_z

		RET
draw_z_plane	ENDP

;---------------------------------------------------------------------

insert_colors	PROC	near	; xxx  to screen_xyzc array


		mov	edi,screen_xyzc_ptr
		mov	cx,nr_of_points

		mov	ax,80h
		mov	dx,4060h
    @@again:
		mov	byte ptr [edi+6],ah	; alpha 1
		mov	byte ptr [edi+7],al	; red	1
		mov	byte ptr [edi+8],dh	; green 1
		mov	byte ptr [edi+9],dl	; blue	1

	       ;add	al,60
	       ;add	dh,40
	       ;add	dl,20

		add	edi,10		    ; to next point

		loopw	@@again


		RET
insert_colors	ENDP

;---------------------------------------------------------------------

reset_tri_delta_col PROC  near

		mov	ax,0		; format 12.12
		cwde			; extend sign
		mov	edi,dRdX
		mov	[edi],eax

		mov	ax,0		; format 12.12
		cwde			; extend sign
		mov	edi,dRdY
		mov	[edi],eax

		mov	ax,0		; format 12.12
		cwde			; extend sign
		mov	edi,dGdX
		mov	[edi],eax

		mov	ax,0		; format 12.12
		cwde			; extend sign
		mov	edi,dGdY
		mov	[edi],eax

		mov	ax,0		; format 12.12
		cwde			; extend sign
		mov	edi,dBdX
		mov	[edi],eax

		mov	ax,0		; format 12.12
		cwde			; extend sign
		mov	edi,dBdY
		mov	[edi],eax


		RET
reset_tri_delta_col ENDP


;---------------------------------------------------------------------

keys		PROC	near		;

		cmp	ah,2dh		; x ?
		jne	@@1
		add	rotx,1		; /256
		RET
	@@1:
		cmp	ah,2ch		; y ?
		jne	@@2
		add	roty,1		; /256
		RET
	@@2:
		cmp	ah,15h		; z ?
		jne	@@3
		add	rotz,1		; /256
		RET
	@@3:

		cmp	ah,4bh		; left ?
		jne	@@4
		sub	addx,1
		RET
	@@4:
		cmp	ah,4dh		; right ?
		jne	@@5
		add	addx,1
		RET
	@@5:

		cmp	ah,48h		; up ?
		jne	@@6
		sub	addy,1
		RET
	@@6:
		cmp	ah,50h		; down ?
		jne	@@7
		add	addy,1
		RET
	@@7:

		cmp	ah,4eh		; + ?
		jne	@@8
		sub	addz,1
		RET
	@@8:
		cmp	ah,4ah		; - ?
		jne	@@9
		add	addz,1
		RET
	@@9:

		cmp	ah,49h		; pgup ?
		jne	@@10
		call	sub_displ_start_10h	; (vid or 10h)
		RET
	@@10:
		cmp	ah,51h		; pgdn ?
		jne	@@11
		call	add_displ_start_10h	; (vid or 10h)
		RET
	@@11:


		RET
keys		ENDP

;----------------------------------------------------------------------

displ_y_offset	dw	0	; tmp.

;-----------------------

sub_displ_start_vid PROC near	; for debug  using video register
				;	     (vidDesktopStartAddr)
				; seems int 10h is using the same reg.

		cmp	displ_y_offset,0
		jne	@@not0
		RET
    @@not0:
		mov	ax,YResolution	; for step
		shr	ax,1		; :2
		sub	displ_y_offset,ax

	       ;mov	edi,_ioBase
	       ;add	edi,0e4h	; +e4h -> vidDesktopStartAddr
		mov	edi,vidDesktopStartAddr

		movzx	eax,displ_y_offset
		movzx	ebx,BytesPerScanLine
		mul	ebx
		mov	[edi],eax

		RET
sub_displ_start_vid ENDP

;----------------------------------------------------------------------

add_displ_start_vid PROC near	; for debug  using video register
				;	     (vidDesktopStartAddr)
				; seems int 10h is using the same reg.

		mov	ax,YResolution	; for step
		shr	ax,1		; :2
		add	displ_y_offset,ax

	       ;mov	edi,_ioBase
	       ;add	edi,0e4h	; +e4h -> vidDesktopStartAddr
		mov	edi,vidDesktopStartAddr

		movzx	eax,displ_y_offset
		movzx	ebx,BytesPerScanLine
		mul	ebx
		mov	[edi],eax

		RET
add_displ_start_vid ENDP

;----------------------------------------------------------------------

sub_displ_start_10h PROC near	; for debug  using int 10h

		cmp	displ_y_offset,0
		jne	@@not0
		RET
    @@not0:
		mov	ax,YResolution	; for step
		shr	ax,1		; :2
		sub	displ_y_offset,ax

		mov	ax,4f07h	; set display start
		mov	bl,0		; immediate
		mov	bh,0		; (reserved, must be 0)
		mov	cx,0		; x offset
		mov	dx,displ_y_offset   ; y offset
		int	10h

		RET
sub_displ_start_10h ENDP

;----------------------------------------------------------------------

add_displ_start_10h PROC near	; for debug  using int 10h

		mov	ax,YResolution	; for step
		shr	ax,1		; :2
		add	displ_y_offset,ax

		mov	ax,4f07h	; set display start
		mov	bl,0		; immediate
		mov	bh,0		; (reserved, must be 0)
		mov	cx,0		; x offset
		mov	dx,displ_y_offset   ; y offset
		int	10h

		RET
add_displ_start_10h ENDP


;----------------------------------------------------------------------

misc_screen	PROC	near

;-----------------------------------------------
;xxx debug xxxx

		mov	edi,leftOverlayBuf
		mov	eax,[edi]
		mov	eax,320*3*1024
		mov	[edi],eax

		mov	edi,rightOverlayBuf
		mov	ebx,[edi]
		mov	eax,320*3*1024
		mov	[edi],eax

;-------------------

		mov	eax,display_base
		mov	edi,eax
		mov	dword ptr [edi+4060h],0ffffffffh

		mov	ah,0
		int	16h

	;xxx debug
		mov	edi,swapPending
		mov	[edi],eax		; value dont`t care

		mov	eax,1
		mov	edi,swapbufferCMD
		mov	[edi],eax


		mov	edi,vidDesktopStartAddr
		mov	eax,[edi]		; xx debug

		mov	eax,40*1280	    ; (1280 bytes per line)
		mov	[edi],eax


;-----------------------------------------------

		call	cls		; clear screen

;------- wr page number --------------------------------

		mov	text_x,2
		mov	text_y,0

		mov	bx,YResolution
		mov	text_y_offset,bx
	       ;mov	edi,offset msg_page_1
		mov	edi,offset msg_title
		call	a_out_msg_edi

		mov	text_x,0	    ; reset x
		add	text_y_offset,bx
		mov	edi,offset msg_page_2
		call	a_out_msg_edi

		mov	text_x,0	    ; reset x
		add	text_y_offset,bx
		mov	edi,offset msg_page_3
		call	a_out_msg_edi

		mov	text_x,0	    ; reset x
		add	text_y_offset,bx
		mov	edi,offset msg_page_4
		call	a_out_msg_edi


		mov	text_y_offset,0     ; return to page 0


;---------------------------------------------------------------------

		mov	text_x,2
		mov	text_y,0

		mov	edi,offset msg_title
		call	a_out_msg_edi		    ; wr title

		mov	text_x,5
		mov	text_y,22

		mov	edi,offset msg_setup_ok
		call	a_out_msg_edi

;---------------------------------------------------------------------

		call	a_wr_debug	; acc. wr. debug registers

		call	draw_3d_clip	; draw 3d clip window if clip
					;   is enabled + not=scr.res.
		mov	edi,dstBaseAddr 	    ; 2d
		mov	dword ptr [edi],480*640*2   ; to page 1

		call	draw_3d_clip	; on th other page too

		mov	edi,dstBaseAddr 	    ; 2d
		mov	dword ptr [edi],0	    ; to page 0


		call	fastfill	; clear clip area + depth buf.

;---------------------------------------------------------------------

;------- write pixel -------

		mov	eax,display_base
		mov	edi,eax
		mov	dword ptr [edi+4060h],0ffffffffh

;---------------------------------------------------------------------

;---------------------------------------------------------------------

		mov	ah,0
		int	16h

		call	my_triangle
		call	a_wr_debug	; acc. wr. debug registers

		mov	ah,0
		int	16h

		call	fastfill

		mov	eax,0
		mov	edi,triangleCmd
		mov	[edi],eax	    ; same triangle again

		call	a_wr_debug	; acc. wr. debug registers

		mov	ah,0
		int	16h

;---------------------------------------------------------------------

		call	fastfill

;-----------------------------------

		mov	eax,280
		shl	eax,4		; format 12.4
		mov	edi,vertexAx
		mov	[edi],eax


		mov	eax,0
		mov	edi,triangleCmd
		mov	[edi],eax

;-----------------------------------

		call	a_wr_debug	; acc. wr. debug registers

		mov	ah,0
		int	16h

		call	fastfill

;---------------------------------------------------------------------

		mov	eax,display_base
		add	eax,page_len
		mov	draw_page_base,eax	; init !!
		mov	graph_page,0		; (visible)

		mov	text_x,0
		mov	text_y,29
		mov	bb_flag,0	; write to fore_buffer
		mov	al,"0"		; page_nr
		call	a_writt_al
		mov	text_x,0
		mov	bb_flag,1	; write to back_buffer
		mov	al,"0"		; page_nr
		call	a_writt_al

		RET
misc_screen	ENDP

;---------------------------------------------------------------------
;============== flat shaded ==========================================
;---------------------------------------------------------------------

displ_3d_flat	PROC	near	; flat shaded
				; pointlist_w_ptr
				; nr_of_faces, facelist_ptr (words)

		call	_RotatePoints
		call	_RotateNormals

		mov	eax,rotated_normals_ptr
		mov	cur_rot_n_ptr,eax   ; init

		mov	edi,facelist_ptr
		mov	esi,screen_xyzc_ptr
		mov	cx,nr_of_faces
    @@again:
		call	displ_1_tri_flat
		add	edi,8		    ; to next face
		add	cur_rot_n_ptr,6     ; to next normal

		loopw	@@again


		RET
displ_3d_flat	ENDP

;---------------------------------------------------------------------

z_offset	dw     32000	    ; make z-buffer working

;-------------------------------

displ_1_tri_flat PROC	near	    ; sub from displ_3d_flat
				; modified V3 version

		push	edi
		push	esi
		push	ecx	    ; changed in proc draw

;-----------------------

		movzx	ebx,word ptr [edi]   ; get pointnr 0 from face
		mov	eax,ebx     ; copy
		shl	ebx,3	    ; *8
		add	ebx,eax     ; *9
		add	ebx,eax     ; *10

		mov	ax,word ptr [ebx+esi]	; get x value
		mov	x1,ax
		mov	ax,word ptr [ebx+esi+2]   ; get y value
		mov	y1,ax
		mov	ax,word ptr [ebx+esi+4]   ; get z value
		add	ax,z_offset
		mov	z1,ax
		mov	eax,dword ptr [ebx+esi+6] ; get argb value
		bswap	eax
		mov	argb1,eax


		movzx	ebx,word ptr [edi+2] ; get pointnr 1 from face
		mov	eax,ebx     ; copy
		shl	ebx,3	    ; *8
		add	ebx,eax     ; *9
		add	ebx,eax     ; *10

		mov	ax,word ptr [ebx+esi]	; get x value
		mov	x2,ax
		mov	ax,word ptr [ebx+esi+2]   ; get y value
		mov	y2,ax
		mov	ax,word ptr [ebx+esi+4]   ; get z value
		add	ax,z_offset
		mov	z2,ax
		mov	eax,dword ptr [ebx+esi+6] ; get argb value
		bswap	eax
		mov	argb2,eax

;-----------------------

		movzx	ebx,word ptr [edi+4] ; get pointnr 2 from face
		mov	eax,ebx     ; copy
		shl	ebx,3	    ; *8
		add	ebx,eax     ; *9
		add	ebx,eax     ; *10

		mov	ax,word ptr [ebx+esi]	; get x value
		mov	x3,ax
		mov	ax,word ptr [ebx+esi+2]   ; get y value
		mov	y3,ax
		mov	ax,word ptr [ebx+esi+4]   ; get z value
		add	ax,z_offset
		mov	z3,ax
		mov	eax,dword ptr [ebx+esi+6] ; get argb value
		bswap	eax
		mov	argb3,eax

;-----------------------

		call	calc_intensity	; using normal + light vector
	       ;call	draw_triangle	; using triangle mode
				    ;x1,y1,x2,y2,x3,y3,color[r,g,b]

		call	set_argb_flat	; change all argb to draw_color
		call	draw_triangle_2 ; using strip mode
					; +argb1,2,3

;-----------------------


		pop	ecx
		pop	esi
		pop	edi

		RET
displ_1_tri_flat ENDP

;---------------------------------------------------------------------

set_argb_flat	PROC	near	; overwrite argb with draw_color
				; have intensity instead random colr.

		mov	ax,0
		shl	eax,16
		mov	ah,draw_color
		mov	al,draw_color+1
		shl	eax,8
		mov	al,draw_color+2

		mov	argb1,eax
		mov	argb2,eax
		mov	argb3,eax


		RET
set_argb_flat	ENDP

;---------------------------------------------------------------------

argb1		dd	0
argb2		dd	0
argb3		dd	0

;---------------------------------------

draw_triangle_2 PROC	near	; x1,y1,x2,y2,x3,y3,argb1,argb2,arbg3


		mov	ax,0000000000000000b	; strip mode
		shl	eax,16
	       ;mov	ax,0000000000100010b	; setup alpha,s0,t0
	       ;mov	ax,0000000000000011b	; setup rgb,alpha
		mov	ax,0000000000000111b	; setup rgb,alpha,z
		mov	edi,sSetupMode
		mov	[edi],eax

;---------------------------

;begin triangle setup
;vertex #0

		mov	ax,x1
		call	conv_ax_real
		mov	edi,sVx
		mov	[edi],eax

		mov	ax,y1
		call	conv_ax_real
		mov	edi,sVy
		mov	[edi],eax

		mov	ax,z1
		call	conv_ax_real
		mov	edi,sVz
		mov	[edi],eax

		mov	eax,argb1
		mov	edi,sARGB
		mov	[edi],eax

		mov	eax,0
		mov	edi,sBegintriCMD
		mov	[edi],eax	    ; begin triangle

;-------------------

;vertex #1

		mov	ax,x2
		call	conv_ax_real
		mov	edi,sVx
		mov	[edi],eax

		mov	ax,y2
		call	conv_ax_real
		mov	edi,sVy
		mov	[edi],eax

		mov	ax,z2
		call	conv_ax_real
		mov	edi,sVz
		mov	[edi],eax

		mov	eax,argb2
		mov	edi,sARGB
		mov	[edi],eax


		mov	eax,0
		mov	edi,sDrawtriCMD
		mov	[edi],eax

;-------------------

;vertex #2

		mov	ax,x3
		call	conv_ax_real
		mov	edi,sVx
		mov	[edi],eax

		mov	ax,y3
		call	conv_ax_real
		mov	edi,sVy
		mov	[edi],eax

		mov	ax,z3
		call	conv_ax_real
		mov	edi,sVz
		mov	[edi],eax

		mov	eax,argb3
		mov	edi,sARGB
		mov	[edi],eax


		mov	eax,0
		mov	edi,sDrawtriCMD
		mov	[edi],eax


		RET
draw_triangle_2 ENDP

;---------------------------------------------------------------------

x1		dw	0	; first point of triangle
y1		dw	0	;
z1		dw	0	;
x2		dw	0	; second  "   "      "
y2		dw	0	;
z2		dw	0	;
x3		dw	0	; third   "   "      "
y3		dw	0	;
z3		dw	0	;


;-------------------------------

draw_triangle	PROC	near	    ;x1,y1,x2,y2,x3,y3,color[r,g,b]

		call	dt_chk_y    ; should not be below 0
		jnc	@@ok
		RET
	@@ok:


		mov	ax,x1
		cwde			; extend sign
		shl	eax,4		; format 12.4
		mov	edi,vertexAx
		mov	[edi],eax

		mov	ax,y1
		cwde			; extend sign
		shl	eax,4		; format 12.4
		mov	edi,vertexAy
		mov	[edi],eax

		mov	ax,x2
		cwde			; extend sign
		shl	eax,4		; format 12.4
		mov	edi,vertexBx
		mov	[edi],eax

		mov	ax,y2
		cwde			; extend sign
		shl	eax,4		; format 12.4
		mov	edi,vertexBy
		mov	[edi],eax

		mov	ax,x3
		cwde			; extend sign
		shl	eax,4		; format 12.4
		mov	edi,vertexCx
		mov	[edi],eax

		mov	ax,y3
		cwde			; extend sign
		shl	eax,4		; format 12.4
		mov	edi,vertexCy
		mov	[edi],eax

;------- execute -----------

	    ; !!! xxx use other calc. -> doc pg.95

	       ;call	chk_clockwise
	       ;jc	@@ccw

		call	chk_area
		js	@@ccw

		mov	eax,0
		mov	edi,triangleCmd
		mov	[edi],eax	; draw if clockwise
		RET

	@@ccw:
		mov	eax,1		;
		ror	eax,1		; set area bit
		mov	edi,triangleCmd
		mov	[edi],eax	; draw if counterclockwise


		RET
draw_triangle	ENDP

;---------------------------------------------------------------------

dxAB		dw	0	; dxAB = x1-x2
dyBC		dw	0	; dyBC = y2-y3
dxBC		dw	0	; dxBC = x2-x3
dyAB		dw	0	; dyAB = y1-y2


;-----------------------

chk_area	PROC	near	; (is cw or ccw)
				; ((dxAB*dyBC)-(dxBC*dyAB)) /2

		mov	ax,x1
		sub	ax,x2
		mov	dxAB,ax

		mov	ax,y2
		sub	ax,y3
		mov	dyBC,ax

		mov	ax,x2
		sub	ax,x3
		mov	dxBC,ax

		mov	ax,y1
		sub	ax,y2
		mov	dyAB,ax

				    ; ((dxAB*dyBC)-(dxBC*dyAB)) /2

		mov	ax,dxAB
		imul	dyBC
		shl	edx,16
		mov	dx,ax

		mov	ecx,edx

		mov	ax,dxBC
		imul	dyAB
		shl	edx,16
		mov	dx,ax

		sub	ecx,edx


		RET
chk_area	ENDP

;---------------------------------------------------------------------

chk_clockwise	PROC	near	; if ((x1*y2-x2*y1) > 0) then clockw.
				; xs*ye-xe*ys

		mov	ax,x1
		mul	y2
		shl	edx,16
		mov	dx,ax
		mov	ebx,edx

		mov	ax,x2
		mul	y1
		shl	edx,16
		mov	dx,ax

		sub	edx,ebx

		RET
chk_clockwise	ENDP

;---------------------------------------------------------------------

sort_by_y	PROC	near

		    ;-sort by y 	; thnx to lord mitra
					; pair w. lowest y first
		MOV	AX,Y1
		CMP    AX,Y2
		JLE    @@NoChg12	; jle -> signed
		SwapNum  X1, X2
		SwapNum  Y1, Y2
		SwapNum  Z1, Z2

    @@NoChg12:
		MOV    AX,Y1
		CMP    AX,Y3
		JLE    @@NoChg13
		SwapNum  X1, X3
		SwapNum  Y1, Y3
		SwapNum  Z1, Z3

    @@NoChg13:
		MOV    AX,Y2
		CMP    AX,Y3
		JLE    @@NoChg23
		SwapNum  X2, X3
		SwapNum  Y2, Y3
		SwapNum  Z2, Z3

    @@NoChg23:


		RET
sort_by_y	ENDP

;---------------------------------------------------------------------

dt_chk_y	PROC	near	; called from draw_triangle

		cmp	y1,0
		jns	@@1
		stc
		RET
	@@1:
		cmp	y2,0
		jns	@@2
		stc
		RET
	@@2:
		cmp	y3,0
		jns	@@3
		stc
		RET
	@@3:
		clc		; ok

		RET
dt_chk_y	ENDP

;---------------------------------------------------------------------

set_tri_color	PROC	near	; after calc intensity

		mov	ah,0
		mov	al,color	; color + 1 ?
		cwde			; extend sign
		shl	eax,12		; format 12.12
		mov	ax,0
		mov	edi,startR
		mov	[edi],eax

		mov	ah,0
		mov	al,color+1	; color + 1 ?
		cwde			; extend sign
		shl	eax,12		; format 12.12
		mov	ax,0
		mov	edi,startG
		mov	[edi],eax

		mov	ah,0
		mov	al,color+2
		cwde			; extend sign
		shl	eax,12		; format 12.12
		mov	edi,startB
		mov	[edi],eax

;------ d rgb val. -----


		mov	ax,0
		mov	bx,x1		; searching highest x
		cmp	bx,x2
		ja	@@h2
		mov	bx,x2
	@@h2:
		cmp	bx,x3
		ja	@@h3
		mov	bx,x3
	@@h3:
		mov	cx,x1		; searching lowest x
		cmp	cx,x2
		jb	@@l2
		mov	cx,x2
	@@l2:
		cmp	cx,x3
		jb	@@l3
		mov	cx,x3
	@@l3:

		sub	bx,cx		; highest-lowest
		jz	@@nodiv
		mov	dx,0
		mov	ax,20		; X delta value
		idiv	bx
		mov	cx,ax		; x.
		mov	ax,0
	       ;idiv	bx
		div	bx
		mov	bx,ax		; .x

		mov	ax,cx
	@@nodiv:


		cwde			; extend sign
		shl	eax,12		; format 12.12
		mov	ax,bx
	       ;mov	ax,1500 	;
		mov	edi,dGdX
		mov	[edi],eax

		mov	ax,0
		mov	bx,y3
		sub	bx,y1
		jz	@@nodiv2
		mov	dx,0
		mov	ax,10		; Y delta value (10)
		idiv	bx
		mov	cx,ax		; x.
		mov	ax,0
	       ;idiv	bx
		div	bx
		mov	bx,ax		; .x

		mov	ax,cx
	@@nodiv2:
		cwde			; extend sign
		shl	eax,12		; format 12.12
		mov	ax,bx		;
		mov	edi,dGdY
		mov	[edi],eax


;------ z value --------

	    ; set z values	z1,z2,z3   startZ,dZdX,dZdY --xxx!!!!
				    ; value at vertex A
		mov	ax,z1
		add	ax,32000    ; add z-plane offset (!! geom.)
				; put in mid z (far=65536, near=0)
		cwde			; extend sign
		shl	eax,12		; format 20.12
		mov	edi,startZ
		mov	[edi],eax

		;dZdX
		;dZdY

		mov	ax,z1
		add	ax,32000    ; offset
		mov	bx,z2
		add	bx,32000    ; offset
		mov	cx,z3
		add	cx,32000    ; offset
		cmp	ax,bx
		jle	@@12
		xchg	ax,bx
	@@12:
		cmp	ax,cx
		jle	@@13
		xchg	ax,cx
	@@13:
		cmp	bx,cx
		jle	@@23
		xchg	bx,cx
	@@23:
		sub	cx,ax
		xchg	ax,cx

	mov ax,0  ; xxx debug
		cwde			; extend sign
		shl	eax,12		; format 20.12
		mov	edi,dZdX
		mov	[edi],eax

		mov	ax,z3
		sub	ax,z1
	mov ax,0  ; xxx debug
		cwde			; extend sign
		shl	eax,12		; format 20.12
		mov	edi,dZdY
		mov	[edi],eax



		RET
set_tri_color	ENDP

;---------------------------------------------------------------------

cur_rot_n_ptr	dd	0   ; tmp.  current rotated normals ptr

intensity	dd	0   ; tmp.

;---------------------------

calc_intensity	PROC	near	    ; using normal + light vector
				    ; draw_color_base -> draw_color

				; A dot B = Ax*Bx + Ay*By + Az*Bz
				;	    (both normalized)
		push	esi

		mov	intensity,0	    ; init
		mov	esi,cur_rot_n_ptr   ; ptr to rotated normal

		mov	ax,n_light_vector
		cwde
		mov	ebx,eax
		mov	ax,word ptr [esi]	; normal x
		or	ax,ax
		jns	@@ns1
	       ;neg	ax
	@@ns1:	cwde				; sign needed
		cdq
		imul	ebx
		mov	intensity,eax

		mov	ax,n_light_vector+2
		cwde
		mov	ebx,eax
		mov	ax,word ptr [esi+2]	; normal y
		or	ax,ax
		jns	@@ns2
	       ;neg	ax
	@@ns2:	cwde				; sign needed
		cdq
		imul	ebx
		add	intensity,eax

		mov	ax,n_light_vector+4
		cwde
		mov	ebx,eax
		mov	ax,word ptr [esi+4]	; normal z
		or	ax,ax
		jns	@@ns3
	       ;neg	ax
	@@ns3:	cwde				; sign needed
		cdq
		imul	ebx
		add	intensity,eax

		cmp	intensity,0
		jns	@@nosign
		neg	intensity
    @@nosign:

;---------------------------

		mov	ebx,0
		mov	eax,intensity
		mov	bl,draw_color_base
		mul	ebx
	       ;shr	eax,16
		shr	eax,20
		add	al,ambient	    ; offset
		mov	draw_color,al
		mov	color,al

		mov	ebx,0
		mov	eax,intensity
		mov	bl,draw_color_base+1
		mul	ebx
	       ;shr	eax,16
		shr	eax,20
		add	al,ambient	    ; offset
		mov	draw_color+1,al
		mov	color+1,al

		mov	ebx,0
		mov	eax,intensity
		mov	bl,draw_color_base+2
		mul	ebx
	       ;shr	eax,16
		shr	eax,20
		add	al,ambient	    ; offset
		mov	draw_color+2,al
		mov	color+2,al


		pop	esi

		RET
calc_intensity	ENDP

;=====================================================================
;---------------------------------------------------------------------

r_value 	db	0
g_value 	db	0
b_value 	db	0

z_value 	dw	0	;

;-----------------------

drw_tri_z	PROC	near	; test proc  z-plane
				; x1,y1,x2,y2,x3,y3
				; z_value,r_value,g_value,b_value

		call	dt_chk_y    ; should not be below 0
		jnc	@@ok
		RET
	@@ok:
		call	sort_by_y   ; xxxxx

		mov	ax,x1
		cwde			; extend sign
		shl	eax,4		; format 12.4
		mov	edi,vertexAx
		mov	[edi],eax

		mov	ax,y1
		cwde			; extend sign
		shl	eax,4		; format 12.4
		mov	edi,vertexAy
		mov	[edi],eax

		mov	ax,x2
		cwde			; extend sign
		shl	eax,4		; format 12.4
		mov	edi,vertexBx
		mov	[edi],eax

		mov	ax,y2
		cwde			; extend sign
		shl	eax,4		; format 12.4
		mov	edi,vertexBy
		mov	[edi],eax

		mov	ax,x3
		cwde			; extend sign
		shl	eax,4		; format 12.4
		mov	edi,vertexCx
		mov	[edi],eax

		mov	ax,y3
		cwde			; extend sign
		shl	eax,4		; format 12.4
		mov	edi,vertexCy
		mov	[edi],eax

;-----------------------

		mov	ah,0
		mov	al,r_value	; red
		cwde			; extend sign
		shl	eax,12		; format 12.12
		mov	ax,0
		mov	edi,startR
		mov	[edi],eax

		mov	ah,0
		mov	al,g_value	; green
		cwde			; extend sign
		shl	eax,12		; format 12.12
		mov	ax,0
		mov	edi,startG
		mov	[edi],eax

		mov	ah,0
		mov	al,b_value	; blue
		cwde			; extend sign
		shl	eax,12		; format 12.12
		mov	edi,startB
		mov	[edi],eax

		mov	ax,z_value	; z (depth)
		cwde			; extend sign
		shl	eax,12		; format 12.12
		mov	edi,startZ
		mov	[edi],eax


;---------------------------

		mov	ax,0		; format 12.12
		cwde			; extend sign
		mov	edi,dRdX
		mov	[edi],eax

		mov	ax,0		; format 12.12
		cwde			; extend sign
		mov	edi,dRdY
		mov	[edi],eax

		mov	ax,0		; format 12.12
		cwde			; extend sign
		mov	edi,dGdX
		mov	[edi],eax

		mov	ax,0		; format 12.12	to dark
		cwde			; extend sign
		mov	edi,dGdY
		mov	[edi],eax

		mov	ax,0		; format 12.12
		cwde			; extend sign
		mov	edi,dBdX
		mov	[edi],eax

		mov	ax,0		; format 12.12	to dark
		cwde			; extend sign
		mov	edi,dBdY
		mov	[edi],eax

		mov	ax,0		; format 12.12
		cwde			; extend sign
		mov	edi,dZdX
		mov	[edi],eax

		mov	ax,0		; format 12.12	to dark
		cwde			; extend sign
		mov	edi,dZdY
		mov	[edi],eax



;------- execute -----------

		mov	eax,0
		mov	edi,triangleCmd
		mov	[edi],eax

		mov	eax,1		;
		ror	eax,1		; set area bit
		mov	[edi],eax	; draw if counterclockwise

		RET
drw_tri_z	ENDP

;---------------------------------------------------------------------
;---------------------------------------------------------------------

rotated_xyz_ptr dd	0   ; ptr to array of rotated x,y,z (words)
screen_xyzc_ptr dd	0   ; ptr to array of projected x,y,z (words)
			    ;			    + c (argb) (bytes)

msg_alloc_rot_err db	"rotated_xyz : mem alloc error",0
msg_alloc_scr_err db	"screen_xyzc : mem alloc error",0

;-----------------------------------

init_3d_arrays	PROC	near	; rotated_xyz

;--------------- alloc memory for roteted --

		mov	ax,0ff11h	    ; GetMemLinear32
		movzx	ecx,nr_of_points    ; x
		add	cx,nr_of_points     ; y
		add	cx,nr_of_points     ; z (max.21k points)
		shl	ecx,1		    ; to word size
		int	31h
		jnc	@@alloc_r_ok
		mov	edi,offset msg_alloc_rot_err
		call	out_msg_edi
		call	prg_exit
    @@alloc_r_ok:
		mov	rotated_xyz_ptr,esi

;--------------- alloc memory for projected ----


		movzx	eax,nr_of_points    ; x
		mov	ebx,10
		mul	ebx
		mov	ecx,eax
		mov	ax,0ff11h	    ; GetMemLinear32
		int	31h
		jnc	@@alloc_s_ok
		mov	edi,offset msg_alloc_scr_err
		call	out_msg_edi
		call	prg_exit
    @@alloc_s_ok:
		mov	screen_xyzc_ptr,esi


		RET
init_3d_arrays	ENDP

;---------------------------------------------------------------------

normals_ptr	dd	0   ; ptr to array of normal x,y,z (words)
rotated_normals_ptr dd	0   ; ptr to array of rotated n. x,y,z (words)

msg_alloc_nor_err db	"normals array : mem alloc error",0
msg_alloc_rnor_err db	"rotated normals : mem alloc error",0

;-----------------------------------

init_normal_arrays PROC near

;--------------- alloc memory for normals --

		mov	ax,0ff11h	    ; GetMemLinear32
		movzx	ecx,nr_of_faces     ; x
		add	cx,nr_of_faces	    ; y
		add	cx,nr_of_faces	    ; z (max.21k faces)
		shl	ecx,1		    ; to word size
		int	31h
		jnc	@@alloc_n_ok
		mov	edi,offset msg_alloc_nor_err
		call	out_msg_edi
		call	prg_exit
    @@alloc_n_ok:
		mov	normals_ptr,esi

;-------------- alloc memory for rotated n. ----

		mov	ax,0ff11h	    ; GetMemLinear32
		movzx	ecx,nr_of_faces     ; x
		add	cx,nr_of_faces	    ; y
		add	cx,nr_of_faces	    ; z (max. 21k faces)
		shl	ecx,1		    ; to word size
		int	31h
		jnc	@@alloc_r_ok
		mov	edi,offset msg_alloc_rnor_err
		call	out_msg_edi
		call	prg_exit
    @@alloc_r_ok:
		mov	rotated_normals_ptr,esi


		RET
init_normal_arrays ENDP

;---------------------------------------------------------------------

normalize_lv	PROC	near	; normalize light vector
				;   light_vector -> n_light_vector

		mov	ax,light_vector
		cwde
		mov	ebx,eax
		imul	 ebx
		mov	ecx,eax

		mov	ax,light_vector+2
		cwde
		mov	ebx,eax
		imul	 ebx
		add	ecx,eax

		mov	ax,light_vector+4
		cwde
		mov	ebx,eax
		imul	 ebx
		add	eax,ecx

		call	_sqrt	    ; eax -> eax (=len1)

		mov	ebx,eax
		mov	cx,1000 	    ; scale
		mov	ax,light_vector
		imul	cx
		idiv	bx
		mov	n_light_vector,ax

		mov	ax,light_vector+2
		imul	 cx
		idiv	bx
		mov	n_light_vector+2,ax

		mov	ax,light_vector+4
		imul	 cx
		idiv	bx
		mov	n_light_vector+4,ax


		RET
normalize_lv	ENDP

;같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같�
;
; _sqrt: Routine courtesy TRAN
;
; In:
;   EAX - number to take root of
; Out:
;   EAX - root
;
;같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같�
_sqrtbasetbl db 0,1,4,9,16,25,36,49,64,81,100,121,144,169,196,225

         align 4
_sqrt:
         pushad
         mov ebp,eax
         bsr ebx,eax
         jnz short _sqrtf0
         xor ebx,ebx
_sqrtf0:
         shr ebx,3
         lea eax,[ebx*8]
         mov cl,32
         sub cl,al
         rol ebp,cl
         mov eax,ebp
         movzx eax,al
         mov edi,offset _sqrtbasetbl
         mov ecx,10h
_sqrtl0:
         scasb
         je short _sqrtl0d
         jb short _sqrtl0d2
         loop _sqrtl0
         inc edi
_sqrtl0d2:
         dec edi
         inc cl
_sqrtl0d:
         movzx edx,byte ptr [edi-1]
         dec cl
         xor cl,0fh
         mov edi,ecx
         mov ecx,ebx
         jecxz short _sqrtdone
         sub eax,edx
_sqrtml:
         shld eax,ebp,8
         rol ebp,8
         mov ebx,edi
         shl ebx,5
         xor edx,edx
         mov esi,eax
         div ebx
         rol edi,4
         add edi,eax
         add ebx,eax
_sqrtf2:
         imul eax,ebx
         mov edx,eax
         mov eax,esi
         sub eax,edx
         jc short _sqrtf1
         loop _sqrtml
_sqrtdone:
         mov [esp+28],edi
         popad
         ret
_sqrtf1:
         dec ebx
         dec edi
         movzx eax,bl
         and al,1fh
         jmp _sqrtf2


;---------------------------------------------------------------------

cur_normals_ptr dd	0	; tmp.

n_cur_face	dw	0	; tmp. for normals

;-----------------------

calc_normals	PROC	near

		mov	eax,normals_ptr
		mov	cur_normals_ptr,eax	; init

		mov	edi,facelist_ptr
		mov	esi,pointlist_w_ptr
		mov	n_cur_face,0		; init
		mov	cx,nr_of_faces
    @@again:
		call	calc_1_normal
		add	edi,8		    ; x,y,z,( )
		add	esi,8		    ; to next face
		add	n_cur_face,1	    ; to next face
		add	cur_normals_ptr,6   ; to next (x,y,z)

		loopw	@@again


		RET
calc_normals	ENDP

;---------------------------------------------------------------------

n_pointnr_0	dw	0	; tmp. pointnumber 0
n_pointnr_1	dw	0
n_pointnr_2	dw	0

point_0_x	dw	0	; tmp.	base value + substore for calc
point_0_y	dw	0
point_0_z	dw	0

point_1_x	dw	0
point_1_y	dw	0
point_1_z	dw	0

point_2_x	dw	0
point_2_y	dw	0
point_2_z	dw	0

cross_x 	dd	0	; tmp.	result of cross product
cross_y 	dd	0
cross_z 	dd	0

len1		dd	0	; tmp.	length 1


;---------------------------

calc_1_normal	PROC	near

		push	edi
		push	esi
		push	cx

;--- get point numbers --

		mov	edi,facelist_ptr
		movzx	eax,n_cur_face
		shl	eax,3		    ; *8
		add	edi,eax 	    ; to record
		movzx	eax,word ptr [edi]  ; get pointnr 0 of face
		mov	n_pointnr_0,ax
		movzx	eax,word ptr [edi+2]  ; get pointnr 1 of face
		mov	n_pointnr_1,ax
		movzx	eax,word ptr [edi+4]  ; get pointnr 2 of face
		mov	n_pointnr_2,ax

;--- get point values ---

		mov	esi,pointlist_w_ptr
		movzx	eax,n_pointnr_0
		mov	ebx,eax
		shl	eax,1		    ; *2
		shl	ebx,2		    ; *4
		add	esi,eax
		add	esi,ebx

		mov	ax,word ptr [esi]   ; get x value
		mov	point_0_x,ax
		mov	ax,word ptr [esi+2] ; get y value
		mov	point_0_y,ax
		mov	ax,word ptr [esi+4] ; get z value
		mov	point_0_z,ax

		mov	esi,pointlist_w_ptr
		movzx	eax,n_pointnr_1
		mov	ebx,eax
		shl	eax,1		    ; *2
		shl	ebx,2		    ; *4
		add	esi,eax
		add	esi,ebx

		mov	ax,word ptr [esi]   ; get x value
		mov	point_1_x,ax
		mov	ax,word ptr [esi+2] ; get y value
		mov	point_1_y,ax
		mov	ax,word ptr [esi+4] ; get z value
		mov	point_1_z,ax

		mov	esi,pointlist_w_ptr
		movzx	eax,n_pointnr_2
		mov	ebx,eax
		shl	eax,1		    ; *2
		shl	ebx,2		    ; *4
		add	esi,eax
		add	esi,ebx

		mov	ax,word ptr [esi]   ; get x value
		mov	point_2_x,ax
		mov	ax,word ptr [esi+2] ; get y value
		mov	point_2_y,ax
		mov	ax,word ptr [esi+4] ; get z value
		mov	point_2_z,ax

;-----------------------
					; must be clockwise (?)

		; subtract to have 2 vectors for cross product
		;_0xyz-1xyz, _2xyz-1xyz

		mov	ax,point_1_x
		mov	bx,point_1_y
		mov	cx,point_1_z

		sub	point_0_x,ax
		sub	point_0_y,bx
		sub	point_0_z,cx

		sub	point_2_x,ax
		sub	point_2_y,bx
		sub	point_2_z,cx

;-----------
		; use subtracted vectors 0 + 2
		; cross point_0_xyz x point_2_xyz
		    ; C = A x B  (A cross B)
		    ; Cx=Ay*Bz - By*Az
		    ; Cy=Az*Bx - Bz*Ax
		    ; Cz=Ax*By - Bx*Ay

		; Cx=Ay*Bz - By*Az

		mov	ax,point_0_y
		imul	point_2_z
		shl	edx,16
		mov	dx,ax
		mov	ebx,edx     ; save in ebx

		mov	ax,point_2_y
		imul	point_0_z
		shl	edx,16
		mov	dx,ax

		sub	ebx,edx
		mov	cross_x,ebx


		; Cy=Az*Bx - Bz*Ax

		mov	ax,point_0_z
		imul	point_2_x
		shl	edx,16
		mov	dx,ax
		mov	ebx,edx     ; save in ebx

		mov	ax,point_2_z
		imul	point_0_x
		shl	edx,16
		mov	dx,ax

		sub	ebx,edx
		mov	cross_y,ebx


		; Cz=Ax*By - Bx*Ay

		mov	ax,point_0_x
		imul	point_2_y
		shl	edx,16
		mov	dx,ax
		mov	ebx,edx     ; save in ebx

		mov	ax,point_2_x
		imul	point_0_y
		shl	edx,16
		mov	dx,ax

		sub	ebx,edx
		mov	cross_z,ebx


;-----------
		; len1=sqrt(x*x + y*y + z*z)   ; of cross_xyz

	     finit  ; xxx debug  (else len1 is often 80000000h)

		fild	cross_x
		fimul	cross_x
		fild	cross_y
		fimul	cross_y
		fild	cross_z
		fimul	cross_z
		fadd	st,st(1)
		fadd	st,st(2)
		fsqrt
		frndint 		; round to integer
		fistp	len1		; has to be dd	( > +-32k)
		ffree	st
		ffree	st

		; normal=cross_x/len1, cross_y/len1, cross_z/len1

		mov	edi,cur_normals_ptr

		mov	word ptr [edi],0	; init, in case
		mov	word ptr [edi+2],0	;   of
		mov	word ptr [edi+4],0	;   len1=0

		cmp	len1,0
		je	@@no0div

		mov	eax,cross_x
	       ;cdq
	       ;mov	ebx,1024	; 2^10 to scale normal
		mov	ebx,1000	; *1000 to scale normal
		imul	ebx
		idiv	len1		; -> scaled norm. x in ax
		mov	word ptr [edi],ax

		mov	eax,cross_y
	       ;cdq
		imul	ebx
		idiv	len1		; -> scaled norm. y in ax
		mov	word ptr [edi+2],ax

		mov	eax,cross_z
	       ;cdq
		imul	ebx
		idiv	len1		; -> scaled norm. z in ax
		mov	word ptr [edi+4],ax

    @@no0div:

;-----------

		pop	cx
		pop	esi
		pop	edi


		RET
calc_1_normal	ENDP


;---------------------------------------------------------------------
;=====================================================================

;---------------------------------------------------------------------

my_triangle	PROC	near

		mov	ax,100
		cwde			; extend sign
		shl	eax,4		; format 12.4
		mov	edi,vertexAx
		mov	[edi],eax

		mov	ax,100
		cwde			; extend sign
		shl	eax,4		; format 12.4
		mov	edi,vertexAy
		mov	[edi],eax

		mov	ax,600
		cwde			; extend sign
		shl	eax,4		; format 12.4
		mov	edi,vertexBx
		mov	[edi],eax

		mov	ax,200
		cwde			; extend sign
		shl	eax,4		; format 12.4
		mov	edi,vertexBy
		mov	[edi],eax

		mov	ax,080
		cwde			; extend sign
		shl	eax,4		; format 12.4
		mov	edi,vertexCx
		mov	[edi],eax

		mov	ax,300
		cwde			; extend sign
		shl	eax,4		; format 12.4
		mov	edi,vertexCy
		mov	[edi],eax

;---------------------------

		mov	ax,100		; color + 1 ?
		cwde			; extend sign
		shl	eax,12		; format 12.12
		mov	ax,0
		mov	edi,startR
		mov	[edi],eax

		mov	ax,100		; color + 1 ?
		cwde			; extend sign
		shl	eax,12		; format 12.12
		mov	ax,0
		mov	edi,startG
		mov	[edi],eax

		mov	ax,0
		cwde			; extend sign
		shl	eax,12		; format 12.12
		mov	edi,startB
		mov	[edi],eax

;---------------------------

		mov	ax,450		; format 12.12
		cwde			; extend sign
		mov	edi,dRdX
		mov	[edi],eax

		mov	ax,450		; format 12.12
		cwde			; extend sign
		mov	edi,dRdY
		mov	[edi],eax

		mov	ax,450		; format 12.12
		cwde			; extend sign
		mov	edi,dGdX
		mov	[edi],eax

		mov	ax,-450 	; format 12.12	to dark
		cwde			; extend sign
		mov	edi,dGdY
		mov	[edi],eax

;------- tst Z val. --------

		mov	ax,120		; xxx test z
		cwde			; extend sign
		shl	eax,12		; format 20.12
		mov	edi,startZ
		mov	[edi],eax

;------- execute -----------

		mov	eax,0
		mov	edi,triangleCmd
		mov	[edi],eax

		RET
my_triangle	ENDP

;=====================================================================
;---------------------------------------------------------------------

clip_3d_left	dw	10	; min. x    (0)
clip_3d_right	dw	630	; max. x+1  (640
clip_3d_top	dw	20	; min. y    (0)
clip_3d_bottom	dw	380	; max. y+1  (480)

clip_3d_enable	db	1	; 0=disable, 1=enable (fbz bit 0)

fillcolor	db	0	; blue	    (to color1 reg.)
		db	0	; green
		db	0	; red
		db	0	; alpha

filldepth	dw	0ffffh	; depth     (to zaColor reg.)
		db	0	; reserved
		db	0	; alpha

;-------------------------------

setup_3d	PROC	near



		mov	video_mode,111h     ; 111h=640*480*64k
					    ;	    (5:6:5)
					    ; 112h=640*480*16M
					    ;	   (8:8:8)
		call	setup_vbe   ; all to setupvbe for lfb

;-----------------------------------------------

		call	pci_check     ; search + get avenger adr.
		call	map_2d3dregs  ; memBaseAddr0 -> _2dBase, _3dBase
		call	set_all_io_reg_addr
		call	set_all_2d_reg_addr
		call	set_all_3d_reg_addr

;-----------------------

	       ;jmp	noreset

		;reset avenger 3d

		mov	edi,_ioBase
		add	edi,10h 	; +10h -> miscInit0
		mov	eax,[edi]
		or	eax,1		; set fbi reset bit
		mov	[edi],eax
		and	al,11111110b	; clear fbi reset bit
		mov	[edi],eax

			    ; tri.out and pixels_in are cleared
			    ;	by fbi reset, pixels_out not !

		noreset:

;-----------------------

		mov	eax,1		; clear pixels out
		mov	edi,nopCMD
		mov	[edi],eax

		mov	eax,10b 	; clear tri. out
		mov	edi,nopCMD
	       ;mov	[edi],eax

;-----------------------

		call	setup_640_16	; 640*480, 16 bpp   (2d)

;-------------------------------------------

		mov	edi,fbiPixelsIn
		mov	eax,[edi]		; GPU debug

		mov	edi,fbiChromaFail
		mov	ebx,[edi]		; GPU debug

		mov	edi,fbiZfuncFail
		mov	ecx,[edi]		; GPU debug

		mov	edi,fbiAfuncFail
		mov	edx,[edi]		; GPU debug

		mov	edi,fbiPixelsOut
		mov	ebp,[edi]		; GPU debug

		mov	edi,status_3d
		mov	eax,[edi]

;-----------------------

		mov	edi,lfbMode
		mov	eax,[edi]
		mov	eax,0
	       ;or	ah,1		; set bit 8, enable pp wr
		or	al,14		; set depth,1:5:5:5 mode
	       ;mov	al,0
	       ;mov	ax,0
		mov	[edi],eax
	       ;mov	 eax,[edi]

;-----------------------

		mov	edi,colBufferAddr
		mov	eax,[edi]		; xxx  debug
		mov	edi,colBufferStride
		mov	ebx,[edi]		; xxx  debug

		mov	edi,colBufferStride
		mov	eax,0
		mov	ax,BytesPerScanLine
		mov	[edi],eax		; !!!!!

		mov	eax,0
		mov	ax,bytesPerScanLine
		mov	edi,auxBufferStride	; ??
		mov	[edi],eax

		mov	edi,auxBufferAddr	; depth buffer
		mov	eax,page_len
		shl	eax,1			; to page 2
		mov	[edi],eax		; ?

;-----------------------

		mov	ax,clip_3d_left 	; min. x
		shl	eax,16
		mov	ax,clip_3d_right	; max. x +1
		mov	edi,clipLeftRight
		mov	[edi],eax

		mov	ax,clip_3d_top		; min. y
		shl	eax,16
		mov	ax,clip_3d_bottom	; max. y +1
		mov	edi,clipTopBottom
		mov	[edi],eax

;-----------------------

		mov	edi,fbzColorPath
		mov	eax,[edi]
		mov	ebx,1
		shl	ebx,29		; bit 29
		or	eax,ebx 	; enable anti-aliasing (?)
			   ;10987654321098765432109876543210
		or	eax,00000000000000000100000000000000b
				    ; bit 14 for less color steps
				    ; bit 16 cc_invert_output
			   ;10987654321098765432109876543210
		or	eax,00000100000000000000000000000000b
				    ; bit 26 subpixel correction
			; (sometimes if tri. are putted together)

		mov	[edi],eax

		mov	edi,fbzMode
		mov	eax,[edi]
		cmp	clip_3d_enable,1
		jne	@@noclip
		or	al,1	    ; bit 0, enable clipping
    @@noclip:	or	ah,10b	    ;	!!! bit 9, enable rgb wr.
		or	ah,100b     ; (!) bit 10, en. depth buf. wr.
		or	al,00010000b	; bit 4, en.depth buffering

					; depth OP  bits 5-7
	       ;or	al,00000000b	; (000=never
		or	al,00100000b	; (001=less than
	       ;or	al,01000000b	; (010=equal
	       ;or	al,01100000b	; (011=less than or equal
	       ;or	al,10000000b	; (100=greater than
	       ;or	al,10100000b	; (101=not equal
	       ;or	al,11000000b	; (110=greater than or equal
	       ;or	al,11100000b	; (111=always)


		or	ah,1	    ;  !!!  bit 8, enable dither.
				    ;		(less color steps)
			   ;10987654321098765432109876543210
		or	eax,00000000000000000000100000000000b
				    ; bit 11 dither 2*2 not 4*4

		mov	[edi],eax

;--- for fastfill ------

		mov	eax,dword ptr fillcolor
		mov	edi,color1	; to fill colorbuffer
		mov	[edi],eax

		mov	eax,dword ptr filldepth
		mov	edi,zaColor	; to fill depthbuffer
		mov	[edi],eax


		RET
setup_3d	ENDP

;=====================================================================

draw_3d_clip	PROC	near	; draw 3d clip window if clip is enab.
				;   and is < screen resolution

		cmp	clip_3d_enable,1    ; enabled ?
		je	@@isen
		RET
    @@isen:

		mov	r,120		; clip window color
		mov	g,120
		mov	b,120
		call	set_color

				; left+top inclusive
				; right+bottom exclusive

		cmp	clip_3d_left,0
		je	@@noleft

		mov	ax,clip_3d_left
		sub	ax,1
		mov	xs,ax
		mov	xe,ax
		mov	ax,clip_3d_top
		cmp	ax,0
		je	@@1
		sub	ax,1
	@@1:	mov	ys,ax
		mov	ax,clip_3d_bottom
		sub	ax,1
		mov	ye,ax
		call	line		    ; draw left x border
    @@noleft:
		mov	ax,clip_3d_right
		cmp	ax,XResolution
		jnb	@@noright

		mov	xs,ax
		mov	xe,ax
		mov	ax,clip_3d_top
		mov	ys,ax
		mov	ax,clip_3d_bottom
		mov	ye,ax
		call	line		    ; draw right x border
    @@noright:
		cmp	clip_3d_top,0
		je	@@notop

		mov	ax,clip_3d_top
		sub	ax,1
		mov	ys,ax
		mov	ye,ax
		mov	ax,clip_3d_left
		mov	xs,ax
		mov	ax,clip_3d_right
		mov	xe,ax
		call	line		    ; draw top y
    @@notop:
		mov	ax,clip_3d_bottom
		cmp	ax,YResolution
		jnb	@@nobottom

		mov	ys,ax
		mov	ye,ax
		mov	ax,clip_3d_left
		cmp	ax,0
		je	@@2
		sub	ax,1
	@@2:
		mov	xs,ax
		mov	ax,clip_3d_right
		mov	xe,ax
		call	line		    ; draw bottom y
    @@nobottom:



		RET
draw_3d_clip	ENDP

;---------------------------------------------------------------------

line		PROC	near	; using xs,ys,xe,ye

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
	       ;mov	eax,0cc000106h
		mov	eax,0cc000106h
		mov	edi,command
		mov	[edi],eax     ; cmd reg.

		RET
line		ENDP

;=====================================================================
;---------------------------------------------------------------------

;hexchars	 db	 "0123456789ABCDEF"  ; for xlat_al


msg_fbiTrianglesOut db	"fbiTrianglesOut: ",0
msg_fbiPixelsIn     db	"fbiPixelsIn:     ",0
msg_fbiPixelsOut    db	"fbiPixelsOut:    ",0
msg_fbiChromaFail   db	"fbiChromaFail: ",0
msg_fbiZfuncFail    db	"fbiZfuncFail:  ",0
msg_fbiAfuncFail    db	 "fbiAfuncFail:  ",0


;---------------------------------------------------------------------

a_wr_debug	PROC	near	; accelerated wr debug registers

		mov	text_x,0	; start_x
		mov	text_y,25	; start_y

		mov	edi,offset msg_fbiTrianglesOut
		call	a_out_msg_edi

		mov	edi,fbiTrianglesOut
		mov	eax,[edi]
	       ;call	a_wr_8_hex
		call	a_wr_eax_dec

;---------------------

		mov	text_x,0
		add	text_y,2

		mov	edi,offset msg_fbiPixelsIn
		call	a_out_msg_edi

		mov	edi,fbiPixelsIn
		mov	eax,[edi]
	       ;call	a_wr_8_hex
		call	a_wr_eax_dec

;---------------------

		mov	text_x,0
		add	text_y,1

		mov	edi,offset msg_fbiPixelsOut
		call	a_out_msg_edi

		mov	edi,fbiPixelsOut
		mov	eax,[edi]
	       ;call	a_wr_8_hex
		call	a_wr_eax_dec

;---------------------

		mov	text_x,40
		sub	text_y,2

		mov	edi,offset msg_fbiChromaFail
		call	a_out_msg_edi

		mov	edi,fbiChromaFail
		mov	eax,[edi]
	       ;call	a_wr_8_hex
		call	a_wr_eax_dec

;---------------------

		mov	text_x,40
		add	text_y,1

		mov	edi,offset msg_fbiZfuncFail
		call	a_out_msg_edi

		mov	edi,fbiZfuncFail
		mov	eax,[edi]
	       ;call	a_wr_8_hex
		call	a_wr_eax_dec

;---------------------

		mov	text_x,40
		add	text_y,1

		mov	edi,offset msg_fbiAfuncFail
		call	a_out_msg_edi

		mov	edi,fbiAfuncFail
		mov	eax,[edi]
	       ;call	a_wr_8_hex
		call	a_wr_eax_dec


		RET
a_wr_debug	ENDP

;--------------- from alib ------ CONV07.ASM -------------------------
;---------------------------------------------------------------------

a_wr_eax_dec	PROC	near	    ; right aligned

		push	edx
		push	edi

		mov	edx,eax
		shr	edx,16		; to dx:ax

		call	clear_dec_string

		mov	edi,offset dec_string
		add	edi,12		; to end
		call	dd_to_dec_string ; convert to string

		mov	edi,offset dec_string
		call	a_out_msg_edi

		pop	edi
		pop	edx

		RET
a_wr_eax_dec	ENDP

;---------------------------------------------------------------------

clear_dec_string PROC	near

		push	cx

		mov	edi,offset dec_string

		mov	cx,12		; len.
    cldstragain:
		mov	byte ptr [edi],20h
		add	edi,1
		loopw	cldstragain

		pop	cx

		RET
clear_dec_string ENDP

;---------------------------------------------------------------------


;---------------------------------------------------------------------

fastfill	PROC	near	; clear clip area
				;   fill colorbuffer w. reg. color1
				;   fill depthbuffer w. reg. zaColor

		push	edi

		mov	edi,fastfillCMD
		mov	[edi],eax	    ; eax don`t matter

		pop	edi

		RET
fastfill	ENDP

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

;---------------------------------------------------------------------

set_color	PROC	near	; r,g,b     for 5:6:5 mode
				;	...0_ rrrr_rggg _ gggb_bbbb
				;		 ah	      al

		mov	eax,0
		mov	ah,r
		and	ah,11111000b	; truncate 3 low red bits
		mov	bx,0
		mov	bl,g
		and	bl,11111100b	; truncate 2 low green bits
		shl	bx,3		; shift it to right pos.
		or	ax,bx		; combine red+green
		mov	bx,0
		mov	bl,b
		shr	bl,3	    ; shift 3 low blue bits away
		or	ax,bx	    ; combine red/green + blue
		mov	edi,colorFore
		mov	[edi],eax

		RET
set_color	ENDP

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



;=====================================================================
;---------------------------------------------------------------------

		.DATA

;------- for accelerated text ----------------------------------------

text_char	db	0		; cur ascii

text_x		dw	0		; text cursor x
text_y		dw	0

text_y_offset	dw	0	; can be used for write to another page
				; 0 = page 0, YResolution = page 1, ...

text_x_start	dw	0
text_y_start	dw	0

text_x_end	dw	79	; 79  for 640*480
text_y_end	dw	29	; 29  for 640*480

text_fore_r	db	18	; text color fore  r
text_fore_g	db	36	; text color fore  g
text_fore_b	db	18	; text color fore  b

text_back_r	db	0	; text color back  r
text_back_g	db	0	; text color back  g
text_back_b	db	0	; text color back  b


;---------------------------------------------------------------------

		.CODE

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
	       ;add	text_back_r,80	    ; xxx debug
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
		add	ax,text_y_offset    ; if 0 = page 0
		shl	eax,16
		mov	ax,text_x	    ; x
		shl	ax,3		    ; *8
		mov	edi,dstXY
		mov	[edi],eax

		mov	eax,0cc000101h	    ; immed. / screen blt.
		or	ah,00000100b	    ; inc x dest.
		mov	edi,command
		mov	[edi],eax     ; cmd reg.

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
		add	ax,text_y_offset    ; if 0 = page 0
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


;----------------------------------------------------------------------

a_crlf		PROC	near

		push	eax

		mov	al,0dh		; cr
		call	a_writt_al

		mov	al,0ah		; lf
		call	a_writt_al

		pop	eax

		RET
a_crlf		ENDP

;---------------------------------------------------------------------

a_scroll_up	PROC	near	; for text

		mov	ax,3		    ; 16 bpp RGB  xxxx!
		shl	eax,16
		mov	ax,BytesPerScanLine
		mov	edi,srcFormat
		mov	dword ptr [edi],eax

	       ;mov	ax,450		    ; y
		mov	ax,18		    ; y     (18)
		add	ax,text_y_offset    ; if 0 = page 0
		shl	eax,16
		mov	ax,0		    ; x
		mov	edi,srcXY
		mov	[edi],eax

		mov	ax,464		    ; y     16
		shl	eax,16
		mov	ax,640		    ; x
		mov	edi,dstSize
		mov	[edi],eax

		mov	ax,0		    ; y     448 (-18)
		add	ax,text_y_offset    ; if 0 = page 0
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
		add	ax,text_y_offset    ; if 0 = page 0
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

		push	eax
		push	ebx
		push	ecx

		mov	eax,0
		mov	ebx,0
		mov	ecx,0

		mov	al,text_fore_r
		shl	eax,11
		mov	bl,text_fore_g
		shl	ebx,5
		mov	cl,text_fore_b

		or	ax,bx
		or	ax,cx

		mov	edi,colorFore
		mov	[edi],eax

		mov	eax,0
		mov	ebx,0
		mov	ecx,0

		mov	al,text_back_r
		shl	eax,11
		mov	bl,text_back_g
		shl	ebx,5
		mov	cl,text_back_b

		or	ax,bx
		or	ax,cx

		mov	edi,colorBack
		mov	[edi],eax

		pop	ecx
		pop	ebx
		pop	eax

		RET
set_text_color	ENDP

;=====================================================================
;---------------------------------------------------------------------

setup_640_16	PROC	near	; 640*480, 16 bpp (5:6:5)

;------- set srcFormat -----

		mov	ax,3			; 16 bpp RGB
		shl	eax,16
		mov	ax,BytesPerScanLine
		mov	edi,srcFormat
		mov	dword ptr [edi],eax


;------- set dstFormat -----

		mov	ax,3			; 16 bpp RGB
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

	       ;mov	ax,480		    ; max. y +1
		mov	ax,0ffffh	; xxx enable multi pages
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

;------- bugfix text -------

		call	chk_win_or_dos
		cmp	win_flag,1
		jne	stup64016_dos	    ; xxxx deactivated

		mov	eax,offset a_wr_char_hst    ; host to screen
	       mov     addr_a_wr_char,eax      ; change def. addr.
    stup64016_dos:			; no change needed for dos


		RET
setup_640_16	ENDP

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

base0		dd	0		; mapped memBaseAddr0

_ioBase 	dd	0		; io register remap
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
		jmp	prg_exit_pci
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
		jmp	prg_exit_device
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
		jmp	prg_exit_pci
    ra0noerr:
		mov	memBaseAddr0,ecx

;---------------------------------------------------------------------

		mov	ax,0b10ah	; read config dword
		mov	bh,bus_num
		mov	bl,dev_func_num
		mov	di,20		; register num (addr)
		int	1ah

		jnc	ra1noerr
		jmp	prg_exit_pci
    ra1noerr:
		mov	memBaseAddr1,ecx

;---------------------------------------------------------------------

		mov	ax,0b10ah	; read config dword
		mov	bh,bus_num
		mov	bl,dev_func_num
		mov	di,24		; register num (addr)
		int	1ah

		jnc	ioanoerr
		jmp	prg_exit_pci

    ioanoerr:
		mov	ioBaseAddr,ecx

		RET
pci_check	ENDP

;---------------------------------------------------------------------

map_2d3dregs	PROC	near	; memBaseAddr0 -> _2dBase, _3dBase
				; (physical memory mapping)

		mov	ebx,memBaseAddr0
		mov	cx,bx
		shr	ebx,16		; = BX:CX

		mov	eax,2000000h	; 32 M (32M, 2 + 6*`0)
		shr	eax,16
		mov	si,ax		; (64K Blocks)
		mov	di,0		; = SI:DI = Size

		mov	ax,800h
		int	31h

	       ;jnc

		mov	eax,0
		mov	ax,bx
		shl	eax,16
		mov	ax,cx
		mov	base0,eax
		mov	_ioBase,eax
		add	eax,100000h
		mov	_2dBase,eax
		add	eax,100000h
		mov	_3dBase,eax


		RET
map_2d3dregs	ENDP

;---------------------------------------------------------------------

set_all_io_reg_addr PROC    near    ; set all io register addresses
				    ; for easy text adressing (?)

		mov	eax,_ioBase	    ; base address
		mov	ebx,4		    ; adder

		mov	status_io,eax	    ; (+0)
		add	eax,ebx
		mov	pciInit0,eax	    ; (+4)   4
		add	eax,ebx
		mov	sipMonitor,eax	    ; (+8)   8
		add	eax,ebx
		mov	lfbMemoryConfig,eax ; (+12) 0ch
		add	eax,ebx
		mov	miscInit0,eax	    ; (+16) 10h
		add	eax,ebx
		mov	miscInit1,eax	    ; (+20) 14h
		add	eax,ebx
		mov	dramInit0,eax	    ; (+24) 18h
		add	eax,ebx
		mov	dramInit1,eax	    ; (+28) 1ch
		add	eax,ebx
		mov	agpInit0,eax	    ; (+32) 20h
		add	eax,ebx
		mov	tmuGbeInit,eax	    ; (+36) 24h
		add	eax,ebx
		mov	vgaInit0,eax	    ; (+40) 28h
		add	eax,ebx
		mov	vgaInit1,eax	    ; (+44) 2ch
		add	eax,ebx
		mov	dramCommand,eax     ; (+48) 30h
		add	eax,ebx
		mov	dramData,eax	    ; (+52) 34h
		add	eax,ebx
		mov	strapInfo,eax	    ; (+56) 38h
		add	eax,ebx
		mov	VidTvOutBlankVCount,eax ; (+60)
		add	eax,ebx
		mov	pllCtrl0,eax	    ; (+64) 40h
		add	eax,ebx
		mov	pllCtrl1,eax	    ; (+68) 44h
		add	eax,ebx
		mov	pllCtrl2,eax	    ; (+72) 48h
		add	eax,ebx
		mov	dacMode,eax	    ; (+76) 4ch
		add	eax,ebx
		mov	dacAddr,eax	    ; (+80) 50h
		add	eax,ebx
		mov	dacData,eax	    ; (+84) 54h
		add	eax,ebx
		mov	rgbMaxDelta,eax     ;  (+88) 58h
		add	eax,ebx
		mov	vidProcCfg,eax	    ;  (+92) 5ch
		add	eax,ebx
		mov	hwCurPatAddr,eax    ;  (+96) 60h
		add	eax,ebx
		mov	hwCurLoc,eax	    ; (+100) 64h
		add	eax,ebx
		mov	hwCurC0,eax	    ; (+104) 68h
		add	eax,ebx
		mov	hwCurC1,eax	    ; (+108) 6ch
		add	eax,ebx
		mov	vidInFormat,eax     ; (+112) 70h
		add	eax,ebx
		mov	vidTvOutBlankHCount,eax   ; (+116) 74h
		add	eax,ebx
		mov	vidSerialParallelPort,eax ; (+120) 78h
		add	eax,ebx
		mov	vidInXDecimDeltas,eax	  ; (+124) 7ch
		add	eax,ebx
		mov	vidInDecimInitErrs,eax	  ; (+128) 80h
		add	eax,ebx
		mov	vidInYDecimDeltas,eax	  ; (+132) 84h
		add	eax,ebx
		mov	vidPixelBufThold,eax	  ; (+136) 88h
		add	eax,ebx
		mov	vidChromaMin,eax	  ; (+140) 8ch
		add	eax,ebx
		mov	vidChromaMax,eax	  ; (+144) 90h
		add	eax,ebx
		mov	vidInStatusCurrentLine,eax ; (+148) 94h
		add	eax,ebx
		mov	vidScreenSize,eax	   ; (+152) 98h
		add	eax,ebx
		mov	vidOverlayStartCoords,eax  ; (+156) 9ch
		add	eax,ebx
		mov	vidOverlayEndScreenCoord,eax ; (+160)  0a0h
		add	eax,ebx
		mov	vidOverlayDudx,eax	     ; (+164)  0a4h
		add	eax,ebx
		mov	vidOverlayDudxOffsetSrcWidth,eax ; (+168)  0a8h
		add	eax,ebx
		mov	vidOverlayDvdy,eax	  ; (+172)  0ach
		add	eax,ebx
		mov	vga_b0,eax	    ; (+176)  0b0h
		add	eax,ebx
		mov	vga_b4,eax	    ; (+180)  0b4h
		add	eax,ebx
		mov	vga_b8,eax	    ; (+184)  0b8h
		add	eax,ebx
		mov	vga_bc,eax	    ; (+188)  0bch
		add	eax,ebx
		mov	vga_c0,eax	    ; (+192)  0c0h
		add	eax,ebx
		mov	vga_c4,eax	    ; (+196)  0c4h
		add	eax,ebx
		mov	vga_c8,eax	    ; (+200)  0c8h
		add	eax,ebx
		mov	vga_cc,eax	    ; (+204)  0cch
		add	eax,ebx
		mov	vga_d0,eax	    ; (+208)  0d0h
		add	eax,ebx
		mov	vga_d4,eax	    ; (+212)  0d4h
		add	eax,ebx
		mov	vga_d8,eax	    ; (+216)  0d8h
		add	eax,ebx
		mov	vga_dc,eax	    ; (+220)  0dch
		add	eax,ebx
		mov	vidOverlayDvdyOffset,eax    ; (+224)  0e0h
		add	eax,ebx
		mov	vidDesktopStartAddr,eax     ; (+228)  0e4h
		add	eax,ebx
		mov	vidDesktopOverlayStride,eax ; (+232)  0e8h
		add	eax,ebx
		mov	vidInAddr0,eax	    ; (+236)  0ech
		add	eax,ebx
		mov	vidInAddr1,eax	    ; (+240)  0f0h
		add	eax,ebx
		mov	vidInAddr2,eax	    ; (+244)  0f4h
		add	eax,ebx
		mov	vidInStride,eax     ; (+248)  0f8h
		add	eax,ebx
		mov	vidCurrOverlayStartAddr,eax ; (+252) 0fch


		RET
set_all_io_reg_addr ENDP


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

;---------------------------------------------------------------------

set_all_3d_reg_addr PROC    near    ; set all 3d register addresses
				    ; for easy text adressing (?)

		mov	eax,_3dBase	    ; base address
		mov	ebx,4		    ; adder

		mov	status_3d,eax	    ; (+0)
		add	eax,ebx
		mov	intrCtrl,eax	    ; (+4)
		add	eax,ebx
		mov	vertexAx,eax	    ; (+8)
		add	eax,ebx
		mov	vertexAy,eax	    ; (+12)
		add	eax,ebx
		mov	vertexBx,eax	    ; (+16)
		add	eax,ebx
		mov	vertexBy,eax	    ; (+20)
		add	eax,ebx
		mov	vertexCx,eax	    ; (+24)
		add	eax,ebx
		mov	vertexCy,eax	    ; (+28)
		add	eax,ebx
		mov	startR,eax	    ; (+32)
		add	eax,ebx
		mov	startG,eax	    ; (+36)
		add	eax,ebx
		mov	startB,eax	    ; (+40)
		add	eax,ebx
		mov	startZ,eax	    ; (+44)
		add	eax,ebx
		mov	startA,eax	    ; (+48)
		add	eax,ebx
		mov	startS,eax	    ; (+52)
		add	eax,ebx
		mov	startT,eax	    ; (+56)
		add	eax,ebx
		mov	startW,eax	    ; (+60)
		add	eax,ebx
		mov	dRdX,eax	    ; (+64)
		add	eax,ebx
		mov	dGdX,eax	    ; (+68)
		add	eax,ebx
		mov	dBdX,eax	    ; (+72)
		add	eax,ebx
		mov	dZdX,eax	    ; (+76)
		add	eax,ebx
		mov	dAdX,eax	    ; (+80)
		add	eax,ebx
		mov	dSdX,eax	    ; (+84)
		add	eax,ebx
		mov	dTdX,eax	    ; (+88)
		add	eax,ebx
		mov	dWdX,eax	    ; (+92)
		add	eax,ebx
		mov	dRdY,eax	    ; (+96)
		add	eax,ebx
		mov	dGdY,eax	    ; (+100)
		add	eax,ebx
		mov	dBdY,eax	    ; (+104)
		add	eax,ebx
		mov	dZdY,eax	    ; (+108)
		add	eax,ebx
		mov	dAdY,eax	    ; (+112)
		add	eax,ebx
		mov	dSdY,eax	    ; (+116)
		add	eax,ebx
		mov	dTdY,eax	    ; (+120)
		add	eax,ebx
		mov	dWdY,eax	    ; (+124)
		add	eax,ebx
		mov	triangleCMD,eax     ; (+128)
		add	eax,ebx
		mov	reserved_132,eax    ; (+132)
		add	eax,ebx
		mov	fvertexAx,eax	    ; (+136)
		add	eax,ebx
		mov	fvertexAy,eax	    ; (+140)
		add	eax,ebx
		mov	fvertexBx,eax	    ; (+144)
		add	eax,ebx
		mov	fvertexBy,eax	    ; (+148)
		add	eax,ebx
		mov	fvertexCx,eax	    ; (+152)
		add	eax,ebx
		mov	fvertexCy,eax	    ; (+156)
		add	eax,ebx
		mov	fstartR,eax	    ; (+160)
		add	eax,ebx
		mov	fstartG,eax	    ; (+164)
		add	eax,ebx
		mov	fstartB,eax	    ; (+168)
		add	eax,ebx
		mov	fstartZ,eax	    ; (+172)
		add	eax,ebx
		mov	fstartA,eax	    ; (+176)
		add	eax,ebx
		mov	fstartS,eax	    ; (+180)
		add	eax,ebx
		mov	fstartT,eax	    ; (+184)
		add	eax,ebx
		mov	fstartW,eax	    ; (+188)
		add	eax,ebx
		mov	fdRdX,eax	    ; (+192)
		add	eax,ebx
		mov	fdGdX,eax	    ; (+196)
		add	eax,ebx
		mov	fdBdX,eax	    ; (+200)
		add	eax,ebx
		mov	fdZdX,eax	    ; (+204)
		add	eax,ebx
		mov	fdAdX,eax	    ; (+208)
		add	eax,ebx
		mov	fdSdX,eax	    ; (+212)
		add	eax,ebx
		mov	fdTdX,eax	    ; (+216)
		add	eax,ebx
		mov	fdWdX,eax	    ; (+220)
		add	eax,ebx
		mov	fdRdY,eax	    ; (+224)
		add	eax,ebx
		mov	fdGdY,eax	    ; (+228)
		add	eax,ebx
		mov	fdBdY,eax	    ; (+232)
		add	eax,ebx
		mov	fdZdY,eax	    ; (+236)
		add	eax,ebx
		mov	fdAdY,eax	    ; (+240)
		add	eax,ebx
		mov	fdSdY,eax	    ; (+244)
		add	eax,ebx
		mov	fdTdY,eax	    ; (+248)
		add	eax,ebx
		mov	fdWdY,eax	    ; (+252)
		add	eax,ebx
		mov	ftriangleCMD,eax    ; (+256)
		add	eax,ebx
		mov	fbzColorPath,eax    ; (+260)
		add	eax,ebx
		mov	fogMode,eax	    ; (+264)
		add	eax,ebx
		mov	alphaMode,eax	    ; (+268)
		add	eax,ebx
		mov	fbzMode,eax	    ; (+272)
		add	eax,ebx
		mov	lfbMode,eax	    ; (+276)
		add	eax,ebx
		mov	clipLeftRight,eax   ; (+280)
		add	eax,ebx
		mov	clipTopBottom,eax   ; (+284)
		add	eax,ebx
		mov	nopCMD,eax	    ; (+288)
		add	eax,ebx
		mov	fastfillCMD,eax     ; (+292)
		add	eax,ebx
		mov	swapbufferCMD,eax   ; (+296)
		add	eax,ebx
		mov	fogColor,eax	    ; (+300)
		add	eax,ebx
		mov	zaColor,eax	    ; (+304)
		add	eax,ebx
		mov	chromaKey,eax	    ; (+308)
		add	eax,ebx
		mov	chromaRange,eax     ; (+312)
		add	eax,ebx
		mov	userIntrCMD,eax     ; (+316)
		add	eax,ebx
		mov	stipple,eax	    ; (+320)
		add	eax,ebx
		mov	color0,eax	    ; (+324)
		add	eax,ebx
		mov	color1,eax	    ; (+328)
		add	eax,ebx
		mov	fbiPixelsIn,eax     ; (+332)
		add	eax,ebx
		mov	fbiChromaFail,eax   ; (+336)
		add	eax,ebx
		mov	fbiZfuncFail,eax    ; (+340)
		add	eax,ebx
		mov	fbiAfuncFail,eax    ; (+344)
		add	eax,ebx
		mov	fbiPixelsOut,eax    ; (+348)
		add	eax,ebx
		mov	fogTable,eax	    ; 32 dup (0) ;(+352) to (+476)
		add	eax,32*4
		mov	reserved_480,eax    ; 3 dup (0) ; (+480) to (+488)
		add	eax,3*4
		mov	colBufferAddr,eax   ; (+492)
		add	eax,ebx
		mov	colBufferStride,eax ; (+496)
		add	eax,ebx
		mov	auxBufferAddr,eax   ; (+500)
		add	eax,ebx
		mov	auxBufferStride,eax ; (+504)
		add	eax,ebx
		mov	reserved_508,eax    ; (+508)
		add	eax,ebx
		mov	clipLeftRight1,eax  ; (+512)
		add	eax,ebx
		mov	clipTopBottom1,eax  ; (+516)
		add	eax,ebx
		mov	reserved_520,eax    ; 17 dup (0) ;(+520) to (+584)
		add	eax,17*4
		mov	swapPending,eax     ; (+588)
		add	eax,ebx
		mov	leftOverlayBuf,eax  ; (+592)
		add	eax,ebx
		mov	rightOverlayBuf,eax ; (+596)
		add	eax,ebx
		mov	fbiSwapHistory,eax  ; (+600)
		add	eax,ebx
		mov	fbiTrianglesOut,eax ; (+604)
		add	eax,ebx
		mov	sSetupMode,eax	    ; (+608)
		add	eax,ebx
		mov	sVx,eax 	    ; (+612)
		add	eax,ebx
		mov	sVy,eax 	    ; (+616)
		add	eax,ebx
		mov	sARGB,eax	    ; (+620)
		add	eax,ebx
		mov	sRed,eax	    ; (+624)
		add	eax,ebx
		mov	sGreen,eax	    ; (+628)
		add	eax,ebx
		mov	sBlue,eax	    ; (+632)
		add	eax,ebx
		mov	sAlpha,eax	    ; (+636)
		add	eax,ebx
		mov	sVz,eax 	    ; (+640)
		add	eax,ebx
		mov	sWb,eax 	    ; (+644)
		add	eax,ebx
		mov	sWtmu0,eax	    ; (+648)
		add	eax,ebx
		mov	sS_W0,eax	    ; (+652) sS/W0
		add	eax,ebx
		mov	sT_W0,eax	    ; (+656) sT/W0
		add	eax,ebx
		mov	sWtmu1,eax	    ; (+660)
		add	eax,ebx
		mov	sS_Wtmu1,eax	    ; (+664) sS/Wtmu1
		add	eax,ebx
		mov	sT_Wtmu1,eax	    ; (+668) sT/Wtmu1
		add	eax,ebx
		mov	sDrawTriCMD,eax     ; (+672)
		add	eax,ebx
		mov	sBeginTriCMD,eax    ; (+676)
		add	eax,ebx
		mov	reserved_680,eax    ; 22 dup (0) ;(+680) to (+764)
		add	eax,22*4
		mov	textureMode,eax     ; (+768)
		add	eax,ebx
		mov	tLOD,eax	    ; (+772)
		add	eax,ebx
		mov	tDetail,eax	    ; (+776)
		add	eax,ebx
		mov	texBaseAddr,eax     ; (+780)
		add	eax,ebx
		mov	texBaseAddr_1,eax   ; (+784)
		add	eax,ebx
		mov	texBaseAddr_2,eax   ; (+788)
		add	eax,ebx
		mov	texBaseAddr_3_8,eax ; (+792)
		add	eax,ebx
		mov	texStride,eax	    ; (+796)
		add	eax,ebx
		mov	trexInit1,eax	    ; (+800)
		add	eax,ebx
		mov	nccTable0,eax	    ; 12 dup (0) ;(+804) to (+848)
		add	eax,12*4
		mov	nccTable1,eax	    ; 12 dup (0) ;(+852) to (+896)
		add	eax,12*4
		mov	reserved_900,eax    ; 31 dup (0) ;(+900) to (+1020)


		RET
set_all_3d_reg_addr ENDP


;=====================================================================


;---------------------------------------------------------------------

conv_int	dw	0
conv_real	real4	0.0

;---------------------------------------

conv_ax_real	PROC	near	; convert integer in ax to
				;   real in eax (need coproc)

						; Pentium clocks:
		mov	conv_int,ax	    ; 1
		fild	conv_int	    ; 3/1 (latency/throug)
		fstp	conv_real	    ; 2

		mov	eax,conv_real	    ; 1

		RET
conv_ax_real	ENDP

;---------------------------------------------------------------------

		END	START
