
/* Memory Definitions */

MEMORY
{
  BOOT (rx) : ORIGIN = 0x04000000, LENGTH = 0x00000008 /* Boot section contains just the initial jump */
  TRAP (rx) : ORIGIN = 0x04000008, LENGTH = 0x00000000 /* Dummy region to ensure we don't have any Initialized writable data */
  CODE (rx) : ORIGIN = 0x04000008, LENGTH = 0x00001ff8 /* Up to the end of the first 4K */
  AMIGA (rx) : ORIGIN = 0x00000000, LENGTH = 0x00080000 /* Half a meg of CHIP RAM in the Amiga */
}


/* Section Definitions */

SECTIONS
{
  /* first section is .fixed_vectors which is used for startup code */
  . = 0x0000000;
  .fixed_vectors :
  {
    *(.fixed_vectors)
  }>BOOT

  /* Remaining code sections */
  .text :
  {
	. = ALIGN(4);
    *(.text)                   /* remaining code */
  } >CODE

  /* .rodata section which is used for read-only data (constants) */
  .rodata :
  {
    *(.rodata*)
  . = ALIGN(4);
  } >CODE
  _romend = . ;

  /* .data section which is used for initialized data.
     Since we don't want any writable data within the ROM
     itself, we put this stuff in a "trap" section. */
  .data :
  {
    _data = . ;
    *(.data)
    SORT(CONSTRUCTORS)
    . = ALIGN(4);
  } >TRAP

  .bss :
  {
	. = ALIGN(4);
    *(.bss)                   /* BSS Data */
	*(COMMON)
  } >AMIGA
  __bss_end__ = . ;
}
