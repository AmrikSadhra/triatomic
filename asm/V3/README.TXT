V3  programming voodoo 3 (aka avenger) in DOS with assembly



-there was a bug when running under windows: first it works, then
 after runnig some programs accelerated text is not working anymore
 19-Oct-2001 fixed: if running dos under windows, host to screen blit
		    is used instead of screen to screen blit.


The v3.exe is included for fast testing, (does it work or not),
to spare the time for individual recompiling v3.asm
about 48 KB from this exe is the extender part

To see "what is going on" v3.sym is also included. With the CauseWay
debugger "CWD" (type cwd v3), the example v3 can executed step by step,
and all symbol names are displayed.
(Flip, f10, should be activated at cwd startup for screen flipping)

CauseWay (including cwd) can be found at
http://www.devoresoftware.com/freesource/mainsrc.htm

--------

most avenger related are the address definitions, the procs "pci_check",
"map2d3dregs", "set_all_2d_reg_addr", and line/rectange/blit

the gif part is only to demonstrate the blit functions
(loadgif is written by John McCarthy, it was taken from 3dvect39.zip)

setup_vbe at the bottom of v3.asm is an older independent project from me,
used to set an (available) vbe mode given in video_mode

----------

started now with v33 (voodoo 3	3D), set my first triangles

----------

started now with v3rot (voodoo 3 rotation)

	because voodoo3 does not support transform and lightning with
	hardware, this has to be done with software.
	I adapted some routines from abe`s demoschool part IV.
	currently it is only a single triangle that can be moved and
	rotated.
	(you can play with rotx, roty, rotz, _addx, _addy, _addz)

----------

please keep in mind that for repeated commands to the GPU a busy check
is maybe necessary: read the status register until the engine is idle

----------

Daniel Hagmann
daniel_hagmann@swissonline.ch
http://homepage.swissonline.ch/tinyasm/v3.htm

26-Nov-2001

-
