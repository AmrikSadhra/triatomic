		TITLE	v3rot.asm	18:53:41  02-Jun-2002

					; 3dfx voodoo 3 (avenger)
					; 3d register programming
					; with CauseWay Extender
					;
					; (5:6:5 / 8:8:8 mode)
		.386			;
		.MODEL	FLAT		;
					;
		.STACK	400h		; need at least 400h for
					;  some pci functions

		ASSUME	GS : NOTHING	; def.: assumed to error,
					; now GS is zero based
					; segment (for screen)


;---------------------------------------------------------------------
;	first steps with avenger 3d, just started
;
;   written by daniel hagmann
;	    rot.asm written by Abe of space (from abe`s demoschool IV)
;
;	masm 6.0
;
;---------------------------------------------------------------------
;   unreleased:
;
;---------------------------------------------------------------------
;   bugs:
;	    + sometimes no readable text under Windows
;		(bug with monochrome src. screen-screen blit)
;		    19-Oct-2001 fixed -> addr_a_wr_char
;	    02-Jun-2002  enabled subpixel correction
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
;avenger 3d registers	(prog. internally used as addresses)
;---------------------------------------------------------------------
;Memory Base 0: Offset 0x0200000   (prog. internally: _3dBase)
;---------------------------------------------------------------------
;Register Name Address	Bits  Description
;---------------------------------------------------------------------
status_3d      dd 0 ; (+0)  31:0 (read only)  Avenger Status
intrCtrl       dd 0 ; (+4)  31:0 Interrupt Status and Control
vertexAx       dd 0 ; (+8)  15:0 Vertex A x-coordinate location (12.4 format)
vertexAy       dd 0 ; (+12) 15:0 Vertex A y-coordinate location (12.4 format)
vertexBx       dd 0 ; (+16) 15:0 Vertex B x-coordinate location (12.4 format)
vertexBy       dd 0 ; (+20) 15:0 Vertex B y-coordinate location (12.4 format)
vertexCx       dd 0 ; (+24) 15:0 Vertex C x-coordinate location (12.4 format)
vertexCy       dd 0 ; (+28) 15:0 Vertex C y-coordinate location (12.4 format)
startR	       dd 0 ; (+32) 23:0 Starting Red parameter (12.12 format)
startG	       dd 0 ; (+36) 23:0 Starting Green parameter (12.12 format)
startB	       dd 0 ; (+40) 23:0 Starting Blue parameter (12.12 format)
startZ	       dd 0 ; (+44) 31:0 Starting Z parameter (20.12 format)
startA	       dd 0 ; (+48) 23:0 Starting Alpha parameter (12.12 format)
startS	       dd 0 ; (+52) 31:0 Starting S/W parameter (14.18 format)
startT	       dd 0 ; (+56) 31:0 Starting T/W parameter (14.18 format)
startW	       dd 0 ; (+60) 31:0 Starting 1/W parameter (2.30 format)
dRdX	       dd 0 ; (+64) 23:0 Change in Red with respect to X (12.12 format)
dGdX	       dd 0 ; (+68) 23:0 Change in Green with respect to X (12.12 format)
dBdX	       dd 0 ; (+72) 23:0 Change in Blue with respect to X (12.12 format)
dZdX	       dd 0 ; (+76) 31:0 Change in Z with respect to X (20.12 format)
dAdX	       dd 0 ; (+80) 23:0 Change in Alpha with respect to X (12.12 format)
dSdX	       dd 0 ; (+84) 31:0 Change in S/W with respect to X (14.18 format)
dTdX	       dd 0 ; (+88) 31:0 Change in T/W with respect to X (14.18 format)
dWdX	       dd 0 ; (+92) 31:0 Change in 1/W with respect to X (2.30 format)
dRdY	       dd 0 ; (+96) 23:0 Change in Red with respect to Y (12.12 format)
dGdY	       dd 0 ; (+100) 23:0 Change in Green with respect to Y (12.12 format)
dBdY	       dd 0 ; (+104) 23:0 Change in Blue with respect to Y (12.12 format)
dZdY	       dd 0 ; (+108) 31:0 Change in Z with respect to Y (20.12 format)
dAdY	       dd 0 ; (+112) 23:0 Change in Alpha with respect to Y (12.12 format)
dSdY	       dd 0 ; (+116) 31:0 Change in S/W with respect to Y (14.18 format)
dTdY	       dd 0 ; (+120) 31:0 Change in T/W with respect to Y (14.18 format)
dWdY	       dd 0 ; (+124) 31:0 Change in 1/W with respect to Y (2.30 format)
triangleCMD    dd 0 ; (+128)  31  Execute TRIANGLE command (floating point)
reserved_132   dd 0 ; (+132) n/a
fvertexAx      dd 0 ; (+136) 31:0 Vertex A x-coordinate location (floating point)
fvertexAy      dd 0 ; (+140) 31:0 Vertex A y-coordinate location (floating point)
fvertexBx      dd 0 ; (+144) 31:0 Vertex B x-coordinate location (floating point)
fvertexBy      dd 0 ; (+148) 31:0 Vertex B y-coordinate location (floating point)
fvertexCx      dd 0 ; (+152) 31:0 Vertex C x-coordinate location (floating point)
fvertexCy      dd 0 ; (+156) 31:0 Vertex C y-coordinate location (floating point)
fstartR        dd 0 ; (+160) 31:0 Starting Red parameter (floating point)
fstartG        dd 0 ; (+164) 31:0 Starting Green parameter (floating point)
fstartB        dd 0 ; (+168) 31:0 Starting Blue parameter (floating point)
fstartZ        dd 0 ; (+172) 31:0 Starting Z parameter (floating point)
fstartA        dd 0 ; (+176) 31:0 Starting Alpha parameter (floating point)
fstartS        dd 0 ; (+180) 31:0 Starting S/W parameter (floating point)
fstartT        dd 0 ; (+184) 31:0 Starting T/W parameter (floating point)
fstartW        dd 0 ; (+188) 31:0 Starting 1/W parameter (floating point)
fdRdX	       dd 0 ; (+192) 31:0 Change in Red with respect to X (floating point)
fdGdX	       dd 0 ; (+196) 31:0 Change in Green with respect to X (floating point)
fdBdX	       dd 0 ; (+200) 31:0 Change in Blue with respect to X (floating point)
fdZdX	       dd 0 ; (+204) 31:0 Change in Z with respect to X (floating point)
fdAdX	       dd 0 ; (+208) 31:0 Change in Alpha with respect to X (floating point)
fdSdX	       dd 0 ; (+212) 31:0 Change in S/W with respect to X (floating point)
fdTdX	       dd 0 ; (+216) 31:0 Change in T/W with respect to X (floating point)
fdWdX	       dd 0 ; (+220) 31:0 Change in 1/W with respect to X (floating point)
fdRdY	       dd 0 ; (+224) 31:0 Change in Red with respect to Y (floating point)
fdGdY	       dd 0 ; (+228) 31:0 Change in Green with respect to Y (floating point)
fdBdY	       dd 0 ; (+232) 31:0 Change in Blue with respect to Y (floating point)
fdZdY	       dd 0 ; (+236) 31:0 Change in Z with respect to Y (floating point)
fdAdY	       dd 0 ; (+240) 31:0 Change in Alpha with respect to Y (floating point)
fdSdY	       dd 0 ; (+244) 31:0 Change in S/W with respect to Y (floating point)
fdTdY	       dd 0 ; (+248) 31:0 Change in T/W with respect to Y (floating point)
fdWdY	       dd 0 ; (+252) 31:0 Change in 1/W with respect to Y (floating point)
ftriangleCMD   dd 0 ; (+256) 31   Execute TRIANGLE command (floating point)
fbzColorPath   dd 0 ; (+260) 27:0 FBI Color Path Control
fogMode        dd 0 ; (+264) 5:0  Fog Mode Control
alphaMode      dd 0 ; (+268) 31:0 Alpha Mode Control
fbzMode        dd 0 ; (+272) 20:0 RGB Buffer and Depth-Buffer Control
lfbMode        dd 0 ; (+276) 16:0 Linear Frame Buffer Mode Control
clipLeftRight  dd 0 ; (+280) 31:0 Left and Right of Clipping Register
clipTopBottom  dd 0 ; (+284) 31:0 Top and Bottom of Clipping Register
nopCMD	       dd 0 ; (+288) 0	  Execute NOP command
fastfillCMD    dd 0 ; (+292) na   Execute FASTFILL command
swapbufferCMD  dd 0 ; (+296) 8:0  Execute SWAPBUFFER command
fogColor       dd 0 ; (+300) 23:0 Fog Color Value
zaColor        dd 0 ; (+304) 31:0 Constant Alpha/Depth Value
chromaKey      dd 0 ; (+308) 23:0 Chroma Key Compare Value
chromaRange    dd 0 ; (+312) 27:0 Chroma Range Compare Values, Modes & Enable
userIntrCMD    dd 0 ; (+316) 9:0  Execute USERINTERRUPT command
stipple        dd 0 ; (+320) 31:0 Rendering Stipple Value
color0	       dd 0 ; (+324) 31:0 Constant Color #0
color1	       dd 0 ; (+328) 31:0 Constant Color #1
fbiPixelsIn    dd 0 ; (+332) 23:0 Pixel Counter (Number pixels processed)
fbiChromaFail  dd 0 ; (+336) 23:0 Pixel Counter (Number pixels failed Chroma test)
fbiZfuncFail   dd 0 ; (+340) 23:0 Pixel Counter (Number pixels failed Z test)
fbiAfuncFail   dd 0 ; (+344) 23:0 Pixel Counter (Number pixels failed Alpha test)
fbiPixelsOut   dd 0 ; (+348) 23:0 Pixel Counter (Number pixels drawn)
fogTable       dd 32 dup (0) ; (+352) to (+476) 31:0 Fog Table
reserved_480   dd  3 dup (0) ; (+480) to (+488) na
colBufferAddr  dd 0 ; (+492) 23:0 Color Buffer Base Address
colBufferStride dd 0; (+496) 15:0 Color Buffer Stride, Memory type
auxBufferAddr  dd 0 ; (+500) 23:0 Auxiliary Buffer Base Address
auxBufferStride dd 0; (+504) 15:0 Auxiliary Buffer Stride, Memory type
reserved_508   dd 0 ; (+508) n/a
clipLeftRight1 dd 0 ; (+512) 31:0 Secondary Left/Right Clipping Register
clipTopBottom1 dd 0 ; (+516) 31:0 Secondary Top/Bottom Clipping Register
reserved_520   dd 17 dup (0) ; (+520) to (+584) n/a
swapPending    dd 0 ; (+588) na   Swap buffer pending
leftOverlayBuf dd 0 ; (+592) 31:0 Left Overlay address
rightOverlayBuf dd 0; (+596) 31:0 Right Overlay address
fbiSwapHistory dd 0 ; (+600) 31:0 Swap History Register
fbiTrianglesOut dd 0; (+604) 23:0 Triangle Counter (Number triangles drawn)
sSetupMode     dd 0 ; (+608) 19:0 Triangle setup mode
sVx	       dd 0 ; (+612) 31:0 Triangle setup X
sVy	       dd 0 ; (+616) 31:0 Triangle setup Y
sARGB	       dd 0 ; (+620) 31:0 Triangle setup Alpha, Red, Green, Blue
sRed	       dd 0 ; (+624) 31:0 Triangle setup Red value
sGreen	       dd 0 ; (+628) 31:0 Triangle setup Green value
sBlue	       dd 0 ; (+632) 31:0 Triangle setup Blue value
sAlpha	       dd 0 ; (+636) 31:0 Triangle setup Alpha value
sVz	       dd 0 ; (+640) 31:0 Triangle setup Z
sWb	       dd 0 ; (+644) 31:0 Triangle setup Global W
sWtmu0	       dd 0 ; (+648) 31:0 Triangle setup Tmu0 & Tmu1 W
sS_W0	       dd 0 ; (+652) 31:0 Triangle setup Tmu0 & Tmu1 S/W (=sS/W0)
sT_W0	       dd 0 ; (+656) 31:0 Triangle setup Tmu0 & Tmu1 T/W (=sT/W0)
sWtmu1	       dd 0 ; (+660) 31:0 Triangle setup Tmu1 only W
sS_Wtmu1       dd 0 ; (+664) 31:0 Triangle setup Tmu1 only S/W (=sS/Wtmu1)
sT_Wtmu1       dd 0 ; (+668) 31:0 Triangle setup Tmu1 only T/W (=sT/Wtmu1)
sDrawTriCMD    dd 0 ; (+672) 31:0 Triangle setup (Draw)
sBeginTriCMD   dd 0 ; (+676) 31:0 Triangle setup Start New triangle
reserved_680   dd 22 dup (0) ; (+680) to (+764) n/a
textureMode    dd 0 ; (+768) 30:0 Texture Mode Control
tLOD	       dd 0 ; (+772) 23:0 Texture LOD Settings
tDetail        dd 0 ; (+776) 21:0 Texture Detail Settings
texBaseAddr    dd 0 ; (+780) 31:0 Texture Base Address
texBaseAddr_1  dd 0 ; (+784) 23:0 Texture Base Address (supplemental LOD 1)
texBaseAddr_2  dd 0 ; (+788) 23:0 Texture Base Address (supplemental LOD 2)
texBaseAddr_3_8 dd 0; (+792) 23:0 Texture Base Address (supplemental LOD 3-8)
texStride      dd 0 ; (+796)
trexInit1      dd 0 ; (+800) 31:0 TREX Hardware Initialization (register 1
nccTable0      dd 12 dup (0) ; (+804) to (+848) 31:0 or 26:0 Narrow Channel
			     ;		   Compression Table 0 (12 entries)
nccTable1      dd 12 dup (0) ; (+852) to (+896) 31:0 or 26:0 Narrow Channel
			     ;		   Compression Table 1 (12 entries)
reserved_900   dd 31 dup (0) ; (+900) to (+1020) n/a

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

curpa		db	0	    ; current page

video_mode	dw	0	    ; desired video-mode

display_base	dd	0	    ; start of LFB

draw_page_base	dd	0	    ; base addr. of other page
				    ; (for double fr.buffer)
				    ; init. from setup vbe

page_len	dd	0	    ; len. of 1 display page
				    ; calc from setup vbe

;---------------------------------------------------------------------

curx		dw	0
cury		dw	0

;---------------------------------------------------------------------

;---------------------------------------------------------------------

;msg_setup_ok	 db	"setup ok   -> key",0

msg_setup_ok	db	"setup ok   -> key",0dh,0ah
		db	"ESC to quit",0

msg_title	db	" V3rot ",0


msg_text_test	db	"tested 20`000 ascii blit`s "
		db	"including line scroll up"
		db	"   -> key, end ",0

;---------------------------------------------------------------------
;----------- internal object format ----------------------------------
;---------------------------------------------------------------------
; pointlist
;   point_1	dw  x,y,z  db a,r,g,b	    ; 10 bytes
;   ...
;		dw  0ffffh		    ; end of pointlist
;
; drawlist	(stripmode, max. 65535 points (dw))
;   triangle_1	dw  point_nr.1, point_nr.2, point_nr.3	; 1. triangle
;		dw  4,5,6,7,8,9,10,11,12,13,14,15,16	; strip.points
;   ...
;		dw  0ffffh		    ; end of drawlist
;---------------------------------------------------------------------

pointlist	dw  300,200,000 		    ; x,y,z	0
		db		000,100,000,000     ; a,r,g,b
		dw  200,300,000 		    ; x,y,z	1
		db		000,000,100,000     ; a,r,g,b
		dw  400,280,000 		    ; x,y,z	2
		db		000,000,000,100     ; a,r,g,b

		dw  0ffffh			    ; endmark

drawlist	dw  0,1,2	    ; 1. triangle
		dw  0ffffh			    ; endmark

;---------------------------------------------------------------------

argb_0		db  000,140,000,000	; a,r,g,b  tmp for test
argb_1		db  000,000,140,000	; a,r,g,b  tmp for test
argb_2		db  000,000,000,140	; a,r,g,b  tmp for test


;---------------------------------------------------------------------

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

		finit			    ; copro for conv_ax_real

;---------------------------------------------------------------------

		call	setup_3d	; (set video_mode=111h)

;---------------------------------------------------------------------

		mov	text_x,0
		mov	text_y,22

		mov	edi,offset msg_setup_ok
		call	a_out_msg_edi

		call	a_wr_debug	; acc. wr. debug registers

		call	a_wr_control	; rotx,y,z,_addx,y,z,trail


;---------------------------------------------------------------------

;------- write pixel -------

		mov	eax,display_base
		mov	edi,eax
		mov	dword ptr [edi+4060h],0ffffffffh

;---------------------------------------------------------------------

		mov	ah,0
		int	16h

	       ;call	my_triangle

		call	draw_triangle_strip	; dark triangle

		call	a_wr_debug	; acc. wr. debug registers

		mov	ah,0
		int	16h

;---------------------------------------

    rotagain:

		;input fix as data
		call	    _rotatepoints
		;output _sx,_sy [no_of_points]
		call	draw_sx_sy	; test proc   triangle

		call	a_wr_debug	; acc. wr. debug registers

		call	a_wr_control	    ; rotx,y,z,_addx,y,z


		add	rotx,1		; /256
		add	roty,2		; /256
		add	rotz,3		; /256
	       ;add	rotz,32 	; /256

	       ;add	_addx,4
	       ;add	_addy,4
	       ;add	_addz,4     ; xxx sub, too near protection

	       ;mov	ah,1
	       ;int	16h
	       ;jz	rotagain


		mov	ah,0
		int	16h

		push	ax

	       ;call	wait_retrace	    ; disable flicker
	       ;call	un_draw_sx_sy

		pop	ax

		cmp	ah,1	    ; ESC ?
		jne	rotagain


;---------------------------------------------------------------------


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


; ROT.ASM contains one function, _RotatePoints, that can be called from C.
; To do this, the C program must have some global variables
; these variables are defined as extrn here in the asm source.
; They are _bx, _by, _bz that should contain the coordinates of the object
; to be rotated. They are never changed instead the rotated coordinates
; are stored in _rx, _ry, _rz. _sx and _sy will contain the screen coordinates
; _addx, _addy, _addz are the distance the object will be moved in the x,y,z 
; direction. If they are 0 the object will appear at the center of the screen.
; ROT.ASM also contains two local routines that are called from _RotatePoints.        
        

                
;	EXTRN	_bx,_by,_bz,_rx,_ry,_rz,_sx,_sy ;extrn variables & arrays
;	EXTRN	_addx, _addy, _addz		;must be defined elsewhere (in c)

        sinax   dw      ?               ;the sin & cos variables are only
        sinay   dw      ?               ;used here, in the asm source
        sinaz   dw      ?
        cosax   dw      ?
        cosay   dw      ?
        cosaz   dw      ?

;	HALFX	EQU	 320/2		;Constants
;	HALFY	EQU	 200/2

	HALFX	EQU	 640/2		;Constants
	HALFY	EQU	 480/2		;Constants
        
;This is the precalculated sin & cos table
;It's the sin & cos values of a 256 "degree" circle with each value
;multiplied by 2^14 (we use fixed point math with 14 bits shift).
;The cosine values are the same as (sinevalues + 90 degrees). 90 deg in
;a 360 deg circle is the same as 64 "deg" in a 256 "deg" circle. That means
;that after 64 values in sintab, the costab & sintab can share the same values
sintab  dw      0, 402, 804, 1205, 1606, 2006, 2404, 2801, 3196, 3590, 3981, 4370, 4756, 5139, 5520, 5897
        dw      6270, 6639, 7005, 7366, 7723, 8076, 8423, 8765, 9102, 9434, 9760, 10080, 10394, 10702, 11003, 11297
        dw      11585, 11866, 12140, 12406, 12665, 12916, 13160, 13395, 13623, 13842, 14053, 14256, 14449, 14635, 14811, 14978
        dw      15137, 15286, 15426, 15557, 15679, 15791, 15893, 15986, 16069, 16143, 16207, 16261, 16305, 16340, 16364, 16379
costab  dw      16384, 16379, 16364, 16340, 16305, 16261, 16207, 16143, 16069, 15986, 15893, 15791, 15679, 15557, 15426, 15286
        dw      15137, 14978, 14811, 14635, 14449, 14256, 14053, 13842, 13623, 13395, 13160, 12916, 12665, 12406, 12140, 11866
        dw      11585, 11297, 11003, 10702, 10394, 10080, 9760, 9434, 9102, 8765, 8423, 8076, 7723, 7366, 7005, 6639
        dw      6270, 5897, 5520, 5139, 4756, 4370, 3981, 3590, 3196, 2801, 2404, 2006, 1606, 1205, 804, 402
        dw      0, -402, -804, -1205, -1606, -2006, -2404, -2801, -3196, -3590, -3981, -4370, -4756, -5139, -5520, -5897
        dw      -6270, -6639, -7005, -7366, -7723, -8076, -8423, -8765, -9102, -9434, -9760, -10080, -10394, -10702, -11003, -11297
        dw      -11585, -11866, -12140, -12406, -12665, -12916, -13160, -13395, -13623, -13842, -14053, -14256, -14449, -14635, -14811, -14978
        dw      -15137, -15286, -15426, -15557, -15679, -15791, -15893, -15986, -16069, -16143, -16207, -16261, -16305, -16340, -16364, -16379
        dw      -16384, -16379, -16364, -16340, -16305, -16261, -16207, -16143, -16069, -15986, -15893, -15791, -15679, -15557, -15426, -15286
        dw      -15137, -14978, -14811, -14635, -14449, -14256, -14053, -13842, -13623, -13395, -13160, -12916, -12665, -12406, -12140, -11866
        dw      -11585, -11297, -11003, -10702, -10394, -10080, -9760, -9434, -9102, -8765, -8423, -8076, -7723, -7366, -7005, -6639
        dw      -6270, -5897, -5520, -5139, -4756, -4370, -3981, -3590, -3196, -2801, -2404, -2006, -1606, -1205, -804, -402
        dw      0, 402, 804, 1205, 1606, 2006, 2404, 2801, 3196, 3590, 3981, 4370, 4756, 5139, 5520, 5897
        dw      6270, 6639, 7005, 7366, 7723, 8076, 8423, 8765, 9102, 9434, 9760, 10080, 10394, 10702, 11003, 11297
        dw      11585, 11866, 12140, 12406, 12665, 12916, 13160, 13395, 13623, 13842, 14053, 14256, 14449, 14635, 14811, 14978
        dw      15137, 15286, 15426, 15557, 15679, 15791, 15893, 15986, 16069, 16143, 16207, 16261, 16305, 16340, 16364, 16379



;		PUBLIC	_RotatePoints	;this function can be called from C
;		PUBLIC	_qsort3d	;sorts sx & sy in "rz-order"

;---------------------------------------------------------------------


num_of_pts dw	3

_bx	dw	300-320,200-320,400-320        ; base object
_by	dw	200-240,300-240,280-240        ; (from mid screen)
_bz	dw	000,000,000	    ; assume: 200 for z

;_bx	 dw	 -20,-120,080			 ; base object
;_bx	 dw	 -20,-120,080			 ; base object
;_by	 dw	 -40,060,040
;_by	 dw	 -40,060,040
;_bz	 dw	 000,000,000	     ; assume: 200 for z

_rx	dw	0,0,0	    ; used by rotatepoints
_ry	dw	0,0,0	    ; [NO_OF_PTS]
_rz	dw	0,0,0

_sx	dw	0,0,0	    ; used by rotatepoints
_sy	dw	0,0,0	    ; [NO_OF_PTS]

_addx	dw	000	    ; object move   input
_addy	dw	000
_addz	dw	000

rotx	db	000	    ; rotation	 input	    256 = 1 turn
roty	db	000
rotz	db	000

;-----------------------

_es	dw	0	    ; tmp var.

;---------------------------------------------------------------------

;_RotatePoints rotates NUM_OF_PTS points in (_bx,_by,_bz)
;					   (rotx,roty,rotz) degrees,
;adds addx,addy,addz to the coordinates, stores them in _rx, _ry & _rz
;and finally calculates the screen coordinates and stores them in _sx and _sy.
;*********** Call from c with: ***************
;*** RotatePoints(ax, ay, az, num_of_pts); *** 
;*********************************************

_RotatePoints	PROC	near
 ;	ARG rotx:Byte, roty:Byte, rotz:Byte, num_of_pts:Word

	mov	ebx,0	    ; debug
	mov	edi,0
        
        push    bp              ;this bp,sp trick must be here if
        mov     bp,sp           ;you use arguments (has to do with the stackframe)
        pushad                  ;save all registers
    
        mov     bl,[rotx]
        xor     bh,bh
	shl	bx,1		;bx = index in sintab and costab
        mov     ax,[sintab + bx] ;move the appropriate value from the sintab
        mov     [sinax],ax       ; to sinax
        mov     ax,[costab + bx] ; and the appropriate value from costab
        mov     [cosax],ax       ; to cosax
        mov     bl,[roty]       ; do the same with sinay & cosay
        xor     bh,bh
        shl     bx,1
        mov     ax,[sintab + bx]
        mov     [sinay],ax
        mov     ax,[costab + bx]
        mov     [cosay],ax
        mov     bl,[rotz]       ; and sinaz & cosaz
        xor     bh,bh
        shl     bx,1
        mov     ax,[sintab + bx]
        mov     [sinaz],ax
        mov     ax,[costab + bx]
        mov     [cosaz],ax
        
        mov     di,[num_of_pts] ;di = loopcounter
@@rotloop:                      ;loop through all points in the arrays
        dec     di              ;let di be both loopcounter and index in the arrays
        shl     di,1            ;di = di * 2 because the arrays are type int
        mov     bx,[_bx + di]   ;load cordinates to rotate
        mov     cx,[_by + di]
        mov     bp,[_bz + di]

       ;push	di
	push	edi
	call	RotPoint	;rotate the coordinates of one point
	pop	edi
       ;pop	di

        add     bx,[_addx]      ;add "movement" to the rotated coordinates
        add     cx,[_addy]
        add     bp,[_addz]
        
        mov     [_rx + di],bx   ;save rotated coordintates in _rx, _ry & _rz
        mov     [_ry + di],cx
        mov     [_rz + di],bp
        call    CalcSxSy        ;calculate the screen coordinates
        mov     [_sx + di],bx   ;and save them in _sx and _sy
        mov     [_sy + di],cx
        
        shr     di,1            ;shift di back into acting as loopcounter
        or      di,di           ;is di 0 yet?
        jnz     @@rotloop       ;if not, rotate another point
    
        popad                   ;restore the saved registers
        pop     bp
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
        mov     ax,[cosax]      ; ax = cos(angle x)
        imul    cx              ; dx:ax = cos(angle x) * y
        mov     di,dx           ; dx:ax means that the high word of the multiplication
        shl     edi,16          ; is in dx and the low word in ax
        mov     di,ax           ; edi = by * cos(angle x)
        mov     ax,[sinax]      ; ax = sin(angle x)
        imul    bp              ; ax = sin(angle x) * z
        shl     edx,16
        mov     dx,ax           ; edx = bz * sinax
        sub     edi,edx         ; edi=edi-edx= cos(angle x)*y - sin(angle x)*z
        sar     edi,14          ; shift to the actual value (fixed point math)
       ;mov	es,di		; save rotated y in es
	mov	_es,di		 ; save rotated y in es
        mov     ax,[sinax]      ; ax = sin(angle x)
        imul    cx              ; dx:ax = sin(angle x) * y
        mov     di,dx
        shl     edi,16
        mov     di,ax           ; edi = sin(angle x) * y
        mov     ax,[cosax]      ; ax = cos(angle x)
        imul    bp              ; dx:ax = cos(angle x) * z
        shl     edx,16
        mov     dx,ax           ; edx = cos(angle x) * z
        add     edi,edx         ;edi=edi+edx = sin(angle x)*y + cos(angle x)*z
        sar     edi,14          ;shift right => di = actual value of rotated z
       ;mov	cx,es		; cx = ry (rotated y)
	mov	cx,_es		 ; cx = ry (rotated y)
        mov     bp,di           ; bp = rz (rotated z)

                                ; Rotate point around the Y-axis
                                ; rx =  cos(angle y) * x + sin(angle y) * rz
                                ; rrz = -sin(angle y) * x + cos(angle y) * rz
        mov     ax,[cosay]      ; ax = cos(angle y)
        imul    bx              ; dx:ax = cos(angle y) * x
        mov     di,dx
        shl     edi,16
        mov     di,ax           ; edi = cos(angle y) * x
        mov     ax,[sinay]      ; ax = sin(angle y)
        imul    bp              ; dx:ax = sin(angle y) * rz
        shl     edx,16
        mov     dx,ax           ; edx = sin(angle y) * rz
        add     edi,edx         ;edi=edi+edx= cos(angle y)*x + sin(angle y)*rz
        sar     edi,14          ; apply fixed point math
       ;mov	es,di		; save rx (rotated x) in es
	mov	_es,di		 ; save rx (rotated x) in es
        mov     ax,[sinay]      ; ax = sin(angle y)
        neg     ax              ; ax = -sin(angle y)
        imul    bx              ; dx:ax = -sin(angle y) * x
        mov     di,dx
        shl     edi,16
        mov     di,ax           ; edi = -sin(angle y) * x
        mov     ax,[cosay]      ; ax = cos(angle y)
        imul    bp              ; dx:ax = cos(angle y) * rz
        shl     edx,16
        mov     dx,ax           ; edx = cos(angle y) * rz
        add     edi,edx         ;edi=edi-edx=-sin(angle y)*x + cos(angle y)*rz
        sar     edi,14          ;fp math, di = rrz (rotated rz)
       ;mov	bx,es		; bx = rx (rotated x)
	mov	bx,_es		 ; bx = rx (rotated x)
        mov     bp,di           ; bp = rrz (rotated rotated z)

                                ; Rotate point around the Z-axis
                                ; rrx = cos(vz) * rx - sin(vz) * ry
                                ; rry = sin(vz) * rx + cos(vz) * ry
        mov     ax,[cosaz]      ; ax = cos(angle z)
        imul    bx              ; dx:ax = cos(angle z) * rx
        mov     di,dx
        shl     edi,16
        mov     di,ax           ;edi = cos(angle z) * rx
        mov     ax,[sinaz]      ; ax = sin(angle z)
        imul    cx              ; dx:ax = sin(angle z) * ry
        shl     edx,16
        mov     dx,ax           ; edx = sin(angle z) * ry
        sub     edi,edx         ;edi=edi-edx=cos(angle z)*rx - sin(angle z)*ry
        sar     edi,14          ; shift right to actual value
       ;mov	es,di		; es = rrx
	mov	_es,di		 ; es = rrx
        mov     ax,[sinaz]      ; ax = sin(angle z)
        imul    bx              ; dx:ax = sin(angle z) * rx
        mov     di,dx
        shl     edi,16
        mov     di,ax           ; edi = sin(angle z) * rx
        mov     ax,[cosaz]      ; ax = cos(angle z)
        imul    cx              ; dx:ax = cos(angle z) * ry
        shl     edx,16
        mov     dx,ax           ; edx = cos(angle z) * ry
        add     edi,edx         ;edi=edi+edx=sin(angle z)*rx + cos(angle z)*ry
        sar     edi,14          ; shift right to actual value
       ;mov	bx,es		; bx = rrx (rotated rx)
	mov	bx,_es		 ; bx = rrx (rotated rx)
        mov     cx,di           ; cx = rry (rotated ry)
    
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

CalcSxSy    PROC    near
                                ; Perspective Projection:
                                ; SX = DIST * X / (DIST + Z)
                                ; SY = DIST * Y / (DIST + Z)
        movsx   eax,bx          ; eax = x-coord. with Sign eXtension
        shl     eax,8           ; eax = 256*x  (distance is 256)
        mov     edx,eax         ; edx = 256*x
        shr     edx,16          ; dx:ax = 256*x (DIST * X)
        add     bp,256          ; bp = DIST + Z 
        idiv    bp              ; quote of division => ax
        add     ax,HALFX        ; add ax with 320/2 (half width of screen)
        mov     bx,ax           ; bx = 256*x / (256 + z) + 160
        
        movsx   eax,cx          ; eax = y-coord. with Sign eXtension
        shl     eax,8           ; eax = 256*y
        mov     edx,eax
        shr     edx,16          ; dx:ax = 256*y (DIST * Y)
        idiv    bp              ; divide with (DIST + Z)
        add     ax,HALFY        ; add result of division with half screen height
        mov     cx,ax           ; cx = 256*y/(256 + z) + 100
        ret

CalcSxSy    ENDP
    
;---------------------------------------------------------------------

draw_sx_sy	PROC	near	; test, _sx,_sy calculated

		mov	ax,0000000000000000b	; strip mode
		shl	eax,16
	       ;mov	ax,0000000000100010b	; setup alpha,s0,t0
		mov	ax,0000000000000011b	; setup rgb,alpha
		mov	edi,sSetupMode
		mov	[edi],eax

;---------------------------

;begin triangle setup
;vertex #0

		mov	ax,word ptr [_sx]
		call	conv_ax_real
		mov	edi,sVx
		mov	[edi],eax

		mov	ax,word ptr [_sy]
		call	conv_ax_real
		mov	edi,sVy
		mov	[edi],eax

		mov	eax,0
		mov	ah,byte ptr [argb_0]	; a
		mov	al,byte ptr [argb_0+1]	; r
		shl	eax,16
		mov	ah,byte ptr [argb_0+2]	; g
		mov	al,byte ptr [argb_0+3]	; b
		mov	edi,sARGB
		mov	[edi],eax

		mov	eax,0
		mov	edi,sBegintriCMD
		mov	[edi],eax	    ; begin triangle

;-------------------

;next vertex

		mov	ax,word ptr [_sx+2]
		call	conv_ax_real
		mov	edi,sVx
		mov	[edi],eax

		mov	ax,word ptr [_sy+2]
		call	conv_ax_real
		mov	edi,sVy
		mov	[edi],eax

		mov	eax,0
		mov	ah,byte ptr [argb_1]	; a
		mov	al,byte ptr [argb_1+1]	; r
		shl	eax,16
		mov	ah,byte ptr [argb_1+2]	; g
		mov	al,byte ptr [argb_1+3]	; b
		mov	edi,sARGB
		mov	[edi],eax

		mov	eax,0
		mov	edi,sDrawtriCMD
		mov	[edi],eax


;-------------------

;next vertex

		mov	ax,word ptr [_sx+4]
		call	conv_ax_real
		mov	edi,sVx
		mov	[edi],eax

		mov	ax,word ptr [_sy+4]
		call	conv_ax_real
		mov	edi,sVy
		mov	[edi],eax

		mov	eax,0
		mov	ah,byte ptr [argb_2]	; a
		mov	al,byte ptr [argb_2+1]	; r
		shl	eax,16
		mov	ah,byte ptr [argb_2+2]	; g
		mov	al,byte ptr [argb_2+3]	; b
		mov	edi,sARGB
		mov	[edi],eax

		mov	eax,0
		mov	edi,sDrawtriCMD
		mov	[edi],eax

		RET
draw_sx_sy	ENDP

;---------------------------------------------------------------------

un_draw_sx_sy	PROC	near	; test, _sx,_sy calculated

		mov	ax,0000000000000000b	; strip mode
		shl	eax,16
	       ;mov	ax,0000000000100010b	; setup alpha,s0,t0
		mov	ax,0000000000000011b	; setup rgb,alpha
		mov	edi,sSetupMode
		mov	[edi],eax

;---------------------------

;begin triangle setup
;vertex #0

		mov	ax,word ptr [_sx]
		call	conv_ax_real
		mov	edi,sVx
		mov	[edi],eax

		mov	ax,word ptr [_sy]
		call	conv_ax_real
		mov	edi,sVy
		mov	[edi],eax

		mov	eax,0
	       ;mov	ah,byte ptr [argb_0]	; a
	       ;mov	al,byte ptr [argb_0+1]	; r
	       ;shl	eax,16
	       ;mov	ah,byte ptr [argb_0+2]	; g
	       ;mov	al,byte ptr [argb_0+3]	; b
		mov	edi,sARGB
		mov	[edi],eax

		mov	eax,0
		mov	edi,sBegintriCMD
		mov	[edi],eax	    ; begin triangle

;-------------------

;next vertex

		mov	ax,word ptr [_sx+2]
		call	conv_ax_real
		mov	edi,sVx
		mov	[edi],eax

		mov	ax,word ptr [_sy+2]
		call	conv_ax_real
		mov	edi,sVy
		mov	[edi],eax

		mov	eax,0
	       ;mov	ah,byte ptr [argb_1]	; a
	       ;mov	al,byte ptr [argb_1+1]	; r
	       ;shl	eax,16
	       ;mov	ah,byte ptr [argb_1+2]	; g
	       ;mov	al,byte ptr [argb_1+3]	; b
		mov	edi,sARGB
		mov	[edi],eax

		mov	eax,0
		mov	edi,sDrawtriCMD
		mov	[edi],eax


;-------------------

;next vertex

		mov	ax,word ptr [_sx+4]
		call	conv_ax_real
		mov	edi,sVx
		mov	[edi],eax

		mov	ax,word ptr [_sy+4]
		call	conv_ax_real
		mov	edi,sVy
		mov	[edi],eax

		mov	eax,0
	       ;mov	ah,byte ptr [argb_2]	; a
	       ;mov	al,byte ptr [argb_2+1]	; r
	       ;shl	eax,16
	       ;mov	ah,byte ptr [argb_2+2]	; g
	       ;mov	al,byte ptr [argb_2+3]	; b
		mov	edi,sARGB
		mov	[edi],eax

		mov	eax,0
		mov	edi,sDrawtriCMD
		mov	[edi],eax


		RET
un_draw_sx_sy	ENDP

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
;=====================================================================
;---------------------------------------------------------------------

draw_triangle_strip PROC    near

		mov	ax,0000000000000000b	; strip mode
		shl	eax,16
	       ;mov	ax,0000000000100010b	; setup alpha,s0,t0
		mov	ax,0000000000000011b	; setup rgb,alpha
		mov	edi,sSetupMode
		mov	[edi],eax

;---------------------------

		mov	ebp,offset drawlist	; init
		mov	ax,word ptr [ebp]
		cmp	ax,0ffffh		; end ?
		jne	drtrstr_calc
		RET
    drtrstr_calc:
		call	calc_point_addr     ; (nr in ax) -> esi


;---------------------------

;begin triangle setup
;vertex #0

		mov	ax,word ptr [esi]
		call	conv_ax_real
		mov	edi,sVx
		mov	[edi],eax

		mov	ax,word ptr [esi+2]
		call	conv_ax_real
		mov	edi,sVy
		mov	[edi],eax

		mov	eax,0
		mov	ah,byte ptr [esi+6]	; a
		mov	al,byte ptr [esi+7]	; r
		shl	eax,16
		mov	ah,byte ptr [esi+8]	; g
		mov	al,byte ptr [esi+9]	; b
		mov	edi,sARGB
		mov	[edi],eax

		mov	eax,0
		mov	edi,sBegintriCMD
		mov	[edi],eax	    ; begin triangle

;-------------------

;next vertex

    drtrstr_again:

		add	ebp,2		    ; to next point

		mov	ax,word ptr [ebp]
		cmp	ax,0ffffh		; end ?
		jne	drtrstr_nxcalc
		RET
    drtrstr_nxcalc:
		call	calc_point_addr     ; (nr in ax) -> esi

		mov	ax,word ptr [esi]
		call	conv_ax_real
		mov	edi,sVx
		mov	[edi],eax

		mov	ax,word ptr [esi+2]
		call	conv_ax_real
		mov	edi,sVy
		mov	[edi],eax

		mov	eax,0
		mov	ah,byte ptr [esi+6]	; a
		mov	al,byte ptr [esi+7]	; r
		shl	eax,16
		mov	ah,byte ptr [esi+8]	; g
		mov	al,byte ptr [esi+9]	; b
		mov	edi,sARGB
		mov	[edi],eax


		mov	eax,0
		mov	edi,sDrawtriCMD
		mov	[edi],eax

		jmp	drtrstr_again



		RET
draw_triangle_strip ENDP

;---------------------------------------------------------------------

calc_point_addr PROC	near		    ; (nr in ax) -> esi

		mov	esi,offset pointlist
						; *10 (len of rec)
		cwde				;	(ax -> eax)
		push	eax
		shl	eax,3		    ; *8
		add	esi,eax
		pop	eax
		shl	eax,1		    ; *2
		add	esi,eax


		RET
calc_point_addr ENDP

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


;------- execute -----------

		mov	eax,0
		mov	edi,triangleCmd
		mov	[edi],eax


		RET
my_triangle	ENDP



;=====================================================================
;---------------------------------------------------------------------

setup_3d	PROC	near



		mov	video_mode,111h     ; 111h=640*480*64k
					    ;	    (5:6:5)
					    ; 112h=640*480*16M
					    ;	   (8:8:8)
		call	setup_vbe   ; all to setupvbe for lfb

;-----------------------------------------------

		call	pci_check     ; search + get avenger adr.
		call	map_2d3dregs  ; memBaseAddr0 -> _2dBase, _3dBase
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
	       ;mov	eax,[edi]

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

		mov	edi,auxBufferAddr
		mov	eax,page_len
		mov	[edi],eax		; ?

;-----------------------

		mov	ax,0			; min. x
		shl	eax,16
		mov	ax,640			; max. x +1
		mov	edi,clipLeftRight
		mov	[edi],eax

		mov	ax,0			; min. y
		shl	eax,16
		mov	ax,480			; max. y +1
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
		or	eax,00000100000000000000000000000000b
				    ; bit 26 subpixel correction
			; (sometimes if tri. are putted together)
		mov	[edi],eax

		mov	edi,fbzMode
		mov	eax,[edi]
		or	al,1	    ; bit 0, enable clipping
		or	ah,10b	    ;	!!! bit 9, enable rgb wr.
		or	ah,100b     ; (!) bit 10, en. depth buf. wr.
		or	al,00010000b	; bit 4, en.depth buffering
		or	al,11100000b	; depth OP (111=always)
		or	ah,1	    ;  !!!  bit 8, enable dither.
					;	    (less color steps)
			   ;10987654321098765432109876543210
		or	eax,00000000000000000000100000000000b
				    ; bit 11 dither 2*2 not 4*4
		mov	[edi],eax




		RET
setup_3d	ENDP

;=====================================================================
;---------------------------------------------------------------------

msg_rotx	db	" rotx: ",0
msg_roty	db	" roty: ",0
msg_rotz	db	" rotz: ",0

msg_addx	db	"_addx: ",0
msg_addy	db	"_addx: ",0
msg_addz	db	"_addx: ",0

msg_trail	db	"trail: ",0

msg_yes 	db	"yes",0
msg_no		db	"no ",0

;---------------------------------------------------------------------

a_wr_control	PROC	near	    ; rotx,y,z,_addx,y,z,trail


		mov	text_x,0	; start_x
		mov	text_y,10	; start_y

		mov	edi,offset msg_rotx
		call	a_out_msg_edi

		mov	al,rotx
		call	a_wr_dec_byte

;-------------------

		mov	text_x,0
		add	text_y,1

		mov	edi,offset msg_roty
		call	a_out_msg_edi

		mov	al,roty
		call	a_wr_dec_byte

;-------------------

		mov	text_x,0
		add	text_y,1

		mov	edi,offset msg_rotz
		call	a_out_msg_edi

		mov	al,rotz
		call	a_wr_dec_byte

;-------------------

		mov	text_x,0
		add	text_y,1

		mov	edi,offset msg_addx
		call	a_out_msg_edi

		mov	ax,_addx
		call	a_wr_dec_word

;-------------------

		mov	text_x,0
		add	text_y,1

		mov	edi,offset msg_addy
		call	a_out_msg_edi

		mov	ax,_addy
		call	a_wr_dec_word

;-------------------

		mov	text_x,0
		add	text_y,1

		mov	edi,offset msg_addz
		call	a_out_msg_edi

		mov	ax,_addz
		call	a_wr_dec_word





		RET
a_wr_control	ENDP

;---------------------------------------------------------------------

hexchars	db	"0123456789ABCDEF"  ; for xlat_al


msg_fbiTrianglesOut db	"fbiTrianglesOut: ",0
msg_fbiPixelsIn     db	"fbiPixelsIn:     ",0
msg_fbiPixelsOut    db	"fbiPixelsOut:    ",0
msg_fbiChromaFail   db	"fbiChromaFail: ",0
msg_fbiZfuncFail    db	"fbiZfuncFail:  ",0
msg_fbiAfuncFail    db	"fbiAfuncFail:  ",0


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

;---------------------------------------------------------------------

a_wr_8_hex	PROC	near	; acc wr value of eax

		push	eax

		mov	cx,8
    awr8hagain:
		rol	eax,4
		push	eax
		and	al,0fh
		call	xlat_al 	; to ascii
		call	a_writt_al
		pop	eax
		loopw	awr8hagain

		mov	al,20h
		call	a_writt_al

		mov	al,"h"
		call	a_writt_al

		pop	eax

		RET
a_wr_8_hex	ENDP

;---------------------------------------------------------------------

;----------------------------------------------------------------------

c_div_10000	dw	27  ; 0,1 function  div 10`000 to ascii
base_number	dw	0   ;?2,3 base_number	       XXXXX
		db	0   ; 4   10`000 er	       X....
		db	0   ; 5    1`000 er		X...
		db	0   ; 6      100 er		 X..
		db	0   ; 7       10 er		  X.
		db	0   ; 8        1 er		   X

;---------------------------------------------------------------------

a_wr_dec_byte	PROC	near	; byte is in al

		call	a_three_space
		sub	text_x,3

		mov	ah,0
		mov	base_number,ax
		call	wr_w_npz

		RET
a_wr_dec_byte	ENDP

;---------------------------------------------------------------------

a_wr_dec_word	PROC	near	; word is in ax

		mov	base_number,ax
		call	wr_w_npz

		RET
a_wr_dec_word	ENDP

;---------------------------------------------------------------------

wr_w_npz	PROC	near		; in base_number
					    ; supress prezeros
		push	ax
		push	cx
		push	edi

		mov	edi,offset c_div_10000
		call	f27

		add	edi,4		 ; to numbers
		mov	cx,5
    prezagain:
		mov	al,byte ptr [edi]
		cmp	al,30h
		jne	noprezero
		add	edi,1
		loop	prezagain
		sub	edi,1
    noprezero:
		mov	al,byte ptr [edi]
		call	a_writt_al
		cmp	cx,0
		je	wr_kbend
		add	edi,1
		loop	noprezero
    wr_kbend:

		pop	edi
		pop	cx
		pop	ax

		RET
wr_w_npz	ENDP

;----------------------------------------------------------------------

f27		PROC	near	    ; 10`000_div
				       ; need no zero_protect
		mov	ax,word ptr [edi+2]
		mov	dx,0
		mov	bx,10000
		div	bx
		mov	byte ptr [edi+4],al
		mov	ax,dx
		mov	dx,0
		mov	bx,1000
		div	bx
		mov	byte ptr [edi+5],al
		mov	ax,dx
		mov	bl,100
		div	bl
		mov	byte ptr [edi+6],al
		mov	al,ah
		mov	ah,0
		mov	bl,10
		div	bl
		mov	byte ptr [edi+7],al
		mov	byte ptr [edi+8],ah

;-------------
		add	byte ptr [edi+4],30h	; conv. to ascii
		add	byte ptr [edi+5],30h	; conv. to ascii
		add	byte ptr [edi+6],30h	; conv. to ascii
		add	byte ptr [edi+7],30h	; conv. to ascii
		add	byte ptr [edi+8],30h	; conv. to ascii

		RET
f27		ENDP


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

dec_string	db	13 dup (0),0
ten		dw	10
comma_count	db	0

;---------------------------------------------------------------------
; dword_convert - convert dword to decimal ascii and store using EDI
;   inputs:  dx,ax = binary value
;	     edi   = storage point
;  output:  edi = pointer to start of decimal string
;
;---------------------------------------------------------------------

dd_to_dec_string PROC	near

		push	ax
		push	bx
		push	dx

		mov	comma_count,4

; convert one character each loop.  The least significant digits are
; converted first.

    dd_loop:
		push	ax
		mov	ax,dx
		xor	dx,dx
		div	ten
		mov	bx,ax
		pop	ax
		div	ten
		xchg	bx,dx

    ; dx,ax = quotient	bx = remainder


		dec	comma_count
		jnz	not_yet1	    ; jmp if not time for comma
		mov	comma_count,3
		mov	byte ptr [edi],"`"
		dec	edi
    not_yet1:
		add	bl,30h
		mov	byte ptr [edi],bl
		dec	edi

    ; dx,ax = quotient	bx = remainder


		or	ax,ax
		jnz	dd_loop
		or	dx,dx
		jnz	dd_loop
		inc	edi	    ; point at last char. stored.

		pop	dx
		pop	bx
		pop	ax

		RET

dd_to_dec_string ENDP

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

text_test	PROC	near

	       ;jmp	tt2		; jump over debug

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

;----------------------------------------------------------------------

a_space 	PROC	near

		push	ax

		mov	al,20h
		call	a_writt_al

		pop	ax

		RET
a_space 	ENDP

;----------------------------------------------------------------------

a_three_space	PROC	near

		push	ax

		mov	al,20h
		call	a_writt_al
		call	a_writt_al
		call	a_writt_al

		pop	ax

		RET
a_three_space	ENDP

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
		jmp	prg_exit

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

calc_esi	PROC	near	; display_base, curx, cury
				    ; for set_pixel,...
				    ; esi changed, eax destroyed
				    ; (for 8:8:8 modes)
		push	bx
		push	edx

		mov	esi,display_base
		mov	eax,0
		mov	ax,BytesPerScanLine
		mov	bx,cury
		mul	bx
		shl	edx,16
		mov	dx,ax
		add	esi,edx
		mov	eax,0
		mov	ax,curx
		shl	ax,1	    ; *2
		add	ax,curx     ; =*3
		add	esi,eax

		pop	edx
		pop	bx

		RET
calc_esi	ENDP

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
		db	"untersttzt",0
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
		clc				; mode found
		RET

    cmavend2:
		stc				; mode not found

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
		cmp	ax,4fh	    ; ok ? (ah=0, al=4fh)
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
		cmp	ax,4fh	    ; ok ? (ah=0, al=4fh)
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
		call	 crlf
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
