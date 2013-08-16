
/* Memory Definitions */

MEMORY
{
  VECTORS (r) : ORIGIN = 0x00EE0000, LENGTH = 0x00000008 /* Boot section contains just the initial jump */
  TRAP (rx) : ORIGIN = 0x10000000, LENGTH = 0x00000000 /* Dummy region to ensure we don't have any Initialized writable data */
  CODE (rx) : ORIGIN = 0x00EE0010, LENGTH = 0x00004000 /* Code section of an overlay BOOT ROM */
  CHIPRAM (rw) : ORIGIN = 0x00010000, LENGTH = 0x00070000 /* Half a meg of chip RAM */
  FASTRAM (rw) : ORIGIN = 0x00200000, LENGTH = 0x009ffff0 /* Eight meg of Fast RAM */
}


/* Section Definitions */

SECTIONS
{
  /* first section is .fixed_vectors which is used for startup code */
  . = 0x0000000;
  .fixed_vectors :
  {
    *(.fixed_vectors)
  }>VECTORS

  /* Remaining code sections */
  .text :
  {
	ROM_start = .;
	. = ALIGN(4);
	*(.boot)
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

  /* .bss section which is used for uninitialized data */
  .bss :
  {
    __bss_start = . ;
    __bss_start__ = . ;
    *(.bss)
    *(COMMON)
    . = ALIGN(4);
  } >CHIPRAM
  __bss_end__ = . ;
  stack_top = 0x300000;
}
