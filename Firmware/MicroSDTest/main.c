/*	Firmware for loading files from SD card.
	SPI and FAT code borrowed from the Minimig project.
*/


#include "amiga_hardware.h"
#include "stdarg.h"

#include "spi.h"
#include "minfat.h"

int main(int argc,char **argv)
{
	volatile short *a=(short*)65536;
	int i,j,k;
	for(i=0;i<16;++i)
	{
		for(j=0;j<65535;++j)
		{
			*(a)=i;
			HW_AMIGA(COLOR0)=*(a);
		}
	}
	Amiga_SetupScreen();
	puts("Hello world!\n");

	puts("Initializing SD card\n");
	if(spi_init())
	{
		FindDrive();
		puts("Attempting to load ROM\n");
		if(LoadFile(0,"kick13.rom\n"))
		{
			puts("Loading of ROM succeeded\n");
		}
		else
			puts("ROM Loading failed.\n");
	}
	puts("Returning\n");

	return(0);
}

