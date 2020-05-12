## triatomic


The beginnings of a 3dfx Voodoo3 (H3) Linux Driver and AGP to PCI hardware adapter to enable use on modern systems. The driver will be derived mostly from the 3dfx Voodoo3 Technical reference documentation found under */doc/*, with help from the final Voodoo3 Glide3x driver drop under */driver/*. Assembly code for a Voodoo3 3D demo written by "Kennie" is also to be referenced, under */asm/*.  

##### The initial planned approach is to: 

1. Build the AGP to PCI adapter using a PCI riser and Universal AGP slot, along with the AGP to PCI pinout document under /hw/doc/ written by Löschzwerg of the PCGH forums.
2. Bring up basic polygon fill code on the Voodoo's 2D engine in user space, if the card succesfully enumerates using the aforementioned adapter. 
3. Bring up some basic 3D functionality using the CMDFIFO mechanism, building and writing command packets, and querying the device's busy status. 
4. Evaluate whether there's a point writing an OpenGL 1 driver with Mesa

##### Current Status

Adapter build is underway

##### Bringup Notes:

* PCI00: Device/VendorID read: 31:16 = 0x0005 "Speed Sorted" 15:0 = 0x121A 
* PCI04: Strapping Pin 3 VMI_HD3 indicates AGP disabled, bit 20 confirm
* Peep the whole register, should give me an idea of successful init, Bit 1 and 0 are Mem access en and I/O access En -> Need 1
* Bring up cmdfifo support and build Packets, execute from FBMEM 
* How does AGP memory work, without AGP? 
