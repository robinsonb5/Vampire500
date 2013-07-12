#include "amiga.h"
#include "font8.h"

static char plane0[640*208/8];
static short copper[8];

static int cursorx,cursory;

static void FillScreen(int v)
{
	int *p=(int *)plane0;
	int i;
	for(i=0;i<(640*208/32);++i)
		*p++=v;
}


static void IncScreen()
{
	int *p=(int*)plane0;
	int i;
	for(i=0;i<(640*208/32);++i)
		(*p++)++;
}


static void ClearScreen()
{
	FillScreen(0);
}


static int scrollcount;

static void ScrollScreen(void *plane0)
{
	// Scroll screen
	int *p1=(int *)(plane0);
	int *p2=(int *)(plane0+640);
	int i;

	++scrollcount;
	if(scrollcount==25)
	{
		// Wait for left mouse button click.
		while(HW_CIAA(CIAA_PRA)&(1<<CIAA_PRA_FIRE0))
			;
		scrollcount=0;
	}

	for(i=0;i<(80*200/4);++i)
	{
		*p1++=*p2++;
	}
	cursory=24;
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
	scrollcount=24;
}


void Amiga_TestPattern()
{
	char *planeptr=((char *)plane0)+(640/8)*(cursory+7)+cursorx;
	int y;
	for(y=0;y<256;++y)
	{
		*planeptr=y;
		*(planeptr+1)=y;
		*(planeptr+2)=y;
		*(planeptr+3)=y;
		planeptr+=640/8;
	}
}


void Amiga_TestPattern2()
{
	int v;
	while(1)
		IncScreen();
}


void Amiga_Putc(int c)
{
	if(c>=32)
	{
		char *planeptr=((char *)plane0)+(640/8)*(cursory*8+7)+cursorx;
		int *f=(int *)&font8[(c-32)*8];
		int f2=*f++;
		int f1=*f++;
		int i;

		*planeptr=f1&0xff;
		planeptr-=(640/8);
		f1>>=8;
		*planeptr=f1&0xff;
		planeptr-=(640/8);
		f1>>=8;
		*planeptr=f1&0xff;
		planeptr-=(640/8);
		f1>>=8;
		*planeptr=f1&0xff;
		planeptr-=(640/8);

		*planeptr=f2&0xff;
		planeptr-=(640/8);
		f2>>=8;
		*planeptr=f2&0xff;
		planeptr-=(640/8);
		f2>>=8;
		*planeptr=f2&0xff;
		planeptr-=(640/8);
		f2>>=8;
		*planeptr=f2&0xff;
		planeptr-=(640/8);
		f2>>=8;
	}

	if(c=='\n')	// line feed;
	{
		++cursory;
		cursorx=0;
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
		ScrollScreen(plane0);
	}
}


void Amiga_Puts(const char *s)
{
	// Because we haven't implemented loadb from ROM yet, we can't use *<char*>++.
	int *s2=(int*)s;
	unsigned char c;
	do
	{
		int i;
		int cs=*s2++;
		for(i=0;i<4;++i)
		{
			c=(cs>>24)&0xff;
			cs<<=8;
			if(c==0)
				return;
			Amiga_Putc(c);
		}
	}
	while(c);
}

