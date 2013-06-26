#include "amiga.h"

int main()
{
	int c;

	HW_CIAA(CIAA_DDRA)=0x03;
	HW_CIAA(CIAA_PRA)=0xfc;

//	while(1)
//		HW_AMIGA(COLOR0)=c++;
	Amiga_SetupScreen();
	Amiga_TestPattern2();

	Amiga_Putc('H');
	Amiga_Putc('e');
	Amiga_Putc('l');
	Amiga_Putc('l');
	Amiga_Putc('o');
	Amiga_Putc('\n');
	Amiga_Puts("Hello, world!\n");

	while(1)
		;
    return 0;
}

