#include "amiga.h"

void Putint(unsigned int val)
{
	int c;
	int i;
	for(i=0;i<8;++i)
	{
		c=(val>>28)&0xf;
		val<<=4;
		if(c>9)
			c+='A'-10;
		else
			c+='0';
		Amiga_Putc(c);
	}
}

#if 0
void CheckAlias()
{
	int i1,i2,i3,i4;
	i2=*(volatile int *)0xfc0000;
	i1=*(volatile int *)0xf00000;
	Putint(i1);
	Putint(i2);
	i4=*(volatile int *)0xfc0004;
	i3=*(volatile int *)0xf00004;
	Putint(i3);
	Putint(i4);
	Amiga_Putc('\n');

	i2=*(volatile int *)0xfc0008;
	i1=*(volatile int *)0xf00008;
	Putint(i1);
	Putint(i2);
	i4=*(volatile int *)0xfc000c;
	i3=*(volatile int *)0xf0000c;
	Putint(i3);
	Putint(i4);
	Amiga_Putc('\n');
}
#endif

int main()
{
	int c;

	HW_CIAA(CIAA_DDRA)=0x03;
	HW_CIAA(CIAA_PRA)=0xfc;

//	while(1)
//		HW_AMIGA(COLOR0)=c++;
	Amiga_SetupScreen();
//	Amiga_TestPattern2();

//	Amiga_Putc('H');
//	Amiga_Putc('e');
//	Amiga_Putc('l');
//	Amiga_Putc('l');
//	Amiga_Putc('o');
//	Amiga_Putc('\n');
//	Amiga_Puts("Hello, world!\n");

	c=*(volatile short*)0xfc0000;
	while(1)
		c=*(volatile short*)0xf00000;

//	CheckAlias();

//	while(1)
//		c=*(volatile int *)0xf00000;

//	while(1)
//		;
    return 0;
}

