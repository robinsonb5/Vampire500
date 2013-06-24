#include "amiga.h"
#include "font8.h"

static int plane0[640*208/8];
static short copper[8];

static int cursorx,cursory;

static void ClearScreen()
{
	int *p=plane0;
	int i;
	for(i=0;i<(640*208/32);++i)
		*p++=0;
}

static void BuildCopperlist(short *c,void *p)
{
	*c++=0xe0;
	*c++=((int)p>>16)&0xffff;
	*c++=0xe2;
	*c++=((int)p)&0xffff;
	*c++=0xffff;
	*c++=0xfffe;
}

void Amiga_SetupScreen()
{
	HW_AMIGA(BPLCON0)=0x9000; // hires, 1 bitplane
	HW_AMIGA(BPLCON1)=0x0000; // horizontal scroll = 0
	HW_AMIGA(BPLCON2)=0x0000;
	HW_AMIGA(BPL1MOD)=0x0000; // modulo = 0
	HW_AMIGA(BPL2MOD)=0x0000; // modulo = 0

	ClearScreen();

	HW_AMIGA(DDFSTRT)=0x003c;
	HW_AMIGA(DDFSTOP)=0x00d4;
	HW_AMIGA(DIWSTRT)=0x2c81;
	HW_AMIGA(DIWSTOP)=0xf4c1;
	HW_AMIGA(COLOR0)=0x037f; // Blue
	HW_AMIGA(COLOR1)=0x0fff; // White

	BuildCopperlist(copper,(void *)plane0);

	HW_AMIGA(COP1LCH)=((int)copper>>16)&0xffff;
	HW_AMIGA(COP1LCL)=(int)copper&0xffff;
	HW_AMIGA(COPJMP1)=0;
	HW_AMIGA(DMACON)=0x8390; // #%1000_0011_1001_0000  -  DMAEN|BPLEN|COPEN|DSKEN
	cursorx=0;
	cursory=0;
}

void Amiga_Putc(char c)
{
	char *planeptr=((char *)plane0)+(640/8)*(7*cursory)+cursorx;
	int *font=(int *)&font[(c-32)*8];
	int f1=*font++;
	int f2=*font++;
	int i;

	*planeptr=f1&0xff;
	planeptr-=(640/8);
	f1>>8;
	*planeptr=f1&0xff;
	planeptr-=(640/8);
	f1>>8;
	*planeptr=f1&0xff;
	planeptr-=(640/8);
	f1>>8;
	*planeptr=f1&0xff;
	planeptr-=(640/8);
	f1>>8;

	*planeptr=f2&0xff;
	planeptr-=(640/8);
	f2>>8;
	*planeptr=f2&0xff;
	planeptr-=(640/8);
	f2>>8;
	*planeptr=f2&0xff;
	planeptr-=(640/8);
	f2>>8;
	*planeptr=f2&0xff;
	planeptr-=(640/8);
	f2>>8;

	if(c==10)	// line feed;
	{
		++cursory;
	}
	else
	{
		++cursorx;
		if(cursorx==80)
		{
			++cursory;
			cursorx=0;
		}
	}
	if(cursory==25)
	{
		// Scroll screen
		int *p1=(int *)(plane0);
		int *p2=(int *)(plane0+640);
		int i;
		for(i=0;i<(80*200/4);++i)
		{
			*p1++=*p2++;
		}
		cursory=24;
	}
}

void Amiga_Puts(const char *s)
{
	// Because we haven't implemented loadb from ROM yet, we can't use *<char*>++.
	int *s2=(int*)s;
	char c;
	do
	{
		int i;
		int cs=*s2++;
		for(i=0;i<4;++i)
		{
			c=(cs>>24)&0xff;
			cs<<=8;
			if(!c)
				break;
			Amiga_Putc(c);
		}
	}
	while(c);
}

#if 0

	move.b	#0x03,0xBFE201	; _led and ovl as outputs
	move.b	#0x00,0xBFE001	; _led active

;------------------------------------------------------------------------------
putxl:
;------------------------------------------------------------------------------
; Args: D0.w - character

	swap	D0
	bsr	putxw
	swap	D1
	move.l	D1,D0
;	bsr	putxw		;optimization
;	rts

;------------------------------------------------------------------------------
putxw:
;------------------------------------------------------------------------------
; Args: D0.w - character

	ror.w	#8,D0
	bsr	putx
	move.l	D1,D0
	ror.w	#8,D0
;	bsr	putx		;optimization
;	rts

;------------------------------------------------------------------------------
putx:
;------------------------------------------------------------------------------
; Args: D0.b - number to print (0-255)
	move.l	D0,D1
	lsr.b	#4,D0
	bsr	putcx

	move.l	D1,D0
	andi.b	#0x0F,D0
;	bsr	putcx		;optimization
;	rts

;------------------------------------------------------------------------------
putcx:
;------------------------------------------------------------------------------
; Args: D0.b - number to print (0-15)

	add.b	#'0',D0
	cmp.b	#'9',D0
	ble	putcx_le9
	add.b	#'A'-'9'-1,D0
putcx_le9:
;	bsr	putc		;optimization
;	rts

;------------------------------------------------------------------------------
putc:
;------------------------------------------------------------------------------
; Args: D0.b - character
; scratch: D0,A0,A1

	movea.l	A3,A1		; framebuffer cursor pointer
	lea	1(A3),A3
	cmp.b	#10,D0		; LF?
	bne.s	no_LF

	suba.w	D2,A3		; return to the beginning of the line
	move.w	#0,D2		; PosX
	lea	8*640/8-1(A3),A3
	bra.s	incPosY
no_LF:
	ext.w	D0
	sub.w	#32,D0		; font table begins with space character
	asl.w	#3,D0		; every character is 8 line high
	lea	font8,A0
	adda.w	D0,A0		; calculate font offset in table

	moveq	#8-1,D0		; number of lines
char_copy_loop:
	move.b	(A0)+,(A1)	; copy line
	lea	640/8(A1),A1
	dbra	D0,char_copy_loop

	addq	#1,D2		; inc PosX
	cmp.w	#80,D2		; last position?
	bne.s	no_EOL

	moveq	#0,D2		; return to the beginnig of the line
	adda.w	#7*640/8,A3

incPosY:
	addq.w	#1,D3		; inc PosY
	cmp.w	#25,D3		; check PosY
	bne.s	not_last_line

	subq.w	#1,D3		; PosY
	suba.w	#8*640/8,A3
	bsr.s	ScrollScreen
not_last_line:
no_EOL:
	rts

;------------------------------------------------------------------------------
PrintText:
;------------------------------------------------------------------------------
; Args: A0 - pointer to NULL terminated text string
; Scratch: A2

	movea.l	A0,A2
next_char:
	movea.l	A3,A1
	moveq	#0,D0
	move.b	(A2)+,D0
	beq.s	end_of_string
	bsr.s	putc
	bra.s	next_char
end_of_string:
	rts

;------------------------------------------------------------------------------
ScrollScreen:
;------------------------------------------------------------------------------
;scratch: D0,A0,A1

	lea	plane0,A0
	lea	8*640/8(A0),A1
	move.w	#640*200/8/4-1,D0
scrollscreen_loop:
	move.l	(A1)+,(A0)+
	nop
	dbra	D0,scrollscreen_loop
	rts

;------------------------------------------------------------------------------
ClearScreen:
;------------------------------------------------------------------------------

	moveq	#0,D2		; PosX
	moveq	#0,D3		; PosY
	lea	plane0,A3	; PosPtr
	movea.l	A3,A0
	moveq	#0,D0
	move.w	#640*208/32-1,D1
clrscr_loop:
	move.l	D0,(A0)+
	nop
	dbra	D1,clrscr_loop
	rts

#endif

