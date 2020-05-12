;---------------------------------------------------------------------
;		_3dsr.inc		20:03:55  26-Aug-2003
;
;				read a .3ds file
;					defined in "filename_read"
;				    aux. proc`s are in _general.inc
;---------------------------------------------------------------------
					    ; xxx first tests
					    ; .3ds  data viewer
					    ;	 (2) graphic view
					    ; for CauseWay Extender
;---------------------------------------------------------------------

		.DATA

;---------------------------------------------------------------------

curpa		db	    0

;page_start_addr dd	     0ba000h	 ; page 2
page_start_addr dd	    0b8000h	; page 0

;---------------------------------------------------------------------

curx		dw	0
cury		dw	0

;color		 db	 255,010,000	      ; r,g,b	 (for spix)
color		db	127,127,127	     ; r,g,b	(for spix)

;---------------------------------------------------------------------

strg_title	db	    "_3dsr.inc",0

;---------------------------------------------------------------------

msg_open_err	db	    "open error",0

msg_size_err	db	    "get file size error",0

msg_alloc_r_err db	    "mem alloc for read buffer failed",0

msg_read_err	db	    "file read error",0

msg_no_3ds_file db	    "seems not to be a .3ds 3D object file",0

msg_no_editor_chunk db	    "3D Editor chunk not found",0

;---------------------------------------------------------------------

filehandle_read dw	    0

filesize_read	dd	    0	; size of read buffer

read_buffer_start dd	    0	; start address of readbuffer

cur_read_ptr	dd	    0	    ; tmp in proc sort f. read buffer

cur_sort_ptr	dd	    0	    ; tmp in proc sort f. sort buffer

;---------------------------------------------------------------------

		.CODE

;---------------------------------------------------------------------

	       ;finit			    ; needed for intel cpu ?

	       ;call	main_3ds_text
				; load,setup,display(text)+get vars

;---------------------------------------------------------------------

		;scale+create pointlist_w (words,world coords.)
		; from pointlist (real4)

	       ;call	sc_cr_pointlist_w   ; -> pointlist_w_ptr

;---------------------------------------------------------------------


;=====================================================================
;---------------------------------------------------------------------

biggest_abs	dd	0	; tmp, biggest absolute value

max_pixel_size	dd	200	; max pixels in 1 direction

msg_alloc_l_err db	"pointlist_w : mem alloc error",0

pointlist_w_ptr dd	0	; ptr to pointlist word coords

;-----------------------------------

sc_cr_pointlist_w PROC	near	; scale+create pointlist_w
				; (words,world coords.)
				; from pointlist (real4)

;--------------- alloc memory for list -----

		mov	ax,0ff11h	    ; GetMemLinear32
		movzx	ecx,nr_of_points    ; x
		add	cx,nr_of_points     ; y
		add	cx,nr_of_points     ; z (max.21k points)
		shl	ecx,1		    ; to word size
		int	31h
		jnc	alloc_l_ok
		mov	edi,offset msg_alloc_l_err
		call	out_msg_edi
		call	prg_exit
    alloc_l_ok:
		mov	pointlist_w_ptr,esi

;-----------------------------------

		;scan size
		    ;biggest x/y +- ; abs,absolutwert
				    ; dx:ax  and dx,7fffh

		mov	esi,pointlist_ptr
		movzx	ecx,nr_of_points	; no zero protection
		add	cx,nr_of_points     ; +y
		add	cx,nr_of_points     ; +z
		mov	biggest_abs,0	    ; init
    @@again:
		mov	eax,dword ptr [esi]
		and	eax,7fffffffh	; abs (remove sign, if any)
		cmp	biggest_abs,eax
		jae	@@bigger
		mov	biggest_abs,eax
    @@bigger:
		add	esi,4		    ; to next
		loop	@@again

		mov	eax,biggest_abs


		    ;biggest=200(pixels),scale

;-----------------------------------

		;scale + write
		    ; real to word (ftoi)

		fild	max_pixel_size
		fld	biggest_abs
		fdiv			; max : biggest_abs = factor

		movzx	ecx,nr_of_points     ; x
		add	cx,nr_of_points     ; y
		add	cx,nr_of_points     ; z

		mov	esi,pointlist_ptr	; source real 4
		mov	edi,pointlist_w_ptr	; desti. word
    @@cagain:
		fld	dword ptr [esi] 	; load
		fmul	st,st(1)		; * factor
		fistp	word ptr [edi]		; store word + pop

		add	esi,4
		add	edi,2

		loop	@@cagain

		mov	edi,pointlist_w_ptr	; desti. word


		RET
sc_cr_pointlist_w ENDP

;=====================================================================
;---------------------------------------------------------------------

main_3ds_text	PROC	near	;

;-------------- chk 3ds signature ------------------

		call	load_3ds	; -> read_buffer_start

		mov	edi,read_buffer_start
		cmp	word ptr [edi],4d4dh	; 3ds signature
		je	is3dsfile
		mov	edi,offset msg_no_3ds_file
		call	out_msg_edi
		call	crlf
		call	prg_exit

    is3dsfile:					    ; assume fix
		cmp	word ptr [edi+16],3d3dh ;   position
		je	edchunkfound
		mov	edi,offset msg_no_editor_chunk
		call	out_msg_edi
		call	crlf
		call	prg_exit

    edchunkfound:

;---------------------------------------------------

		call	setup_screen	    ; text

;---------------------------------------------------

		call	display_3ds ; text
				    ; + get nr_of_points (vertices)
				    ;	    pointlist_ptr
				    ;	    nr_of_faces
				    ;	    facelist_ptr


		RET
main_3ds_text	ENDP

;---------------------------------------------------------------------

msg_4d4d_bytes	db	"Bytes in the main (4d4d) chunk. "
		db	" (len=16) ",0
msg_3ds_version db	"3DS-Version: ",0

msg_3d3d_bytes	db	"Bytes in the editor- (3d3d) chunk. ",0

msg_b000_bytes	db	"Bytes in the Keyframer- (B000) chunk. ",0

msg_no_kfr	db	"no Keyframer chunk",0

msg_sub_id	db	"sub-chunk ID: ",0
msg_sub_size	db	"sub-chunk size: ",0


;---------------------------

_4d4d_size	dd	0	; main chunk size
version 	dd	0	;
_3d3d_size	dd	0	; 3d editor chunk size

_3d3d_start_addr    dd	0	; start address of 3d editor chunk

;---------------------------

chunk_start_addr    dd	0	;
chunk_size	    dd	0	;
chunk_offset_ptr    dd	0	; position in current chunk

;---------------------------

bytes_remain_lvl1   dd	0	; remaining bytes in level 1
bytes_remain_lvl2   dd	0	; remaining bytes in level 2
bytes_remain_lvl3   dd	0	; remaining bytes in level 3
bytes_remain_lvl4   dd	0	; remaining bytes in level 4
bytes_remain_lvl5   dd	0	; remaining bytes in level 5

cur_id		dw	0	; tmp, current id


;---------------------------------------------------------------------

display_3ds	PROC	near	; 4d4d + 3d3d chunk found
				; assume 3d3d is always at +16
				;   (=always subchunk 2)

		mov	edi,read_buffer_start

		mov	eax,dword ptr [edi+2]
		mov	_4d4d_size,eax
		call	wr_eax_dec
		call	space
		mov	esi,offset msg_4d4d_bytes
		call	out_msg_esi
		call	two_space

		mov	version,0
		cmp	word ptr [edi+6],2	; sub chunk id ?
		jne	d3ds_nosub2
		mov	esi,offset msg_3ds_version
		call	out_msg_esi
		mov	eax,dword ptr [edi+12]
		mov	version,eax
		add	al,30h
		call	writt_al
		call	two_space

    d3ds_nosub2:
		call	crlf
		mov	eax,dword ptr [edi+18]	; assume: fix pos.
		mov	_3d3d_size,eax
		mov	chunk_size,eax		; tmp
		call	wr_eax_dec
		call	space
		mov	esi,offset msg_3d3d_bytes
		call	out_msg_esi
		call	crlf

;------- go to keyframer -------

		mov	eax,_4d4d_size
		sub	eax,16		; assumed size of 4d4d ch.
		sub	eax,_3d3d_size
		jnz	is_kfr
		mov	esi,offset msg_no_kfr	; no keyframer
		call	out_msg_esi
		jmp	kfr_end
    is_kfr:
		add	edi,16		    ; to 3d3d chunk
		add	edi,_3d3d_size	    ; to next chunk
		mov	ax,word ptr [edi]	; should be B000h
	       ;call	wr_4_hex
		mov	eax,dword ptr [edi+2]  ; len of keyframer
		call	wr_eax_dec
		call	space
		mov	esi,offset msg_b000_bytes
		call	out_msg_esi
		call	crlf
    kfr_end:

		call	crlf

;-------------------------------

		mov	edi,read_buffer_start	; reset edi

		mov	ax,word ptr [edi]	; ID
		call	wr_4_hex
		call	four_space
		mov	eax,dword ptr [edi+2]	; len
		call	wr_eax_dec
		call	four_space
		add	edi,6			; +ID+len

		cmp	word ptr [edi],2	; ID sub "version"
		jne	novers

		call	crlf
		call	two_space
		mov	ax,word ptr [edi]	; ID
		call	wr_4_hex
		call	four_space
		mov	eax,dword ptr [edi+2]	; len
		call	wr_eax_dec
		add	edi,eax 		; to next

    novers:
		call	crlf
		mov	ax,word ptr [edi]	; ID
		mov	cur_id,ax
		call	wr_4_hex
		call	four_space
		mov	eax,dword ptr [edi+2]	; len
		mov	bytes_remain_lvl1,eax
		sub	bytes_remain_lvl1,6	; (-ID-len)
		call	wr_eax_dec
		add	edi,6			; +ID+len
		call	crlf

    parsechunkagain:
		cmp	bytes_remain_lvl1,0	     ; end ?
		je	chunk_finished

		call	two_space
		mov	ax,word ptr [edi]	; ID
		mov	cur_id,ax
		call	wr_4_hex
		call	four_space
		mov	eax,dword ptr [edi+2]	; len
		call	wr_eax_dec

		cmp	cur_id,4000h	    ; object block ?
		jne	pchunkeiter1
		call	display_ch_4000 	; level 2
    pchunkeiter1:

		call	crlf
		sub	bytes_remain_lvl1,eax	; last eax !!
		add	edi,eax 	    ; go to next id

		mov	ah,0
		int	16h
		jmp	parsechunkagain

    chunk_finished:

		mov	al,"-"
		call	writt_al
		call	writt_al
		call	crlf

		RET			; xxx debug

;-------------------------------

	; need: 4d4d		    main chunk		level 0
	;	  3d3d		    3d editor chunk	level 1
	;	    4000	    object block	level 2
	;	      4100	    triangular mesh	level 3
	;		4110	    vertices list	level 4
	;		4120	    faces description	level 4


		RET
display_3ds	ENDP

;---------------------------------------------------------------------

display_ch_4000 PROC	near	; called from display_3ds
				;   edi points to ID
				;	level = 2
		push	eax
		push	edi

		mov	eax,dword ptr [edi+2]	    ; len
		mov	bytes_remain_lvl2,eax
		sub	bytes_remain_lvl2,6	; (-ID-len)

		call	four_space

		add	edi,6		; point to data

    dspch4000again:
		sub	bytes_remain_lvl2,1
		mov	al,byte ptr [edi]
		cmp	al,0
		je	dspch4000end
		call	writt_al	; wr name string
		add	edi,1
		jmp	dspch4000again

    dspch4000end:
		call	crlf
		call	four_space

;------- sub chunk ---------		    ; level = 3

		add	edi,1

		mov	ax,word ptr [edi]	; ID
		call	wr_4_hex
		call	four_space

		mov	eax,dword ptr [edi+2]	; len
		mov	bytes_remain_lvl3,eax
		sub	bytes_remain_lvl3,6	; (-ID-len)

		call	wr_eax_dec

;-------------------
;can have: no(?),
;	   4100     triangular mesh (var.)
;	   4600     light   (var.)
;	   4700     camera (size=32)
;	   4710(?),4720(?)

		cmp	ax,4100

;---------------------------

		call	crlf

		add	edi,6		    ; to sub chunk
						; level = 4
    dsplch4000_again1:

		call	displ_lvl_4

		cmp	bytes_remain_lvl3,0
		je	dsplch4000_end1

		mov	eax,dword ptr [edi+2]	; len
		add	edi,eax 		; to next

		jmp	dsplch4000_again1

    dsplch4000_end1:


;---------------------------

		pop	edi
		pop	eax

		RET
display_ch_4000 ENDP

;---------------------------------------------------------------------

displ_lvl_4	PROC	near	    ; called from display_ch_4000
				    ; edi points to ID

		push	edi

		call	four_space
		call	two_space

		mov	ax,word ptr [edi]	; ID
		call	wr_4_hex		; wr ID
		call	four_space

		mov	eax,dword ptr [edi+2]	; len
		mov	bytes_remain_lvl4,eax
		sub	bytes_remain_lvl4,6	; (-ID-len)
		sub	bytes_remain_lvl3,eax

		call	wr_eax_dec		; wr len
		call	four_space

		cmp	word ptr [edi],4110h	; ID = VertexL ?
		jne	dsplvl4_no4110
		call	displ_4110h
    dsplvl4_no4110:
		cmp	word ptr [edi],4120h	; ID = FaceL ?
		jne	dsplvl4_no4120
		call	displ_4120h
    dsplvl4_no4120:


		call	crlf

		pop	edi

		RET
displ_lvl_4	ENDP

;---------------------------------------------------------------------

nr_of_vertices	dw	0		; = nr_of_points
nr_of_points	dw	0		; = nr_of_vertices
pointlist_ptr	dd	0		; ptr to pointlist (vertices)
					;	(float, 4-byte real)
msg_vertices	db	"vertices",0

;-------------------------------

displ_4110h	PROC	near		; do not change edi !

		push	edi

;--header---
		mov	eax,0
		mov	ax,word ptr [edi+6]	; nr. of vertices
		cmp	ax,0
		je	@@nostore		; do not store 0
		mov	nr_of_vertices,ax
		mov	nr_of_points,ax 	; "vertices"="points"
    @@nostore:
		call	wr_eax_dec		; wr nr of vertices

		call	space

		mov	esi,offset msg_vertices
		call	out_msg_esi

		call	four_space

		mov	ah,0
		int	16h

;--vertices-
		cmp	word ptr [edi+6],0     ; nr. of vertices
		je	dspl4110end	 ; ignore chunks w. 0 vertices

		add	edi,8		; to first vertex
		mov	pointlist_ptr,edi   ; save ptr

		mov	cx,nr_of_vertices
    dspl4110again:
		mov	eax,dword ptr [edi]	; x
		call	wr_float
		call	four_space
		mov	eax,dword ptr [edi+4]	; y
		call	wr_float
		call	four_space
		mov	eax,dword ptr [edi+8]	; z
		call	wr_float
		add	edi,12
		call	crlf
		call	four_space
		call	four_space
		loop	dspl4110again

    dspl4110end:

		pop	edi

		RET
displ_4110h	ENDP

;---------------------------------------------------------------------

nr_of_faces	dw	0
facelist_ptr	dd	0		; ptr to facelist (words)
msg_faces	db	"faces",0

;-------------------------------

displ_4120h	PROC	near		; do not change edi !

		push	edi

;--header---

		mov	eax,0
		mov	ax,word ptr [edi+6]	; nr. of faces
		cmp	ax,0
		je	@@nostore		; do not store 0
		mov	nr_of_faces,ax
    @@nostore:
		call	wr_eax_dec		; wr nr of faces

		call	space

		mov	    esi,offset msg_faces
		call	    out_msg_esi

		call	four_space

		mov	ah,0
		int	16h		    ; wait for key

;--faces----
		cmp	word ptr [edi+6],0     ; nr. of faces
		je	dspl4120end	; ignore chunk w. 0 faces

		add	edi,8		; to first face
		mov	facelist_ptr,edi    ; save ptr

		mov	cx,nr_of_faces
		mov	eax,0
    dspl4120again:
		mov	ax,word ptr [edi]     ; num of vertex A
		call	wr_eax_dec
		call	four_space
		mov	ax,word ptr [edi+2]   ; num of vertex B
		call	wr_eax_dec
		call	four_space
		mov	ax,word ptr [edi+4]   ; num of vertex C
		call	wr_eax_dec
		call	four_space
		mov	al,"("
		call	writt_al
		mov	ax,word ptr [edi+6]   ; face info
		call	wr_eax_dec
		mov	al,")"
		call	writt_al

		add	edi,8			; 4*2 bytes
		call	crlf
		call	four_space
		call	four_space
		loop	dspl4120again

    dspl4120end:

		pop	edi

		RET
displ_4120h	ENDP

;---------------------------------------------------------------------

setup_screen	PROC	    near

		mov	    ah,5
		mov	    al,curpa
		int	    10h 	    ; setpage 2

;-----------------------------------

		mov	    ah,2
		mov	    bh,curpa	    ; curpa
		mov	    dl,0	    ; pos_x
		mov	    dh,0	    ; pos_y
		int	    10h 	    ; set_cursor

;------- clear screen --------------

		mov	    edi,page_start_addr     ; page
		mov	    ecx,2000
    clsagain:
		mov	    byte ptr gs:[edi],20h   ; char.
		mov	    byte ptr gs:[edi+1],7   ; attrib.
		add	    edi,2

		loop	    clsagain

;------- wr title ------------------

		mov	    edi,offset strg_title   ; title string
		call	    out_msg_edi

;------- wr filename ---------------

		call	    four_space
		mov	    edi,offset filename_read
		call	    out_msg_edi

		call	    crlf
		call	    crlf

		RET
setup_screen	ENDP

;---------------------------------------------------------------------

load_3ds	PROC	    near

;--------------- open file -----

		mov	    edx,offset filename_read
		mov	    al,0	    ; read access
		mov	    ah,3dh
		int	    21h 	    ; open file
		jnc	    open_ok
		mov	    edi,offset msg_open_err ; error code in al
		call	    out_msg_edi
		call	    prg_abort
    open_ok:
		mov	    filehandle_read,ax	     ; insert handle

;--------------- get file size -

			    ; CX:DX  ->  DX:AX

		mov	    ah,42h	    ; f. move file ptr.
		mov	    al,2	    ; method (end)
		mov	    bx,filehandle_read
		mov	    ecx,0
		mov	    edx,0
		int	    21h
		jnc	    gefilsizok
		mov	    edi,offset msg_size_err
		call	    out_msg_edi
		call	    prg_abort
    gefilsizok:

		mov	    bx,dx		; dx:
		shl	    ebx,16
		mov	    bx,ax		; ax
		mov	    filesize_read,ebx

;-------reset ptr-pos to start--

		mov	    ah,42h	    ; dos_f  move_file_ptr
		mov	    al,0	    ; set ptr to start of file
		mov	    bx,filehandle_read	    ; handle
		mov	    cx,0		    ; no offset
		mov	    dx,0		    ; no offset
		int	    21h


;--------------- alloc memory for read -----

		mov	    ax,0ff11h		; GetMemLinear32
		mov	    ecx,filesize_read
		or	    ecx,0fh
		add	    ecx,1		; round up
		int	    31h
		jnc	    alloc_r_ok
		mov	    edi,offset msg_alloc_r_err
		call	    out_msg_edi
		call	    prg_abort
    alloc_r_ok:
		mov	    read_buffer_start,esi

;--------------- read the file -----

;BX	- Handle
;ECX	- Length
;EDI	- Position.

		mov	    bx,filehandle_read
		mov	    ecx,filesize_read
		mov	    edi,read_buffer_start

		call	    read_file

		jnc	    read_file_ok
		mov	    edi,offset msg_read_err
		call	    out_msg_edi
		call	    prg_abort

    read_file_ok:

;--------------- close the file ----

		mov	    ah,3eh	    ;close file function.
		mov	    bx,filehandle_read
		int	    21h
		jnc	    close_ok
		nop
    close_ok:
		nop



		RET
load_3ds	ENDP


;---------------------------------------------------------------------

;---------------------------------------------------------------------
;		end of _3dsr.inc
;---------------------------------------------------------------------
