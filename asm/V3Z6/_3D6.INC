;---------------------------------------------------------------------
;		_3d6.inc		20:03:17  16-Aug-2003
;
;		    6. version,
;				screen_xyz_ptr -> screen_xyzc_ptr
;				    (size= nr_of_points *6 -> *10)
;				    c = color = +6 = dd = ARGB
;
;				in CalcSxSy: Dist is now 512
;
;		    5. version,
;				vertex normals instead of face normals
;				(for smooth sh.)
;			    + _RotateVtxNormals
;				vertex_normals -> rot.vertex_normals
;
;---------------------------------------------------------------------
;
;   written by daniel hagmann
;	    based on rot.asm
;	    written by Abe of space (from abe`s demoschool IV)
;
;	masm 6.0
;
;---------------------------------------------------------------------

		.CODE

;---------------------------------------------------------------------
; in this (5.) version the following is expected:
;   (in:)
;   nr_of_points    dw	number of points (vertices) the object have
;
;   (in:)
;   pointlist_w_ptr dd	to array of base points in world coords
;				dw x,y,z,...	     (never changed)
;   (out:)
;   rotated_xyz_ptr dd	to an array of rotated points from proc
;				_RotatePoints	dw x,y,z,...
;   (out:)
;   screen_xyzc_ptr dd	to an array of projected points in screen
;			coords (CalcSxSy)   dw x,y,z  db a,r,g,b ,...
;						(z,a,r,g,b unchanged)
;
;   depending on:
;   rotx, roty, rotz (rotation angle from base, 256 = 1 turn)
;   addx, addy, addz   displacement (from mid screen)
;
;   call with:
;   call    _RotatePoints
;
;---------------------------------------------------------------------

; ROT.ASM contains one function, _RotatePoints, that can be called
; from C.
; To do this, the C program must have some global variables
; these variables are defined as extrn here in the asm source.
; They are _bx, _by, _bz that should contain the coordinates of the
; object to be rotated. They are never changed instead the rotated
; coordinates are stored in _rx, _ry, _rz. _sx and _sy will contain
; the screen coordinates.
; addx, addy, addz are the distance the object will be moved in
; the x,y,z direction. If they are 0 the object will appear at the
; center of the screen.
; ROT.ASM also contains two local routines that are called from
; _RotatePoints.


; EXTRN   _bx,_by,_bz,_rx,_ry,_rz,_sx,_sy ;extrn variables & arrays
; EXTRN   _addx, _addy, _addz	  ;must be defined elsewhere (in c)

	sinax	dw	?	; the sin & cos variables are only
	sinay	dw	?	; used here, in the asm source
	sinaz	dw	?
	cosax	dw	?
	cosay	dw	?
	cosaz	dw	?

;	HALFX	EQU	 320/2	  ; Constants
;	HALFY	EQU	 200/2

	HALFX	EQU	 640/2	  ; Constants (screen-x-res /2)
	HALFY	EQU	 480/2	  ; Constants (screen-y-res /2)


;---------------------------------------------------------------------

;	PUBLIC	_RotatePoints	;this function can be called from C
;	PUBLIC	_qsort3d	;sorts sx & sy in "rz-order"

;---------------------------------------------------------------------


num_of_pts dw	3		; here 3 = only a single triangle !

_bx	dw	0,0,0			       ; base object
_by	dw	0,0,0			       ; (from mid screen)
_bz	dw	000,000,000	    ; assume: 0 for z ..?

_rx	dw	0,0,0	    ; used by rotatepoints
_ry	dw	0,0,0	    ; [NO_OF_PTS]
_rz	dw	0,0,0

_sx	dw	0,0,0	    ; used by rotatepoints
_sy	dw	0,0,0	    ; [NO_OF_PTS]

addx	dw	000	    ; object move   input
addy	dw	000
addz	dw	000

rotx	db	000	    ; rotation	 input	    256 = 1 turn
roty	db	000
rotz	db	000

;-----------------------

_es	dw	0	    ; tmp var.

;---------------------------------------------------------------------

; _RotatePoints rotates NUM_OF_PTS points in (_bx,_by,_bz)
;		    xxx nr_of_points in pointlist_w_ptr array
;					   (rotx,roty,rotz) degrees,
; adds addx,addy,addz to the coordinates, stores them in _rx, _ry & _rz
;		    xxx stores them in rotated_xyz_ptr array
; and finally calculates the screen coordinates and stores them in
;							   _sx and _sy.
;		    xxx stores them in screen_xyzc_ptr array
;
;*********** Call from c with: ***************
;*** RotatePoints(ax, ay, az, num_of_pts); ***
;*********************************************

;---------------------------------------------------------------------

_RotatePoints	PROC	near
 ;	ARG rotx:Byte, roty:Byte, rotz:Byte, num_of_pts:Word


	push	bp	    ; this bp,sp trick must be here if
	mov	bp,sp	    ; you use arguments
			    ;  (has to do with the stackframe)
	pushad		    ; save all registers

	mov	ebx,0	    ; debug
	mov	edi,0	    ; init

;--- precalc sin/cos ---------------

	mov	bl,rotx
	xor	bh,bh
	shl	bx,1		;bx = index in sintab and costab
	mov	ax,sintab [bx] ;move the appropriate value from the sintab
	mov	sinax,ax       ; to sinax
	mov	ax,costab [bx] ; and the appropriate value from costab
	mov	cosax,ax       ; to cosax
	mov	bl,roty       ; do the same with sinay & cosay
	xor	bh,bh
	shl	bx,1
	mov	ax,sintab [bx]
	mov	sinay,ax
	mov	ax,costab [bx]
	mov	cosay,ax
	mov	bl,rotz       ; and sinaz & cosaz
	xor	bh,bh
	shl	bx,1
	mov	ax,sintab [bx]
	mov	sinaz,ax
	mov	ax,costab [bx]
	mov	cosaz,ax

;--- rotate main -------------------

	mov	esi,pointlist_w_ptr	; source x,y,z array
	mov	edi,rotated_xyz_ptr	; destination x,y,z array
	mov	cx,nr_of_points
@@rotloop1:		    ; rot pointlist array to rotated array
	push	cx

	mov	bx,word ptr [esi]   ; x  load cordinates to rotate
	mov	cx,word ptr [esi+2] ; y     (from pointlist array)
	mov	bp,word ptr [esi+4] ; z

	push	edi
	call	RotPoint	;rotate the coordinates of one point
	pop	edi

	add	bx,addx       ; add "movement" to the rotated coordinates
	add	cx,addy
	add	bp,addz

	mov	word ptr [edi],bx     ; x  save rotated coordintates in
	mov	word ptr [edi+2],cx   ; y   rotated array
	mov	word ptr [edi+4],bp   ; z

	add	esi,6
	add	edi,6

	pop	cx
	loopw	@@rotloop1

;-------

	mov	esi,rotated_xyz_ptr	; source x,y,z array
	mov	edi,screen_xyzc_ptr	; destination x,y,z,c array
	mov	cx,nr_of_points
@@rotloop2:	    ; project rotated array to screen_xyzc array
	push	cx

	mov	bx,word ptr [esi]	; x in
	mov	cx,word ptr [esi+2]	; y in
	mov	bp,word ptr [esi+4]	; z in
	mov	word ptr [edi+4],bp	; store z unchanged

	    ;bx,cx,bp
	call	CalcSxSy	;calculate the screen coordinates
       ;call	CalcSxSy_2	; xxx debug DIST is variable

	mov	word ptr [edi],bx  ; and save them in screen_xyzc arr.
	mov	word ptr [edi+2],cx

	add	esi,6		; to next xyz (6)
	add	edi,10		; to next xyzc (10) (only x+y chngd.)

	pop	cx

	loopw	@@rotloop2

;-----------------------------------

	popad			;restore the saved registers
	pop	bp
	ret
_RotatePoints  ENDP



;RotPoint rotates one point using the precalculated values stored in
;sinax,sinay,sinaz,cosax,cosay and cosaz
;Destroys: ax,edx,si,edi,es
;Input:    bx= X cx= Y bp= Z
;Output:   bx= rotatedX cx= rotatedY bp= rotatedZ

RotPoint    PROC    near

			    ; Rotate point around the X-axis
			    ; ry = cos(angle x) * y - sin(angle x) * z
			    ; rz = sin(angle x) * y + cos(angle x) * z
	mov	ax,cosax    ; ax = cos(angle x)
	imul	cx	    ; dx:ax = cos(angle x) * y
	mov	di,dx	    ; dx:ax means that the high word of the mul.
	shl	edi,16	    ; is in dx and the low word in ax
	mov	di,ax	    ; edi = by * cos(angle x)
	mov	ax,sinax    ; ax = sin(angle x)
	imul	bp	    ; ax = sin(angle x) * z
	shl	edx,16
	mov	dx,ax	    ; edx = bz * sinax
	sub	edi,edx     ; edi=edi-edx= cos(angle x)*y - sin(angle x)*z
	sar	edi,14	    ; shift to the actual value (fixed point math)
       ;mov	es,di	    ; save rotated y in es
	mov	_es,di	    ; save rotated y in _es
	mov	ax,sinax    ; ax = sin(angle x)
	imul	cx	    ; dx:ax = sin(angle x) * y
	mov	di,dx
	shl	edi,16
	mov	di,ax	    ; edi = sin(angle x) * y
	mov	ax,cosax    ; ax = cos(angle x)
	imul	bp	    ; dx:ax = cos(angle x) * z
	shl	edx,16
	mov	dx,ax	    ; edx = cos(angle x) * z
	add	edi,edx     ; edi=edi+edx = sin(angle x)*y + cos(angle x)*z
	sar	edi,14	    ; shift right => di = actual value of rotated z
       ;mov	cx,es	    ; cx = ry (rotated y)
	mov	cx,_es	    ; cx = ry (rotated y)
	mov	bp,di	    ; bp = rz (rotated z)

			    ; Rotate point around the Y-axis
			    ; rx =  cos(angle y) * x + sin(angle y) * rz
			    ; rrz = -sin(angle y) * x + cos(angle y) * rz
	mov	ax,cosay    ; ax = cos(angle y)
	imul	bx	    ; dx:ax = cos(angle y) * x
	mov	di,dx
	shl	edi,16
	mov	di,ax	    ; edi = cos(angle y) * x
	mov	ax,sinay    ; ax = sin(angle y)
	imul	bp	    ; dx:ax = sin(angle y) * rz
	shl	edx,16
	mov	dx,ax	    ; edx = sin(angle y) * rz
	add	edi,edx     ; edi=edi+edx= cos(angle y)*x + sin(angle y)*rz
	sar	edi,14	    ; apply fixed point math
       ;mov	es,di	    ; save rx (rotated x) in es
	mov	_es,di	    ; save rx (rotated x) in _es
	mov	ax,sinay    ; ax = sin(angle y)
	neg	ax	    ; ax = -sin(angle y)
	imul	bx	    ; dx:ax = -sin(angle y) * x
	mov	di,dx
	shl	edi,16
	mov	di,ax	    ; edi = -sin(angle y) * x
	mov	ax,cosay    ; ax = cos(angle y)
	imul	bp	    ; dx:ax = cos(angle y) * rz
	shl	edx,16
	mov	dx,ax	    ; edx = cos(angle y) * rz
	add	edi,edx     ; edi=edi-edx=-sin(angle y)*x + cos(angle y)*rz
	sar	edi,14	    ; fp math, di = rrz (rotated rz)
       ;mov	bx,es	    ; bx = rx (rotated x)
	mov	bx,_es	    ; bx = rx (rotated x)
	mov	bp,di	    ; bp = rrz (rotated rotated z)

			    ; Rotate point around the Z-axis
			    ; rrx = cos(angle z) * rx - sin(angle z) * ry
			    ; rry = sin(angle z) * rx + cos(angle z) * ry
	mov	ax,cosaz    ; ax = cos(angle z)
	imul	bx	    ; dx:ax = cos(angle z) * rx
	mov	di,dx
	shl	edi,16
	mov	di,ax	    ; edi = cos(angle z) * rx
	mov	ax,sinaz    ; ax = sin(angle z)
	imul	cx	    ; dx:ax = sin(angle z) * ry
	shl	edx,16
	mov	dx,ax	    ; edx = sin(angle z) * ry
	sub	edi,edx     ; edi=edi-edx=cos(angle z)*rx - sin(angle z)*ry
	sar	edi,14	    ; shift right to actual value
       ;mov	es,di	    ; es = rrx
	mov	_es,di	    ; es = rrx
	mov	ax,sinaz    ; ax = sin(angle z)
	imul	bx	    ; dx:ax = sin(angle z) * rx
	mov	di,dx
	shl	edi,16
	mov	di,ax	    ; edi = sin(angle z) * rx
	mov	ax,cosaz    ; ax = cos(angle z)
	imul	cx	    ; dx:ax = cos(angle z) * ry
	shl	edx,16
	mov	dx,ax	    ; edx = cos(angle z) * ry
	add	edi,edx     ; edi=edi+edx=sin(angle z)*rx + cos(angle z)*ry
	sar	edi,14	    ; shift right to actual value
       ;mov	bx,es	    ; bx = rrx (rotated rx)
	mov	bx,_es	    ; bx = rrx (rotated rx)
	mov	cx,di	    ; cx = rry (rotated ry)

    ret
RotPoint ENDP


;CalcSxSy Calculates the Screen (x,y) coordinates using a perspective
;projection on the (x,y,z) coordinates. Screen distance is 256.
;CalcSxSy also adds half width of the screen to the sx coordinate and half
;height of the screen to the sy coordinate to make the coordinates
;centered around the center of the screen.
;Destroys: ax,dx,bp
;Input:    bx= X cx= Y bp= Z
;Output:   bx= SX, cx =SY


CalcSxSy    PROC    near    ; in original DIST = 256 because 320*200
			    ; here screen_x :5 *4  (* 0,8)

			    ; Perspective Projection:
			    ; SX = DIST * X / (DIST + Z)
			    ; SY = DIST * Y / (DIST + Z)
	movsx	eax,bx	    ; eax = x-coord. with Sign eXtension
	shl	eax,9	    ; eax = 256*x  (distance is 256)	<-- 8
	mov	edx,eax     ; edx = 256*x
	shr	edx,16	    ; dx:ax = 256*x (DIST * X)
	add	bp,512	    ; bp = DIST + Z			<-- 256
	idiv	bp	    ; quote of division => ax
	add	ax,HALFX    ; add ax with 320/2 (half width of screen)
	mov	bx,ax	    ; bx = 256*x / (256 + z) + 160

	movsx	eax,cx	    ; eax = y-coord. with Sign eXtension
	shl	eax,9	    ; eax = 256*y			<-- 8
	mov	edx,eax
	shr	edx,16	    ; dx:ax = 256*y (DIST * Y)
	idiv	bp	    ; divide with (DIST + Z)
	add	ax,HALFY    ; add result of division with half screen height
	mov	cx,ax	    ; cx = 256*y/(256 + z) + 100
	ret

CalcSxSy    ENDP

;---------------------------------------------------------------------

DIST	dw	512	    ; ( screen_x /4  ? ), or ( :5 *4 )

;-------------------------------

CalcSxSy_2  PROC    near    ; try to make DIST variable (xxx debug)
			    ; Input:	bx= X cx= Y bp= Z
			    ; Output:	bx= SX, cx =SY


			    ; Perspective Projection:
			    ; SX = DIST * X / (DIST + Z)
			    ; SY = DIST * Y / (DIST + Z)
	movsx	eax,bx	    ; eax = x-coord. with Sign eXtension
       ;shl	eax,7	    ; eax = 256*x  (distance is 256)	<-- 8
       ;mov	edx,eax     ; edx = 256*x
       ;shr	edx,16	    ; dx:ax = 256*x (DIST * X)
	imul	DIST

	add	bp,DIST     ; bp = DIST + Z			<-- 256
	idiv	bp	    ; quote of division => ax
	add	ax,HALFX    ; add ax with 320/2 (half width of screen)
	mov	bx,ax	    ; bx = 256*x / (256 + z) + 160

	movsx	eax,cx	    ; eax = y-coord. with Sign eXtension
       ;shl	eax,7	    ; eax = 256*y			<-- 8
       ;mov	edx,eax
       ;shr	edx,16	    ; dx:ax = 256*y (DIST * Y)
	imul	DIST

	idiv	bp	    ; divide with (DIST + Z)
	add	ax,HALFY    ; add result of division with half screen height
	mov	cx,ax	    ; cx = 256*y/(256 + z) + 100
	ret

CalcSxSy_2  ENDP

;=====================================================================

_RotateVtxNormals PROC near ; new in version _3dv5.inc
			    ; assume that _RotatePoints was called
			    ; before so sinax,y,z cosax,y,z are valid

	pushad		    ; save all registers

	mov	ebx,0	    ; debug
	mov	edi,0	    ; init


;--- rotate main -------------------

	mov	esi,vertex_normals_ptr	; source x,y,z array
	mov	edi,rotated_vertex_normals_ptr
					; destination x,y,z array
	mov	cx,nr_of_points
@@nrotloop:		    ; rot normals array to rotated array
	push	cx

	mov	bx,word ptr [esi]   ; x  load cordinates to rotate
	mov	cx,word ptr [esi+2] ; y     (from pointlist array)
	mov	bp,word ptr [esi+4] ; z

	push	edi
	call	RotPoint	;rotate the coordinates of one point
	pop	edi

	mov	word ptr [edi],bx     ; x  save rotated coordintates in
	mov	word ptr [edi+2],cx   ; y   rotated array
	mov	word ptr [edi+4],bp   ; z

	add	esi,6
	add	edi,6

	pop	cx
	loopw	@@nrotloop


	popad

	    RET
_RotateVtxNormals ENDP

;=====================================================================

_RotateNormals PROC near    ; new in version _3dv4.inc
			    ; assume that _RotatePoints was called
			    ; before so sinax,y,z cosax,y,z are valid

	pushad		    ; save all registers

	mov	ebx,0	    ; debug
	mov	edi,0	    ; init


;--- rotate main -------------------

	mov	esi,normals_ptr 	; source x,y,z array
	mov	edi,rotated_normals_ptr ; destination x,y,z array
	mov	cx,nr_of_faces
@@nrotloop:		    ; rot normals array to rotated array
	push	cx

	mov	bx,word ptr [esi]   ; x  load cordinates to rotate
	mov	cx,word ptr [esi+2] ; y     (from pointlist array)
	mov	bp,word ptr [esi+4] ; y

	push	edi
	call	RotPoint	;rotate the coordinates of one point
	pop	edi

       ;add	bx,addx       ; add "movement" to the rotated coordinates
       ;add	cx,addy
       ;add	bp,addz

	mov	word ptr [edi],bx     ; x  save rotated coordintates in
	mov	word ptr [edi+2],cx   ; y   rotated array
	mov	word ptr [edi+4],bp   ; z

	add	esi,6
	add	edi,6

	pop	cx
	loopw	@@nrotloop


	popad

	    RET
_RotateNormals ENDP

;=====================================================================
;---------------------------------------------------------------------

; This is the precalculated sin & cos table
; It's the sin & cos values of a 256 "degree" circle with each value
; multiplied by 2^14 (we use fixed point math with 14 bits shift).
; The cosine values are the same as (sinevalues + 90 degrees). 90 deg
; in a 360 deg circle is the same as 64 "deg" in a 256 "deg" circle.
; That means that after 64 values in sintab, the costab & sintab can
; share the same values

sintab	dw	0, 402, 804, 1205, 1606, 2006, 2404, 2801, 3196, 3590
	dw	3981, 4370, 4756, 5139, 5520, 5897
	dw	6270, 6639, 7005, 7366, 7723, 8076, 8423, 8765, 9102
	dw	9434, 9760, 10080, 10394, 10702, 11003, 11297
	dw	11585, 11866, 12140, 12406, 12665, 12916, 13160, 13395
	dw	13623, 13842, 14053, 14256, 14449, 14635, 14811, 14978
	dw	15137, 15286, 15426, 15557, 15679, 15791, 15893, 15986
	dw	16069, 16143, 16207, 16261, 16305, 16340, 16364, 16379
costab	dw	16384, 16379, 16364, 16340, 16305, 16261, 16207, 16143
	dw	16069, 15986, 15893, 15791, 15679, 15557, 15426, 15286
	dw	15137, 14978, 14811, 14635, 14449, 14256, 14053, 13842
	dw	13623, 13395, 13160, 12916, 12665, 12406, 12140, 11866
	dw	11585, 11297, 11003, 10702, 10394, 10080, 9760, 9434
	dw	9102, 8765, 8423, 8076, 7723, 7366, 7005, 6639
	dw	6270, 5897, 5520, 5139, 4756, 4370, 3981, 3590, 3196
	dw	2801, 2404, 2006, 1606, 1205, 804, 402
	dw	0, -402, -804, -1205, -1606, -2006, -2404, -2801
	dw	-3196, -3590, -3981, -4370, -4756, -5139, -5520, -5897
	dw	-6270, -6639, -7005, -7366, -7723, -8076, -8423, -8765
	dw	-9102, -9434, -9760, -10080, -10394, -10702, -11003
	dw	-11297
	dw	-11585, -11866, -12140, -12406, -12665, -12916, -13160
	dw	-13395, -13623, -13842, -14053, -14256, -14449, -14635
	dw	-14811, -14978
	dw	-15137, -15286, -15426, -15557, -15679, -15791, -15893
	dw	-15986, -16069, -16143, -16207, -16261, -16305, -16340
	dw	-16364, -16379
	dw	-16384, -16379, -16364, -16340, -16305, -16261, -16207
	dw	-16143, -16069, -15986, -15893, -15791, -15679, -15557
	dw	-15426, -15286
	dw	-15137, -14978, -14811, -14635, -14449, -14256, -14053
	dw	-13842, -13623, -13395, -13160, -12916, -12665, -12406
	dw	-12140, -11866
	dw	-11585, -11297, -11003, -10702, -10394, -10080, -9760
	dw	-9434, -9102, -8765, -8423, -8076, -7723, -7366, -7005
	dw	-6639
	dw	-6270, -5897, -5520, -5139, -4756, -4370, -3981, -3590
	dw	-3196, -2801, -2404, -2006, -1606, -1205, -804, -402
	dw	0, 402, 804, 1205, 1606, 2006, 2404, 2801, 3196, 3590
	dw	3981, 4370, 4756, 5139, 5520, 5897
	dw	6270, 6639, 7005, 7366, 7723, 8076, 8423, 8765, 9102
	dw	9434, 9760, 10080, 10394, 10702, 11003, 11297
	dw	11585, 11866, 12140, 12406, 12665, 12916, 13160, 13395
	dw	13623, 13842, 14053, 14256, 14449, 14635, 14811, 14978
	dw	15137, 15286, 15426, 15557, 15679, 15791, 15893, 15986
	dw	16069, 16143, 16207, 16261, 16305, 16340, 16364, 16379

;---------------------------------------------------------------------
;	END OF _3D.INC
;---------------------------------------------------------------------
