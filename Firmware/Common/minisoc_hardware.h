#ifndef MINISOC_HARDWARE_H
#define MINISOC_HARDWARE_H

/* Hardware registers for the ZPU MiniSOC project.
   Based on the similar TG68MiniSOC project, but with
   changes to suit the ZPU's archicture */

#define VGABASE 0xE0000000

#define FRAMEBUFFERPTR 0

#define SP0PTR 0x100
#define SP0XPOS 0x104
#define SP0YPOS 0x108

#define HW_VGA(x) *(volatile unsigned long *)(VGABASE+x)
#define VGA_INT_VBLANK 1

/*
4	Word	Even row modulo (not yet implemented)

6	Word	Odd row modulo (not yet implemented)

8	Word	HTotal -  the total number of pixel clocks in a scanline (not yet implemented)

A	Word	HSize – number of horizontal pixels displayed (not yet implemented)

C	Word	HBStart – start of the horizontal blank (not yet implemented)

E	Word	HBStop – end of the horizontal blanking period. (Not yet implemented)

10	Word	Vtotal – the number of scanlines in a frame (not yet implemented)

12	Word	Vsize – the number of displayed scanlines  (not yet implemented)

14	Word	Vbstart – start of the vertical blanking period  (not yet implemented)

16	Word	Vbstop – end of the vertical blanking period  (not yet implemented)

18	Word	Control  (not yet implemented)
		bit 7	Character overlay on/off  (not yet implemented)
		bit 1	resolution – 1: high, 0: low   (not yet implemented)
		bit 0	visible.  (not yet implemented)
*/


#define PERIPHERALBASE 0xFFFFFF84
#define HW_PER(x) *(volatile unsigned int *)(PERIPHERALBASE+x)
#define HW_PER_L(x) *(volatile unsigned int *)(PERIPHERALBASE+x)

#define PER_UART 0
#define PER_UART_CLKDIV 4

#define PER_UART_RXINT 9
#define PER_UART_TXREADY 8

#define PER_FLAGS 0x8  /* Currently only contains ROM overlay */
#define PER_FLAGS_OVERLAY 0

#define PER_HEX 0xc

#define PER_PS2_KEYBOARD 0x10
#define PER_PS2_MOUSE 0x14

/* PS2 Status bits */
#define PER_PS2_RECV 11
#define PER_PS2_CTS 10

/* Timers */

#define PER_TIMER_CONTROL 0x18

/* Control bits */
#define PER_TIMER_TR5 5
#define PER_TIMER_TR4 4
#define PER_TIMER_TR3 3
#define PER_TIMER_TR2 2
#define PER_TIMER_TR1 1

#define PER_TIMER_EN5 13
#define PER_TIMER_EN4 12
#define PER_TIMER_EN3 11
#define PER_TIMER_EN2 10
#define PER_TIMER_EN1 9

/* Divisor registers */
#define PER_TIMER_DIV0 0x1c
#define PER_TIMER_DIV1 0x20
#define PER_TIMER_DIV2 0x24
#define PER_TIMER_DIV3 0x28
#define PER_TIMER_DIV4 0x2c
#define PER_TIMER_DIV5 0x30
#define PER_TIMER_DIV6 0x34
#define PER_TIMER_DIV7 0x38	/* SPI speed */

/* Millisecond counter */
#define PER_MILLISECONDS 0x3c

/* SPI register */
#define PER_SPI_CS 0x40	/* CS bits are write-only, but bit 15 reads as the SPI busy signal */
#define PER_SPI 0x44 /* Blocks on both reads and writes, making BUSY signal redundant. */
#define PER_SPI_PUMP 0x48 /* Push 16-bits through SPI in one instruction */

#define PER_SPI_FAST 8
#define PER_SPI_BUSY 15

#define PER_MANIFEST1 0x74 /* First four characters of Manifest filename */
#define PER_MANIFEST2 0x78 /* Second four characters of Manifest filename */

/* Interrupts */

#define PER_INT_UART 2
#define PER_INT_TIMER 3
#define PER_INT_PS2 4

#ifndef DISABLE_UART_TX
void putcserial(char c);
void putserial(char *msg);
#else
#define putserial(x)
#endif

#ifndef DISABLE_UART_RX
char getserial();
#else
#define getserial 0
#endif

#endif

