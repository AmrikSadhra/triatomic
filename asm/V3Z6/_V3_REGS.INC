;---------------------------------------------------------------------
;		_v3_regs.inc		23:43:03  27-Jul-2003
;
;			3dfx Voodoo 3  io+2D+3D Register defs.
;---------------------------------------------------------------------
		.DATA
;---------------------------------------------------------------------
;avenger io registers	(prog. internally used as addresses)
;---------------------------------------------------------------------
;Memory Base 0: Offset 0x0000000   (prog. internally: _ioBase)
;---------------------------------------------------------------------
;Register Name Address	Bits  Description
;---------------------------------------------------------------------
status_io      dd 0 ; (+0)  31:0 (read only)  Avenger status register
	;--- initializations register: ---
pciInit0       dd 0 ; (+4)   4	31:0	PCI initialization
sipMonitor     dd 0 ; (+8)   8	31:0	silicon process monitor
lfbMemoryConfig dd 0 ;(+12) 0ch 31:0	starting tile page and stride
miscInit0      dd 0 ; (+16) 10h 31:0	misc. initialization
miscInit1      dd 0 ; (+20) 14h 31:0	misc. initialization
dramInit0      dd 0 ; (+24) 18h 31:0	DRAM initialization reg.0
dramInit1      dd 0 ; (+28) 1ch 31:0	DRAM initialization reg.1
agpInit0       dd 0 ; (+32) 20h 31:0	AGP initialization
tmuGbeInit     dd 0 ; (+36) 24h 31:0	read-reordering memory init.
vgaInit0       dd 0 ; (+40) 28h 31:0	VGA initialization
vgaInit1       dd 0 ; (+44) 2ch 31:0	VGA initialization
dramCommand    dd 0 ; (+48) 30h 31:0	(see 2D offset 0x70)
dramData       dd 0 ; (+52) 34h 31:0	(see 2D offset 0x064)
strapInfo      dd 0 ; (+56) 38h 11:0	strap bits after power up
	;--- A video register: ---
VidTvOutBlankVCount dd 0 ; (+60) 31:0  3ch  TV out vertical activ start/end
	;--- PLL and DAC registers: ---
pllCtrl0       dd 0 ; (+64) 40h  31:0	video clock PLL
pllCtrl1       dd 0 ; (+68) 44h  31:0	GRX clock PLL
pllCtrl2       dd 0 ; (+72) 48h  31:0	AGP PLL
dacMode        dd 0 ; (+76) 4ch   4:0	DAC mode 2:1 or 1:1
dacAddr        dd 0 ; (+80) 50h   8:0	DAC pallette address
dacData        dd 0 ; (+84) 54h  23:0	DAC data register
	;--- video registers part I: ---
rgbMaxDelta    dd 0 ;  (+88) 58h 23:0	max. delta for video filtering
vidProcCfg     dd 0 ;  (+92) 5ch 31:0	video processor configuration
hwCurPatAddr   dd 0 ;  (+96) 60h 23:0	cursor pattern address
hwCurLoc       dd 0 ; (+100) 64h 26:0	x and y location of HW cursor
hwCurC0        dd 0 ; (+104) 68h 23:0	HW cursor color 0
hwCurC1        dd 0 ; (+108) 6ch 23:0	HW cursor color 1
vidInFormat    dd 0 ; (+112) 70h 31:0	video in format
vidTvOutBlankHCount   dd 0 ; (+116) 74h  31:0 TV out horizontal activ start/end
vidSerialParallelPort dd 0 ; (+120) 78h  31:0 serial and parallel ports
vidInXDecimDeltas     dd 0 ; (+124) 7ch  video in h. decimation delta 1+2
vidInDecimInitErrs    dd 0 ; (+128) 80h  video in h+v decim. initial err. term
vidInYDecimDeltas     dd 0 ; (+132) 84h  video in v. decimation delta 1+2
vidPixelBufThold      dd 0 ; (+136) 88h  17:0  video pixel buffer threshold
vidChromaMin	      dd 0 ; (+140) 8ch        chroma key minimum value
vidChromaMax	      dd 0 ; (+144) 90h        chroma key maximum value
vidInStatusCurrentLine dd 0 ; (+148) 94h  video in status and cur. scan line
vidScreenSize	       dd 0 ; (+152) 98h  23:0 screen resolution
vidOverlayStartCoords  dd 0 ; (+156) 9ch  31:0 start surface + screen coor.
vidOverlayEndScreenCoord dd 0 ; (+160)	0a0h overlay end screen coordinates
vidOverlayDudx		 dd 0 ; (+164)	0a4h  overlay h. magification factor
vidOverlayDudxOffsetSrcWidth dd 0 ; (+168)  0a8h dudx offset + o. src width
vidOverlayDvdy	      dd 0 ; (+172)  0ach overlay vertical magnification factor
	;--- VGA registers: --- (only in I/O space, not memory mapped)
vga_b0	       dd 0 ; (+176)  0b0h
vga_b4	       dd 0 ; (+180)  0b4h
vga_b8	       dd 0 ; (+184)  0b8h
vga_bc	       dd 0 ; (+188)  0bch
vga_c0	       dd 0 ; (+192)  0c0h
vga_c4	       dd 0 ; (+196)  0c4h
vga_c8	       dd 0 ; (+200)  0c8h
vga_cc	       dd 0 ; (+204)  0cch
vga_d0	       dd 0 ; (+208)  0d0h
vga_d4	       dd 0 ; (+212)  0d4h
vga_d8	       dd 0 ; (+216)  0d8h
vga_dc	       dd 0 ; (+220)  0dch
	;--- video registers part II: ---
vidOverlayDvdyOffset	dd 0 ; (+224)  0e0h   overlay v. mag. factor init offs.
vidDesktopStartAddr	dd 0 ; (+228)  0e4h  desktop start address
vidDesktopOverlayStride dd 0 ; (+232)  0e8h desktop and overlay strides
vidInAddr0     dd 0 ; (+236)  0ech  video in buffer 0 start address
vidInAddr1     dd 0 ; (+240)  0f0h  video in buffer 1 start address
vidInAddr2     dd 0 ; (+244)  0f4h  video in buffer 2 start address
vidInStride    dd 0 ; (+248)  0f8h  video in buffer stride
vidCurrOverlayStartAddr dd 0 ; (+252) 0fch 23:0  current overlay start a.i.use

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
;		end of _v3_regs.inc
;---------------------------------------------------------------------
