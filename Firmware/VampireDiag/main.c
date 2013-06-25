#include "amiga.h"

int main()
{
	int c;
	while(1)
		HW_AMIGA(COLOR0)=c++;
	Amiga_SetupScreen();
	Amiga_Puts("Hello, world!\n");

    return 0;
}

