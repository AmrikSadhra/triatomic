/*
** Copyright (c) 1995, 3Dfx Interactive, Inc.
** All Rights Reserved.
**
** This is UNPUBLISHED PROPRIETARY SOURCE CODE of 3Dfx Interactive, Inc.;
** the contents of this file may not be disclosed to third parties, copied or
** duplicated in any form, in whole or in part, without the prior written
** permission of 3Dfx Interactive, Inc.
**
** RESTRICTED RIGHTS LEGEND:
** Use, duplication or disclosure by the Government is subject to restrictions
** as set forth in subdivision (c)(1)(ii) of the Rights in Technical Data
** and Computer Software clause at DFARS 252.227-7013, and/or in similar or
** successor clauses in the FAR, DOD or NASA FAR Supplement. Unpublished  -
** rights reserved under the Copyright Laws of the United States.
**
** $Revision: 1.1.1.1 $
** $Date: 2000/08/03 00:27:20 $
*/

#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

#include <fx64.h>
#include "texusint.h"

static int 
dithmat[4][4] = { 0,  8,  2, 10, 
                  12,  4, 14,  6, 
                  3, 11,  1,  9, 
                  15,  7, 13,  5 };

// for error diffusion.
static int      errR[MAX_TEXWIDTH], errG[MAX_TEXWIDTH], errB[MAX_TEXWIDTH];     

// duplicate data for textures which have a minimal block size (yuyv, uyvy, compressed)
// src - input data
// wp, hp pointers to input dimensions, converted dimensions output
// lbw, lbh log of block width & height
static const FxU32 *
_txDuplicateData(const FxU32 *src, int *wp, int *hp, int lbw, int lbh)
{
    FxU32 *dst;
    int width = *wp, height = *hp;
    int x, y, w, h;
    int bw = 1 << lbw, bh = 1 << lbh;

    w = (width+bw-1)&~(bw-1);
    h = (height+bh-1)&~(bh-1);

    dst = (FxU32 *)malloc(w*h*sizeof(FxU32));

    for (y=0; y < h; y++) {
        for (x=0; x < w; x++) {
            dst[x + y * w] = src[ (x%width) + (y%height)*width];
        }
    }

    *wp = w;
    *hp = h;

    return dst;
#undef BLOCK_SIZE
}

static int
_txPixQuantize_RGB332( unsigned long argb, int x, int y, int w)
{
    return (
            (((argb>>16) & 0xE0) |
             ((argb>>11) & 0x1C) |
             ((argb>> 6) & 0x03) )          );
}

static int
_txPixQuantize_RGB332_D4x4( unsigned long argb, int x, int y, int w)
{
    int d = dithmat[y&3][x&3];
    int n, t;

    n = (int) (((argb >> 16) & 0xFF) * 0x70/255.0f + 0.5f) + d; 
    t = (n>>4)<<5;
    n = (int) (((argb >>  8) & 0xFF) * 0x70/255.0f + 0.5f) + d; 
    t |= (n>>4)<<2;
    n = (int) (((argb      ) & 0xFF) * 0x30/255.0f + 0.5f) + d; 
    t |= (n>>4)<<0;
    return t & 0xFF;
}

static int
_txPixQuantize_RGB332_DErr( unsigned long argb, int x, int y, int w)
{
    static unsigned char a3[] = {0x00,0x24,0x49,0x6d,0x92,0xb6,0xdb,0xff};
    static unsigned char a2[] = {0x00,0x55,0xaa,0xff};
    static int          qr, qg, qb;             // quantized incoming values.
    int                         ir, ig, ib;             // incoming values.
    int                         t;

    ir = (argb >> 16) & 0xFF;   // incoming pixel values.
    ig = (argb >>  8) & 0xFF;
    ib = (argb      ) & 0xFF;

    if (x == 0) qr = qg = qb = 0;

    ir += errR[x] + qr;
    ig += errG[x] + qg;
    ib += errB[x] + qb;

    qr = ir;            // quantized pixel values. 
    qg = ig;            // qR is error from pixel to left, errR is
    qb = ib;            // error from pixel to the top & top left.

    if (qr < 0) qr = 0; if (qr > 255) qr = 255;         // clamp.
    if (qg < 0) qg = 0; if (qg > 255) qg = 255;
    if (qb < 0) qb = 0; if (qb > 255) qb = 255;

    // To RGB332.
    qr = (int) (qr * 0x7ff/255.0f);     qr >>= 8;
    qg = (int) (qg * 0x7ff/255.0f);     qg >>= 8;
    qb = (int) (qb * 0x3ff/255.0f);     qb >>= 8;

    t  = (qr << 5) | (qg << 2) | qb;    // this is the value to be returned.

    // Now dequantize the input, and compute & distribute the errors.
    qr = a3[qr];        qr = ir - qr;
    qg = a3[qg];        qg = ig - qg;
    qb = a2[qb];        qb = ib - qb;

    // 3/8 (=0.375) to the EAST, 3/8 to the SOUTH, 1/4 (0.25) to the SOUTH-EAST.
    errR[x]  = ((x == 0) ? 0 : errR[x]) + ((int) (qr * 0.375f));
    errG[x]  = ((x == 0) ? 0 : errG[x]) + ((int) (qg * 0.375f));
    errB[x]  = ((x == 0) ? 0 : errB[x]) + ((int) (qb * 0.375f));

    errR[x+1] = (int) (qr * 0.250f);
    errG[x+1] = (int) (qg * 0.250f);
    errB[x+1] = (int) (qb * 0.250f);

    qr = (int) (qr * 0.375f);           // Carried to the pixel on the right.
    qg = (int) (qg * 0.375f);
    qb = (int) (qb * 0.375f);

    return t & 0xFF;
}

/* YIQ422 done elsewhere */

static int
_txPixQuantize_A8( unsigned long argb, int x, int y, int w)
{
    return (argb >> 24);
}

static int
_txPixQuantize_I8( unsigned long argb, int x, int y, int w)
{
    return (
    ((int) (((argb >>16) & 0xFF) * .30F +
            ((argb >> 8) & 0xFF) * .59F +
            ((argb     ) & 0xFF) * .11F + 0.5f )) & 0xFF);
}

static int
_txPixQuantize_AI44( unsigned long argb, int x, int y, int w)
{
    return(
        (int)   ((      ((argb>>16) & 0xFF) * .30F +
                        ((argb>> 8) & 0xFF) * .59F +
                        ((argb    ) & 0xFF) * .11F + 0.5f ) * 0.0625f) |
        (int)           ((argb>>24) & 0xF0));
}

static int
_txPixQuantize_AI44_D4x4( unsigned long argb, int x, int y, int w)
{
    int d = dithmat[y&3][x&3];
    int n, t;

    /* Don't dither alpha channel */
    n = (int)   (       ((argb>>16) & 0xFF) * .30F +
                        ((argb>> 8) & 0xFF) * .59F +
                        ((argb    ) & 0xFF) * .11F + 0.5f);
    

    n = (int) (n * 0xF0/255.0f + 0.5f) + d;     
    t = (n>>4);
    t |= (int)  ((argb>>24) & 0xF0);
    return t & 0xFF;
}

static int
_txPixQuantize_AI44_DErr( unsigned long argb, int x, int y, int w)
{
    int ii, t;
    static      int     qi;

    /* Don't dither alpha channel */
    ii = (int)  (       ((argb>>16) & 0xFF) * .30F +
                                ((argb>> 8) & 0xFF) * .59F +
                                ((argb    ) & 0xFF) * .11F + 0.5f);


    if (x == 0) qi = 0;
    ii += errR[x] + qi;
    qi = ii;
    if (qi < 0) qi = 0; if (qi > 255) qi = 255;         // clamp.
    qi = (int) (qi * 0xfff/255.0f);     qi >>= 8;

    t = qi;
    t |= (int)  ((argb>>24) & 0xF0);


    // Now dequantize the input, and compute & distribute the errors.
    qi = (qi << 4) | qi;
    qi = ii - qi;

    // 3/8 (=0.375) to the EAST, 3/8 to the SOUTH, 1/4 (0.25) to the SOUTH-EAST.
    errR[x]  = ((x == 0) ? 0 : errR[x]) + ((int) (qi * 0.375f));
    errR[x+1] = (int) (qi * 0.250f);
    qi = (int) (qi * 0.375f);           // Carried to the pixel on the right.

    return t & 0xFF;
}


static int
_txPixQuantize_ARGB8332 ( unsigned long argb, int x, int y, int w)
{
    return (
                         ((argb>>16) & 0xE0) |
                         ((argb>>11) & 0x1C) |
                         ((argb>> 6) & 0x03) |
                         ((argb>>16) & 0xFF00)          );
}


static int
_txPixQuantize_ARGB8332_D4x4( unsigned long argb, int x, int y, int w)
{
    int d = dithmat[y&3][x&3];
    int n, t;

    n = (int) (((argb >> 16) & 0xFF) * 0x70/255.0f + 0.5f) + d; 
    t = (n>>4)<<5;
    n = (int) (((argb >>  8) & 0xFF) * 0x70/255.0f + 0.5f) + d; 
    t |= (n>>4)<<2;
    n = (int) (((argb      ) & 0xFF) * 0x30/255.0f + 0.5f) + d; 
    t |= (n>>4)<<0;
    t |= ((argb >> 16) & 0xFF00);
    return t & 0xFFFF;
}

static int
_txPixQuantize_ARGB8332_DErr( unsigned long argb, int x, int y, int w)
{
    int t;

    t = _txPixQuantize_RGB332_DErr(argb, x, y, w);
    t |= ((argb >> 16) & 0xFF00);
    return t & 0xFFFF;
}

/* AYIQ8422 done elsewhere */

static int
_txPixQuantize_RGB565( unsigned long argb, int x, int y, int w)
{
    return (
                    ((argb >> 8) & 0xF800) |
                        ((argb >> 5) & 0x07E0) |
                        ((argb >> 3) & 0x001F)          );
}

static int
_txPixQuantize_RGB565_D4x4 ( unsigned long argb, int x, int y, int w)
{
    int d = dithmat[y&3][x&3];
    int n, t;

    n = (int) (((argb >> 16) & 0xFF) * 0x1F0/255.0f + 0.5f) + d;        
    t = (n>>4)<<11;
    n = (int) (((argb >>  8) & 0xFF) * 0x3F0/255.0f + 0.5f) + d;        
    t |= (n>>4)<<5;
    n = (int) (((argb      ) & 0xFF) * 0x1F0/255.0f + 0.5f) + d;        
    t |= (n>>4)<<0;
    return t & 0xFFFF;
}


static int
_txPixQuantize_RGB565_DErr ( unsigned long argb, int x, int y, int w)
{
    static int          qr, qg, qb;             // quantized incoming values.
    int                         ir, ig, ib;             // incoming values.
    int                         t;

    ir = (argb >> 16) & 0xFF;   // incoming pixel values.
    ig = (argb >>  8) & 0xFF;
    ib = (argb      ) & 0xFF;

    if (x == 0) qr = qg = qb = 0;

    ir += errR[x] + qr;
    ig += errG[x] + qg;
    ib += errB[x] + qb;

    qr = ir;            // quantized pixel values. 
    qg = ig;            // qR is error from pixel to left, errR is
    qb = ib;            // error from pixel to the top & top left.

    if (qr < 0) qr = 0; if (qr > 255) qr = 255;         // clamp.
    if (qg < 0) qg = 0; if (qg > 255) qg = 255;
    if (qb < 0) qb = 0; if (qb > 255) qb = 255;

    // To RGB565.
    qr = (int) (qr * 0x1FFF/255.0f);    qr >>= 8;
    qg = (int) (qg * 0x3FFF/255.0f);    qg >>= 8;
    qb = (int) (qb * 0x1FFF/255.0f);    qb >>= 8;

    t  = (qr << 11) | (qg << 5) | qb;   // this is the value to be returned.

    // Now dequantize the input, and compute & distribute the errors.
    qr = (qr << 3) | (qr >> 2);
    qg = (qg << 2) | (qg >> 4);
    qb = (qb << 3) | (qb >> 2);
    qr = ir - qr;
    qg = ig - qg;
    qb = ib - qb;

    // 3/8 (=0.375) to the EAST, 3/8 to the SOUTH, 1/4 (0.25) to the SOUTH-EAST.
    errR[x]  = ((x == 0) ? 0 : errR[x]) + ((int) (qr * 0.375f));
    errG[x]  = ((x == 0) ? 0 : errG[x]) + ((int) (qg * 0.375f));
    errB[x]  = ((x == 0) ? 0 : errB[x]) + ((int) (qb * 0.375f));

    errR[x+1] = (int) (qr * 0.250f);
    errG[x+1] = (int) (qg * 0.250f);
    errB[x+1] = (int) (qb * 0.250f);

    qr = (int) (qr * 0.375f);           // Carried to the pixel on the right.
    qg = (int) (qg * 0.375f);
    qb = (int) (qb * 0.375f);

    return t & 0xFFFF;
}

static int
_txPixQuantize_ARGB1555( unsigned long argb, int x, int y, int w)
{
    return (
                    ((argb >> 9) & 0x7C00) |
                        ((argb >> 6) & 0x03E0) |
                        ((argb >> 3) & 0x001F) |        
                        ((argb >> 24) ? 0x8000 : 0)     );
}

static int
_txPixQuantize_ARGB1555_D4x4 ( unsigned long argb, int x, int y, int w)
{
    int d = dithmat[y&3][x&3];
    int n, t;

    n = (int) (((argb >> 16) & 0xFF) * 0x1F0/255.0f + 0.5f) + d;        
    t = (n>>4)<<10;
    n = (int) (((argb >>  8) & 0xFF) * 0x1F0/255.0f + 0.5f) + d;        
    t |= (n>>4)<<5;
    n = (int) (((argb      ) & 0xFF) * 0x1F0/255.0f + 0.5f) + d;        
    t |= (n>>4)<<0;
    t |= ((argb >> 24) ? 0x8000 : 0);
    return t & 0xFFFF;
}

static int
_txPixQuantize_ARGB1555_DErr ( unsigned long argb, int x, int y, int w)
{
    static int          qr, qg, qb;             // quantized incoming values.
    int                 ir, ig, ib;             // incoming values.
    int                 t;

    ir = (argb >> 16) & 0xFF;   // incoming pixel values.
    ig = (argb >>  8) & 0xFF;
    ib = (argb      ) & 0xFF;

    if (x == 0) qr = qg = qb = 0;

    ir += errR[x] + qr;
    ig += errG[x] + qg;
    ib += errB[x] + qb;

    qr = ir;            // quantized pixel values. 
    qg = ig;            // qR is error from pixel to left, errR is
    qb = ib;            // error from pixel to the top & top left.

    if (qr < 0) qr = 0; if (qr > 255) qr = 255;         // clamp.
    if (qg < 0) qg = 0; if (qg > 255) qg = 255;
    if (qb < 0) qb = 0; if (qb > 255) qb = 255;

    // To RGB565.
    qr = (int) (qr * 0x1FFF/255.0f);    qr >>= 8;
    qg = (int) (qg * 0x1FFF/255.0f);    qg >>= 8;
    qb = (int) (qb * 0x1FFF/255.0f);    qb >>= 8;

    t  = (qr << 10) | (qg << 5) | qb;   // this is the value to be returned.
    t |= ((argb >> 24) ? 0x8000 : 0);

    // Now dequantize the input, and compute & distribute the errors.
    qr = (qr << 3) | (qr >> 2);
    qg = (qg << 3) | (qg >> 2);
    qb = (qb << 3) | (qb >> 2);
    qr = ir - qr;
    qg = ig - qg;
    qb = ib - qb;

    // 3/8 (=0.375) to the EAST, 3/8 to the SOUTH, 1/4 (0.25) to the SOUTH-EAST.
    errR[x]  = ((x == 0) ? 0 : errR[x]) + ((int) (qr * 0.375f));
    errG[x]  = ((x == 0) ? 0 : errG[x]) + ((int) (qg * 0.375f));
    errB[x]  = ((x == 0) ? 0 : errB[x]) + ((int) (qb * 0.375f));

    errR[x+1] = (int) (qr * 0.250f);
    errG[x+1] = (int) (qg * 0.250f);
    errB[x+1] = (int) (qb * 0.250f);

    qr = (int) (qr * 0.375f);           // Carried to the pixel on the right.
    qg = (int) (qg * 0.375f);
    qb = (int) (qb * 0.375f);

    return t & 0xFFFF;
}

static int
_txPixQuantize_ARGB4444 (unsigned long argb, int x, int y, int w)
{
    return (
                    ((argb >> 12) & 0x0F00) |
                        ((argb >>  8) & 0x00F0) |
                        ((argb >>  4) & 0x000F) |       
                        ((argb >> 16) & 0xF000) );
}

static int
_txPixQuantize_ARGB4444_D4x4 (unsigned long argb, int x, int y, int w)
{
    int d = dithmat[y&3][x&3];
    int n, t;

    n = (int) (((argb >> 16) & 0xFF) * 0xF0/255.0f + 0.5f) + d; 
    t = (n>>4)<<8;
    n = (int) (((argb >>  8) & 0xFF) * 0xF0/255.0f + 0.5f) + d; 
    t |= (n>>4)<<4;
    n = (int) (((argb      ) & 0xFF) * 0xF0/255.0f + 0.5f) + d; 
    t |= (n>>4)<<0;
    t |= (argb >> 16) & 0xF000;
    return t & 0xFFFF;
}

static int
_txPixQuantize_ARGB4444_DErr (unsigned long argb, int x, int y, int w)
{
    static int          qr, qg, qb;             // quantized incoming values.
    int                         ir, ig, ib;             // incoming values.
    int                         t;

    ir = (argb >> 16) & 0xFF;   // incoming pixel values.
    ig = (argb >>  8) & 0xFF;
    ib = (argb      ) & 0xFF;

    if (x == 0) qr = qg = qb = 0;

    ir += errR[x] + qr;
    ig += errG[x] + qg;
    ib += errB[x] + qb;

    qr = ir;            // quantized pixel values. 
    qg = ig;            // qR is error from pixel to left, errR is
    qb = ib;            // error from pixel to the top & top left.

    if (qr < 0) qr = 0; if (qr > 255) qr = 255;         // clamp.
    if (qg < 0) qg = 0; if (qg > 255) qg = 255;
    if (qb < 0) qb = 0; if (qb > 255) qb = 255;

    // To RGB565.
    qr = (int) (qr * 0xFFF/255.0f);     qr >>= 8;
    qg = (int) (qg * 0xFFF/255.0f);     qg >>= 8;
    qb = (int) (qb * 0xFFF/255.0f);     qb >>= 8;

    t  = (qr <<  8) | (qg << 4) | qb;   // this is the value to be returned.
    t |= (argb >> 16) & 0xF000;

    // Now dequantize the input, and compute & distribute the errors.
    qr = (qr << 4) | (qr >> 0);
    qg = (qg << 4) | (qg >> 0);
    qb = (qb << 4) | (qb >> 0);
    qr = ir - qr;
    qg = ig - qg;
    qb = ib - qb;

    // 3/8 (=0.375) to the EAST, 3/8 to the SOUTH, 1/4 (0.25) to the SOUTH-EAST.
    errR[x]  = ((x == 0) ? 0 : errR[x]) + ((int) (qr * 0.375f));
    errG[x]  = ((x == 0) ? 0 : errG[x]) + ((int) (qg * 0.375f));
    errB[x]  = ((x == 0) ? 0 : errB[x]) + ((int) (qb * 0.375f));

    errR[x+1] = (int) (qr * 0.250f);
    errG[x+1] = (int) (qg * 0.250f);
    errB[x+1] = (int) (qb * 0.250f);

    qr = (int) (qr * 0.375f);           // Carried to the pixel on the right.
    qg = (int) (qg * 0.375f);
    qb = (int) (qb * 0.375f);

    return t & 0xFFFF;
}

static int
_txPixQuantize_AI88( unsigned long argb, int x, int y, int w)
{
    return (
    (((int) (((argb >>16) & 0xFF) * .30F +
                ((argb >> 8) & 0xFF) * .59F +
                ((argb     ) & 0xFF) * .11F + 0.5f )) & 0xFF) |

                ((argb >>16) & 0xFF00)                  );
}

static void 
_txCalcYUVFromRGB(FxU32 argb, long *y, long *u, long *v)
{
        float red, green, blue;

        red =   (float)((argb >> 16) & 0xFF);
        green = (float)((argb >>  8) & 0xFF);
        blue =  (float)(argb & 0xFF);

        // Calculate YUV using RGB.  Add 0.5 to each for rounding.

        // ImageMagick method
        /*
        *y = (long)( 0.29900 * red + 0.58700 * green + 0.11400 * blue );
        *u = (long)(-0.14740 * red - 0.28950 * green + 0.43690 * blue + 128.5);
        *v = (long)( 0.61500 * red - 0.51500 * green - 0.10000 * blue + 128.5);
        */

        // MWP method
        /*
        *y = (long)((77.0 / 256.0) * red + (150.0 / 256.0) * green + (29.0 / 256.0) * blue + 0.5);
        *u = (long)(128 - (44.0 / 256.0) * red - (87.0 / 256.0) * green + (131.0 / 256.0) * blue + 0.5);        
        *v = (long)(128 + (131.0 / 256.0) * red - (110.0 / 256.0) * green - (21.0 / 256.0) * blue + 0.5);
        */

        // Method from solving dequantizer equations
        *y = (long)( .25695 * red + .50442 * green + .09773 * blue + 16.5);
        *u = (long)(-.14821 * red - .29095 * green + .43917 * blue + 128.5);
        *v = (long)( .43917 * red - .36788 * green - .07128 * blue + 128.5);

        // Clamp YUV

        if (*y > 235)
        {
                *y = 235;       
        }
        else if (*y < 16)
        {
                *y = 16;        
        }
        
        if (*u > 240)
        {
                *u = 240;       
        }
        else if (*u < 16)
        {
                *u = 16;        
        }
        
        if (*v > 240)
        {
                *v = 240;       
        }
        else if (*v < 16)
        {
                *v = 16;        
        }
}

void 
_txImgQuantizeYUV(FxU16 *dst, const FxU32 *src, int w, int h, FxU32 format)
{
        int k = w * h;
    int i, j;
        unsigned long Y[2], U[2], V[2];
        unsigned long avgU, avgV;
        long tmpY, tmpU, tmpV;
    const FxU32 *localSrc = NULL;

    /* surface size must be a multiple of the 2x1 block size */
    if (w & 0x01UL) {
       src = localSrc = _txDuplicateData(src, &w, &h, 1, 0);
    }

        for (i = 0; i < k; i += 2)
        {
                // Process 2 texels at a time

                for (j = 0; j < 2; j++)
                {
                        _txCalcYUVFromRGB(*src, &tmpY, &tmpU, &tmpV);

            src++;

                        Y[j] = (unsigned long) tmpY;
                        U[j] = (unsigned long) tmpU;
                        V[j] = (unsigned long) tmpV;
                }

                avgU = (unsigned long) ((U[0] + U[1] + 1) / 2.0);  // add 1 to round
                avgV = (unsigned long) ((V[0] + V[1] + 1) / 2.0);  // add 1 to round

                if ( format == GR_TEXFMT_YUYV_422 )
                {
                        // First texel

                        *dst++ = (FxU16)((avgU << 8) | Y[0]);

                        // Second texel

                        *dst++ = (FxU16)((avgV << 8) | Y[1]);
                }
                else 
                {       
                        // GR_TEXFMT_UYVY_422 format

                        // First texel

                        *dst++ = (FxU16)((Y[0] << 8) | avgU);

                        // Second texel

                        *dst++ = (FxU16)((Y[1] << 8) | avgV);
                }
        }

    if ( localSrc )
        free((void *)localSrc);
}

void 
_txImgQuantizeAYUV(FxU32 *dst, FxU32 *src, int w, int h)
{
    int i, k;
        long y, u, v;

        k = w * h;

        for (i = 0; i < k; i++)
        {
                _txCalcYUVFromRGB(*src, &y, &u, &v);

                // Output the AYUV texel
        
                *dst++ = (*src++ & 0xFF000000) | ( y << 16 ) | ( u << 8 ) | v;
        }
}

void
sst2FXT1Encode4bpp(int *data, int width, int height, int* encoded);


static void
_txImgQuantizeFXT1(FxU32 *dst, const FxU32 *src, int w, int h, FxU32 format, FxU32 dither)
{
    const FxU32 *localSrc = NULL;

    /* surface size must be a multiple of the 8x4 block size */
    if (((w & 0x07UL) != 0) || ((h & 0x03UL) != 0)) {
       src = localSrc = _txDuplicateData(src, &w, &h, 3, 2);
    }

    sst2FXT1Encode4bpp((int *)src, w, h, (int *)dst);

    if ( localSrc )
       free((void *)localSrc);
}

static FxU32
_txColorBlend(const FxU32 c0, const FxU32 c1, 
              const FxU32 r, const FxU32 g, const FxU32 b,
              const float blendFrac)
{
  const FxU32
    maskR = (0xFFFFFFFFUL >> (32UL - r)),
    maskG = (0xFFFFFFFFUL >> (32UL - g)),
    maskB = (0xFFFFFFFFUL >> (32UL - b));
  const float
    r0 = (float)((c0 >> (g + b)) & maskR),
    g0 = (float)((c0 >> (0 + b)) & maskG),
    b0 = (float)((c0 >> (0 + 0)) & maskB),
    r1 = (float)((c1 >> (g + b)) & maskR),
    g1 = (float)((c1 >> (0 + b)) & maskG),
    b1 = (float)((c1 >> (0 + 0)) & maskB);
  float
    blendR = (((1.0f - blendFrac) * r0) + (blendFrac * r1)),
    blendG = (((1.0f - blendFrac) * g0) + (blendFrac * g1)),
    blendB = (((1.0f - blendFrac) * b0) + (blendFrac * b1));

  return (((FxU32)blendR << (g + b)) |
          ((FxU32)blendG << (0 + b)) |
          ((FxU32)blendB << (0 + 0)));
}

static void
_txImgEncodeBlock(FxU16* dst, 
                  const FxU32* src, int srcW, int srcH,
                  int blockS, int blockT)
{
  int 
    i, j;
  FxU32
    blockAlphaSum = 0x00UL;
  FxU32
    texelBlock[4][4],
    minTexel = 0xFFFFFFFFUL,
    maxTexel = 0x00000000UL;

#define RGB_8888_565(__rgb8888) \
  ((FxU16)((((((FxU32)(__rgb8888)) >> (0x00UL + 0x03UL)) & 0x1FUL) << 0x00UL) | \
           (((((FxU32)(__rgb8888)) >> (0x08UL + 0x02UL)) & 0x3FUL) << 0x05UL) | \
           (((((FxU32)(__rgb8888)) >> (0x10UL + 0x03UL)) & 0x1FUL) << 0x0BUL)))

  /* Find the min and max color for this interpolation and if this
   * block has alpha values for the silly color0 < color1 thing.  
   */
  for(i = 0; i < 4; i++) {
    for(j = 0; j < 4; j++) {
      const FxU32 
        rawColor = *(src + ((blockT + i) * srcW) + (blockS + j)),
        rawAlpha = (rawColor >> 24UL);
      const FxU16
        convertedColor = RGB_8888_565(rawColor);

      /* Get running block sum of the alpha's */
      blockAlphaSum += rawAlpha;

      /* Convert the block to 565 in a sort of brain dead way
       * keeping track of the block local min and max.  
       */
      texelBlock[i][j] = (rawAlpha << 24UL) | convertedColor;
      if (convertedColor < minTexel) minTexel = convertedColor;
      if (convertedColor > maxTexel) maxTexel = convertedColor;
    }
  }

  /* Do we have varying alpha? Do the whacked 3 color encoding,
   * otherwise on to do the 4 color encoding.  
   *
   * Currently, the 1 bit alpha encoding sets teh alpha threshold
   * at 1/4 the average alpha for the entire block. The spec does
   * not seem to indicate an actual threshold for the encoding, I
   * guess this assumes taht you will be analyzing the entire
   * texture at once which I'm way to lazy to do.
   */
  {
    FxU16 
      texelData[2] = { 0, 0 };
    
    if (blockAlphaSum == (0xFFUL << 0x04UL)) {
      const FxU32
        c2TestVal   = _txColorBlend(maxTexel, minTexel, 5, 6, 5, 1.0f / 4.0f),
        midColorVal = _txColorBlend(maxTexel, minTexel, 5, 6, 5, 0.5f),
        c3TestVal   = _txColorBlend(maxTexel, minTexel, 5, 6, 5, 3.0f / 4.0f);

      /* color0 > color1 == 4 color */
      dst[0] = (FxU16)maxTexel;
      dst[1] = (FxU16)minTexel;
          
      for(i = 0; i < 4; i++) {
        for(j = 0; j < 4; j++) {
          const FxU32
            testTexel = (texelBlock[i][j] & 0xFFFFUL);
          FxU32
            bitVal;

          if (testTexel > c2TestVal)        bitVal = 0x00UL;
          else if (testTexel > midColorVal) bitVal = 0x02UL;
          else if (testTexel > c3TestVal)   bitVal = 0x03UL;
          else                              bitVal = 0x01UL;

          texelData[i >> 1] |= (bitVal << (((i & 0x01UL) << 0x03UL) + (j << 0x01UL)));
        }
      }
    } else {
      const FxU32
        alphaThresh = ((blockAlphaSum >> 0x04UL) >> 2UL),
        c2TestVal   = _txColorBlend(minTexel, maxTexel, 5, 6, 5, 1.0f / 3.0f),
        c3TestVal   = _txColorBlend(minTexel, maxTexel, 5, 6, 5, 2.0f / 3.0f);

      /* color0 < color1 == 3 color + transparent */
      dst[0] = (FxU16)minTexel;
      dst[1] = (FxU16)maxTexel;
          
      for(i = 0; i < 4; i++) {
        for(j = 0; j < 4; j++) {
          const FxU32
            convertedColor = texelBlock[i][j],
            testTexel      = (convertedColor & 0xFFFFUL),
            testAlpha      = (convertedColor >> 24UL);
          FxU32
            bitVal;

          if (testAlpha < alphaThresh)    bitVal = 0x03UL;
          else if (testTexel > c3TestVal) bitVal = 0x01UL;
          else if (testTexel > c2TestVal) bitVal = 0x02UL;
          else                            bitVal = 0x00UL;

          texelData[i >> 1] |= (bitVal << (((i & 0x01UL) << 0x03UL) + (j << 0x01UL)));
        }
      }          
    }

    dst[2] = texelData[0];
    dst[3] = texelData[1];
  }
}

static void
_txImgQuantizeDXT1(FxU16* dst, const FxU32* src,
                   FxU32 format, 
                   int w, int h)
{
  int s, t;
  const FxU32 *localSrc = NULL;

  /* surface size must be a multiple of the 4x4 block size */
  if (((w & 0x03UL) != 0) || ((h & 0x03UL) != 0)) {
    src = localSrc = _txDuplicateData(src, &w, &h, 2, 2);
  }

  for(t = 0; t < h; t += 4) {
    for(s = 0; s < w; s += 4) {
      _txImgEncodeBlock(dst, 
                        src, w, h,
                        s, t);
      // convert the data so that its in little endian format
#ifdef ENDB
      HWC_SWAP16(dst);
      HWC_SWAP16(dst+2);
#endif

      dst += 4;
    }
  }

  if ( localSrc )
    free((void *)localSrc);
}

static void
_txImgQuantizeDXAlpha3(FxU16* dst, const FxU32* src,
                       FxU32 format, 
                       int w, int h)
{
  int s, t;
  const FxU32 *localSrc = NULL;

  /* surface size must be a multiple of the 4x4 block size */
  if (((w & 0x03UL) != 0) || ((h & 0x03UL) != 0)) {
    src = localSrc = _txDuplicateData(src, &w, &h, 2, 2);
  }

  for(t = 0; t < h; t += 4) {
    for(s = 0; s < w; s += 4) {
      int
        i, j;
      FxBool
        minRangeP = FXFALSE,
        maxRangeP = FXFALSE;
      FxU32
        minAlpha = 0x100UL,
        maxAlpha = 0x000UL,
        srcColors[16];

      /* Scan for the min and max alpha values. */
      for(i = 0; i < 4; i++) {
        for(j = 0; j < 4; j++) {
          const FxU32
            rawAlpha = *(src + ((t + i) * w) + (s + j)) >> 24UL;

          minRangeP |= (rawAlpha == 0x00UL);
          if ((rawAlpha != 0x00UL) && (rawAlpha < minAlpha)) minAlpha = rawAlpha;

          maxRangeP |= (rawAlpha == 0xFFUL);
          if ((rawAlpha != 0xFFUL) && (rawAlpha > maxAlpha)) maxAlpha = rawAlpha;
        }
      }

      /* Encode the alpha block. If we have both 0 and 255 values then
       * we use the 6-alpha block encoding otherwise we use the
       * 8-alpha block encoding.  
       */
      {
        FxU64
          alphaData;

        if (minRangeP && maxRangeP) {
          const FxU32
            testA0 = _txColorBlend(minAlpha, maxAlpha, 0, 0, 8, 1.0f / 6.0f),
            testA2 = _txColorBlend(minAlpha, maxAlpha, 0, 0, 8, 2.0f / 6.0f),
            testA3 = _txColorBlend(minAlpha, maxAlpha, 0, 0, 8, 3.0f / 6.0f),
            testA4 = _txColorBlend(minAlpha, maxAlpha, 0, 0, 8, 4.0f / 6.0f),
            testA5 = _txColorBlend(minAlpha, maxAlpha, 0, 0, 8, 5.0f / 6.0f);
            
          FX_SET64(alphaData, 0x00UL, (maxAlpha << 0x08UL) | minAlpha);
            
          for(i = 0; i < 4; i++) {
            for(j = 0; j < 4; j++) {
              FxU32
                rawColor = *(src + ((t + i) * w) + (s + j)),
                rawAlpha = (rawColor >> 24UL);
              FxU64
                bitVal;
                
              if (rawAlpha == 0x00)        FX_SET64(bitVal, 0x00UL, 0x06UL);
              else if (rawAlpha == 0xFFUL) FX_SET64(bitVal, 0x00UL, 0x07UL);
              else if (rawAlpha < testA0)  FX_SET64(bitVal, 0x00UL, 0x00UL);
              else if (rawAlpha < testA2)  FX_SET64(bitVal, 0x00UL, 0x02UL);
              else if (rawAlpha < testA3)  FX_SET64(bitVal, 0x00UL, 0x03UL);
              else if (rawAlpha < testA4)  FX_SET64(bitVal, 0x00UL, 0x04UL);
              else if (rawAlpha < testA5)  FX_SET64(bitVal, 0x00UL, 0x05UL);
              else                         FX_SET64(bitVal, 0x00UL, 0x01UL);

              alphaData = FX_OR64(alphaData, FX_SHL64(bitVal, (((i << 0x02UL) + j) << 0x01UL) + 16UL));
              
              /* If we're in dxt4 mode then we multiply the color by the alpha
               * value otherwise we just pass the original color value. 
               */
              if (format == GR_TEXFMT_ARGB_CMP_DXT4) {
                rawColor = _txColorBlend(0x00UL, rawColor,
                                         8, 8, 8,
                                         (rawAlpha / 255.0f));
              }
              
              /* We also set the alpha value for the encoding to be full
               * so that it does not do the alpha transparency thing.  
               */
              srcColors[(i << 2UL) + j] = (0xFF000000UL | rawColor);
            }
          }
        } else {
          /* Merge the boolean-ness since we don't have both */
          if (minRangeP) minAlpha = 0x00UL;
          if (maxRangeP) maxAlpha = 0xFFUL;

          {
            const FxU32
              testA0 = _txColorBlend(maxAlpha, minAlpha, 0, 0, 8, 1.0f / 8.0f),
              testA2 = _txColorBlend(maxAlpha, minAlpha, 0, 0, 8, 2.0f / 8.0f),
              testA3 = _txColorBlend(maxAlpha, minAlpha, 0, 0, 8, 3.0f / 8.0f),
              testA4 = _txColorBlend(maxAlpha, minAlpha, 0, 0, 8, 4.0f / 8.0f),
              testA5 = _txColorBlend(maxAlpha, minAlpha, 0, 0, 8, 5.0f / 8.0f),
              testA6 = _txColorBlend(maxAlpha, minAlpha, 0, 0, 8, 6.0f / 8.0f),
              testA7 = _txColorBlend(maxAlpha, minAlpha, 0, 0, 8, 7.0f / 8.0f);

            FX_SET64(alphaData, 0x00UL, (minAlpha << 0x08UL) | maxAlpha);

            for(i = 0; i < 4; i++) {
              for(j = 0; j < 4; j++) {
                FxU32
                  rawColor = *(src + ((t + i) * w) + (s + j)),
                  rawAlpha = (rawColor >> 24UL);
                FxU64
                  bitVal;
              
                if (rawAlpha > testA0)      FX_SET64(bitVal, 0x00UL, 0x00UL);
                else if (rawAlpha > testA2) FX_SET64(bitVal, 0x00UL, 0x02UL);
                else if (rawAlpha > testA3) FX_SET64(bitVal, 0x00UL, 0x03UL);
                else if (rawAlpha > testA4) FX_SET64(bitVal, 0x00UL, 0x04UL);
                else if (rawAlpha > testA5) FX_SET64(bitVal, 0x00UL, 0x05UL);
                else if (rawAlpha > testA6) FX_SET64(bitVal, 0x00UL, 0x06UL);
                else if (rawAlpha > testA7) FX_SET64(bitVal, 0x00UL, 0x07UL);
                else                        FX_SET64(bitVal, 0x00UL, 0x01UL);

                alphaData = FX_OR64(alphaData, FX_SHL64(bitVal, (((i << 0x02UL) + j) << 0x01UL) + 16UL));
              
                /* If we're in dxt4 mode then we multiply the color by the alpha
                 * value otherwise we just pass the original color value. 
                 */
                if (format == GR_TEXFMT_ARGB_CMP_DXT4) {
                  rawColor = _txColorBlend(0x00UL, rawColor,
                                           8, 8, 8,
                                           (rawAlpha / 255.0f));
                }
              
                /* We also set the alpha value for the encoding to be full
                 * so that it does not do the alpha transparency thing.  
                 */
                srcColors[(i << 2UL) + j] = (0xFF000000UL | rawColor);
              }
            }
          }
        }

        {
          const FxU8*
            alphaSrc = (const FxU8*)&alphaData;
          FxU8*
            alphaDst = (FxU8*)dst;

          for(i = 0; i < 8; i++) *alphaDst++ = *alphaSrc++;
        }
      }
      // convert the data so that its in little endian format
#ifdef ENDB
      HWC_SWAP8(dst);
      HWC_SWAP8(dst+2);
#endif

      dst += 4;

      /* Encode the color block w/o the transparency option */
      _txImgEncodeBlock(dst, 
                        srcColors, 4, 4,
                        0, 0);
#ifdef ENDB
      HWC_SWAP16(dst);
      HWC_SWAP16(dst+2);
#endif

      dst += 4;
    }
  }

  if ( localSrc )
    free((void *)localSrc);
}

static void
_txImgQuantizeDXAlpha4(FxU16* dst, const FxU32* src,
                       FxU32 format, 
                       int w, int h)
{
  int s, t;
  const FxU32 *localSrc = NULL;

  /* surface size must be a multiple of the 4x4 block size */
  if (((w & 0x03UL) != 0) || ((h & 0x03UL) != 0)) {
    src = localSrc = _txDuplicateData(src, &w, &h, 2, 2);
  }

  for(t = 0; t < h; t += 4) {
    for(s = 0; s < w; s += 4) {
      int
        i, j;
      FxU32
        srcColors[16];

      /* Encode the alpha block. */
      for(i = 0; i < 4; i++) {
        FxU16
          alphaVal = 0;
        
        for(j = 0; j < 4; j++) {
          FxU32
            rawColor = *(src + ((t + i) * w) + (s + j)),
            rawAlpha = (rawColor >> 24UL);

          /* We're just going to take the top 4 bits of the whole
           * alpha value as the encoding.  
           */
          alphaVal |= ((rawAlpha >> 0x04UL) << (j << 0x02UL));

          /* If we're in dxt2 mode then we multiply the color by the alpha
           * value otherwise we just pass the original color value. 
           */
          if (format == GR_TEXFMT_ARGB_CMP_DXT2) {
            rawColor = _txColorBlend(0x00UL, rawColor,
                                     8, 8, 8,
                                     (rawAlpha / 255.0f));
          }

          /* We also set the alpha value for the encoding to be full
           * so that it does not do the alpha transparency thing.  
           */
          srcColors[(i << 2UL) + j] = (0xFF000000UL | rawColor);
        }

        dst[i] = alphaVal;
      }
      // convert the data so that its in little endian format
#ifdef ENDB
      HWC_SWAP16(dst);
      HWC_SWAP16(dst+2);
#endif

      dst += 4;

      /* Encode the color block w/o the transparency option */
      _txImgEncodeBlock(dst, 
                        srcColors, 4, 4,
                        0, 0);
#ifdef ENDB
      HWC_SWAP16(dst);
      HWC_SWAP16(dst+2);
#endif

      dst += 4;
    }
  }

  if ( localSrc )
    free((void *)localSrc);
}

void
txImgQuantize(char *dst, char *src, 
               int w, int h, 
               FxU32 format, FxU32 dither)
{
    int (*quantizer)(unsigned long argb, int x, int y, int w);
    int         x, y;

    dither &= TX_DITHER_MASK;

    if (dither == TX_DITHER_ERR) { // Error diffusion, floyd-steinberg
        int             i;

        // Clear error diffusion accumulators.
        for (i=0; i<w; i++) errR[i] = errG[i] = errB[i] = 0;

        switch(format) {
        case GR_TEXFMT_RGB_332:         quantizer = _txPixQuantize_RGB332_DErr; 
                                                                break;
        case GR_TEXFMT_A_8:             quantizer = _txPixQuantize_A8;                  
                                                                break;
        case GR_TEXFMT_I_8:             quantizer = _txPixQuantize_I8;
                                                                break;
        case GR_TEXFMT_AI_44:           quantizer = _txPixQuantize_AI44_DErr;
                                                                break;
        case GR_TEXFMT_ARGB_8332:       quantizer = _txPixQuantize_ARGB8332_DErr;
                                                                break;
        case GR_TEXFMT_RGB_565:         quantizer = _txPixQuantize_RGB565_DErr; 
                                                                break;
        case GR_TEXFMT_ARGB_1555:       quantizer = _txPixQuantize_ARGB1555_DErr;
                                                                break;
        case GR_TEXFMT_ARGB_4444:       quantizer = _txPixQuantize_ARGB4444_DErr;
                                                                break;
        case GR_TEXFMT_AI_88:           quantizer = _txPixQuantize_AI88;
                                                                break;

        default: txPanic("Unable to dither this format\n");                         break;
        }
    }else if (dither == TX_DITHER_4x4) { // 4x4 ordered dithering.

        switch(format) {
        case GR_TEXFMT_RGB_332:         quantizer = _txPixQuantize_RGB332_D4x4; 
                                                                break;
        case GR_TEXFMT_A_8:             quantizer = _txPixQuantize_A8;                  
                                                                break;
        case GR_TEXFMT_I_8:             quantizer = _txPixQuantize_I8;                          
                                                                break;
        case GR_TEXFMT_AI_44:           quantizer = _txPixQuantize_AI44_D4x4;           
                                                                break;
        case GR_TEXFMT_ARGB_8332:       quantizer = _txPixQuantize_ARGB8332_D4x4;       
                                                                break;
        case GR_TEXFMT_RGB_565:         quantizer = _txPixQuantize_RGB565_D4x4; 
                                                                break;
        case GR_TEXFMT_ARGB_1555:       quantizer = _txPixQuantize_ARGB1555_D4x4;   
                                                                break;
        case GR_TEXFMT_ARGB_4444:       quantizer = _txPixQuantize_ARGB4444_D4x4;       
                                                                break;
        case GR_TEXFMT_AI_88:           quantizer = _txPixQuantize_AI88;                        
                                                                break;

        default: txPanic("Unable to dither this format\n");                         
                                                                break;
        }
    } else {            // No dithering.

        switch(format) {
        case GR_TEXFMT_RGB_332:         quantizer = _txPixQuantize_RGB332;              
          break;
        case GR_TEXFMT_A_8:             quantizer = _txPixQuantize_A8;          
          break;
        case GR_TEXFMT_I_8:             quantizer = _txPixQuantize_I8;                  
          break;
        case GR_TEXFMT_AI_44:           quantizer = _txPixQuantize_AI44;                
          break;
        case GR_TEXFMT_ARGB_8332:       quantizer = _txPixQuantize_ARGB8332;    
          break;
        case GR_TEXFMT_RGB_565:         quantizer = _txPixQuantize_RGB565;              
          break;
        case GR_TEXFMT_ARGB_1555:       quantizer = _txPixQuantize_ARGB1555;        
          break;
        case GR_TEXFMT_ARGB_4444:       quantizer = _txPixQuantize_ARGB4444;    
          break;
        case GR_TEXFMT_AI_88:           quantizer = _txPixQuantize_AI88;                
          break;
        case GR_TEXFMT_ARGB_CMP_FXT1:
        case GR_TEXFMT_ARGB_CMP_DXT1:
        case GR_TEXFMT_ARGB_CMP_DXT2:
        case GR_TEXFMT_ARGB_CMP_DXT3:
        case GR_TEXFMT_ARGB_CMP_DXT4:
        case GR_TEXFMT_ARGB_CMP_DXT5:
        case GR_TEXFMT_ARGB_8888:
        case GR_TEXFMT_YUYV_422:
        case GR_TEXFMT_UYVY_422:
        case GR_TEXFMT_AYUV_444:        
        case GR_TEXFMT_RGB_888:                 quantizer = NULL;
          break;

        default: txPanic("Bad texture format in txQuantize()\n");                 
          break;
        }
    }

    switch (format ) {
    // 8 bit dst
    case GR_TEXFMT_RGB_332:
    case GR_TEXFMT_YIQ_422:
    case GR_TEXFMT_ALPHA_8:
    case GR_TEXFMT_INTENSITY_8:
    case GR_TEXFMT_ALPHA_INTENSITY_44:
      for (y=0; y<h; y++) {
        for (x=0; x<w; x++) {
          *dst++ = (*quantizer)(*(unsigned long *)src, x, y, w);
          src += 4;
        }
      }
      break;

    // 16 bit dst.
    case GR_TEXFMT_ARGB_8332:
    case GR_TEXFMT_AYIQ_8422:
    case GR_TEXFMT_RGB_565:
    case GR_TEXFMT_ARGB_1555:
    case GR_TEXFMT_ARGB_4444:
    case GR_TEXFMT_ALPHA_INTENSITY_88:
    case GR_TEXFMT_AP_88:
    case GR_TEXFMT_RSVD2:
      {
        unsigned short *dst16 = (unsigned short *) dst;
        
        for (y=0; y<h; y++) {
          for (x=0; x<w; x++) {
            *dst16++ = (*quantizer)(*(unsigned long *)src, x, y, w);
            src += 4;
          }
        }
      }
    break;
    // sst2 specific dst.
    case GR_TEXFMT_YUYV_422:
    case GR_TEXFMT_UYVY_422:
      _txImgQuantizeYUV((FxU16 *) dst, (FxU32 *)src, w, h, format);
      break;
    case GR_TEXFMT_ARGB_CMP_FXT1:
      _txImgQuantizeFXT1((FxU32 *)dst, (FxU32 *)src, w, h, format, dither);
      break;
    case GR_TEXFMT_AYUV_444:
      _txImgQuantizeAYUV((FxU32 *) dst, (FxU32 *)src, w, h);
      break;
    case GR_TEXFMT_ARGB_CMP_DXT1:
      _txImgQuantizeDXT1((FxU16*)dst, (FxU32*)src,
                         format,
                         w, h);
      break;
      
    case GR_TEXFMT_ARGB_CMP_DXT2:
    case GR_TEXFMT_ARGB_CMP_DXT3:
      _txImgQuantizeDXAlpha4((FxU16*)dst, (FxU32*)src,
                             format, 
                             w, h);
      break;
      
    case GR_TEXFMT_ARGB_CMP_DXT4:
    case GR_TEXFMT_ARGB_CMP_DXT5:
      _txImgQuantizeDXAlpha3((FxU16*)dst, (FxU32*)src,
                             format, 
                             w, h);
      break;
    }
}

/*
 * Reduce an ARGB8888 image to 16bits or 8bits/pixel, possibly dithering
 * the resulting image using either ordered 4x4 or error-diffusion dithering.
 *
 * For the special cases of YIQ image, you also get the choice of 2 different
 * quality levels in each of the compression cases.
 */
void    
txMipQuantize(TxMip *pxMip, TxMip *txMip, int format, FxU32 dither, FxU32 compression)
{
    int         i, w, h;

    if( txVerbose )
      {
        printf("Quantizing: (to %s)", Format_Name[format]);
      }
    pxMip->format = format;
    pxMip->width  = txMip->width;
    pxMip->height = txMip->height;

    switch(format) {
    // Special cases.
    case GR_TEXFMT_YIQ_422:
    case GR_TEXFMT_AYIQ_8422:
      if( txVerbose ) printf(".\n");
      txMipNcc(pxMip, txMip, format, dither, compression);
      return;

    case GR_TEXFMT_ARGB_8888: 
      // Copy source to destination, and be done.
      if( txVerbose ) printf(".\n");
      memcpy(pxMip->data[0], txMip->data[0], txMip->size);
      return;

    case GR_TEXFMT_P_8:
    case GR_TEXFMT_AP_88:
      if( txVerbose ) printf(".\n");
      txMipPal256(pxMip, txMip, format, dither, compression);
      return;

    case GR_TEXFMT_P_8_6666:
      txMipPal6666(pxMip, txMip, format, dither, compression);
      return;
      
    // Normal cases
    case GR_TEXFMT_A_8: 
    case GR_TEXFMT_I_8: 
    case GR_TEXFMT_AI_44: 
    case GR_TEXFMT_RGB_332:
    case GR_TEXFMT_RGB_565: 
    case GR_TEXFMT_ARGB_8332: 
    case GR_TEXFMT_ARGB_1555: 
    case GR_TEXFMT_ARGB_4444:
    case GR_TEXFMT_AI_88:
    case GR_TEXFMT_YUYV_422:
    case GR_TEXFMT_UYVY_422:
    case GR_TEXFMT_ARGB_CMP_FXT1:
    case GR_TEXFMT_AYUV_444:
    case GR_TEXFMT_ARGB_CMP_DXT1:
    case GR_TEXFMT_ARGB_CMP_DXT2:
    case GR_TEXFMT_ARGB_CMP_DXT3:
    case GR_TEXFMT_ARGB_CMP_DXT4:
    case GR_TEXFMT_ARGB_CMP_DXT5:
      break;

    default:
      txPanic("Bad data format in Quantize\n");
      return;
    }

    // We deal with rest of them here one mipmap level at a time.

    w = txMip->width;
    h = txMip->height;

    for (i=0; i< pxMip->depth; i++) {
        if( txVerbose )
          printf(" %dx%d", w, h);

        txImgQuantize(pxMip->data[i], txMip->data[i], 
                       w, h, 
                       format, dither);

        w >>= 1; if (w == 0) w = 1;
        h >>= 1; if (h == 0) h = 1;
    }
    if( txVerbose )
      printf(".\n");
}
