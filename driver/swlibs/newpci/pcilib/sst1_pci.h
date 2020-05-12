/*
** THIS SOFTWARE IS SUBJECT TO COPYRIGHT PROTECTION AND IS OFFERED ONLY
** PURSUANT TO THE 3DFX GLIDE GENERAL PUBLIC LICENSE. THERE IS NO RIGHT
** TO USE THE GLIDE TRADEMARK WITHOUT PRIOR WRITTEN PERMISSION OF 3DFX
** INTERACTIVE, INC. A COPY OF THIS LICENSE MAY BE OBTAINED FROM THE 
** DISTRIBUTOR OR BY CONTACTING 3DFX INTERACTIVE INC(info@3dfx.com). 
** THIS PROGRAM IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER 
** EXPRESSED OR IMPLIED. SEE THE 3DFX GLIDE GENERAL PUBLIC LICENSE FOR A
** FULL TEXT OF THE NON-WARRANTY PROVISIONS.  
** 
** USE, DUPLICATION OR DISCLOSURE BY THE GOVERNMENT IS SUBJECT TO
** RESTRICTIONS AS SET FORTH IN SUBDIVISION (C)(1)(II) OF THE RIGHTS IN
** TECHNICAL DATA AND COMPUTER SOFTWARE CLAUSE AT DFARS 252.227-7013,
** AND/OR IN SIMILAR OR SUCCESSOR CLAUSES IN THE FAR, DOD OR NASA FAR
** SUPPLEMENT. UNPUBLISHED RIGHTS RESERVED UNDER THE COPYRIGHT LAWS OF
** THE UNITED STATES.  
** 
** COPYRIGHT 3DFX INTERACTIVE, INC. 1999, ALL RIGHTS RESERVED
**
**
** $Revision: 1.2 $ 
** $Date: 2000/06/15 00:11:40 $ 
**
*/

#ifndef _SST1_PCI_H_
#define _SST1_PCI_H_

#ifndef _FXPCI_H_
#include <fxpci.h>
#endif

extern const PciRegister SST1_PCI_INIT_ENABLE; // 0x40
extern const PciRegister SST1_PCI_BUS_SNOOP_0; // 0x44
extern const PciRegister SST1_PCI_BUS_SNOOP_1; // 0x48
extern const PciRegister SST1_PCI_CFG_STATUS;  // 0x4C

extern const PciRegister SST1_PCI_VCLK_ENABLE;
extern const PciRegister SST1_PCI_VCLK_DISABLE;
#endif



