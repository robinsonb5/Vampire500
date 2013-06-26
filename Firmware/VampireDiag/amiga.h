#ifndef AMIGA_H
#define AMIGA_H

#define VPOSR    0x04
#define INTREQR  0x1E
#define DSKPTH   0x20
#define DSKLEN   0x24
#define LISAID   0x7C
#define COP1LCH  0x80
#define COP1LCL  0x82
#define COPJMP1  0x88
#define DIWSTRT  0x8E
#define DIWSTOP  0x90
#define DDFSTRT  0x92
#define DDFSTOP  0x94
#define DMACON   0x96
#define INTENA   0x9A
#define INTREQ   0x9C
#define ADKCON   0x9E
#define BPLCON0  0x100
#define BPLCON1  0x102
#define BPLCON2  0x104
#define BPL1MOD  0x108
#define BPL2MOD  0x10A
#define COLOR0   0x180
#define COLOR1   0x182

#define HW_AMIGA(x) (*(short *)(0xDFF000+x))

#define CIAA_PRA 0x0001
#define CIAA_DDRA 0x0201

#define HW_CIAA(x) (*(char *)(0xBFE000+x))

void Amiga_Putc(unsigned char c);
void Amiga_Puts(const char *s);
void Amiga_SetupScreen();

#endif

