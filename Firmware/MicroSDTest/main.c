/*	Firmware for loading files from SD card.
	Part of the ZPUTest project by Alastair M. Robinson.
	SPI and FAT code borrowed from the Minimig project.

	This boot ROM ends up stored in the ZPU stack RAM
	which in the current incarnation of the project is
	memory-mapped to 0x04000000
	Halfword and byte writes to the stack RAM aren't
	currently supported in hardware, so if you use
    hardware storeh/storeb, and initialised global
    variables in the boot ROM should be declared as
    int, not short or char.
	Uninitialised globals will automatically end up
	in SDRAM thanks to the linker script, which in most
	cases solves the problem.
*/


#include "amiga_hardware.h"
#include "stdarg.h"

#include "spi.h"
#include "minfat.h"


void _boot();
void _break();

/* Load files named in a manifest file */

int main(int argc,char **argv)
{
	int i;
	Amiga_Init();
	Amiga_SetupScreen();

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

