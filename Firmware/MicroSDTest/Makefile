BASE	= zpu-elf
CC      = $(BASE)-gcc
LD      = $(BASE)-gcc
AS      = $(BASE)-as
CP      = $(BASE)-objcopy
DUMP    = $(BASE)-objdump

BUILD_DIR=zpu_obj

MINSTARTUP_SRC = ../Common/mincrt0.s
MINSTARTUP_OBJ = $(patsubst ../Common/%.s,$(BUILD_DIR)/%.o,$(MINSTARTUP_SRC))

COMMON_SRC = ../Common/small_printf.c ../Common/font8.c ../Common/font8.h \
	../Common/spi.c ../Common/spi.h ../Common/swap.c ../Common/swap.h ../Common/amiga_hardware.c 
COMMON_OBJ = $(patsubst ../Common/%.c,$(BUILD_DIR)/%.o,$(COMMON_SRC))

BOOT_PRJ = MicroSDTest
BOOT_SRC = main.c minfat.c minfat.h
BOOT_OBJ = $(COMMON_OBJ) $(patsubst %.c,$(BUILD_DIR)/%.o,$(BOOT_SRC))

LINKMAP  = boot.ld
LIBDIR   = 

# Commandline options for each tool.
#ZPUOPTS= -mno-poppcrel -mno-compare -mno-byteop -mno-shortop -mno-callpcrel \
#  -mno-call -mno-neqbranch -mno-pushspadd \
#  -mno-neg -mno-mod -mno-div

ZPUOPTS= -mno-poppcrel -mno-pushspadd -mno-callpcrel  -mno-neg # No-neg requires bugfixed toolchain

CFLAGS  = -I. -I../Common/ -c -Os $(ZPUOPTS) -DPRINTF_HEX_ONLY -DDISABLE_UART_RX # -DDISABLE_UART_TX 
AFLAGS  = 
LFLAGS  = -Wl,--relax -nostdlib -Os
CP_HEXFLAGS = -Oihex
CP_SRECFLAGS = -Osrec --gap-fill 0

# Libraries.
LIBS       =

# Our target.
all: $(BUILD_DIR) $(BOOT_PRJ).bin $(BOOT_PRJ).rpt

mif: $(BOOT_PRJ).mif

clean:
	rm -f $(BUILD_DIR)/*.o *.hex *.elf *.map *.lst *.srec $(BOOT_PRJ).mif $(BOOT_PRJ).rom *~ */*.o *.bin

link:
	rm -f $(BOOT_PRJ).mif $(BOOT_PRJ).elf
	make

# Convert ELF binary to bin file.
%.bin: %.elf
	$(CP) -O binary $< $@

# Convert ELF binary to Intel HEX file.
%.hex: %.elf
	$(CP) $(CPFLAGS) $< $@

# Convert ELF binary to SREC file
%.srec: %.elf
	$(CP) $(CP_SRECFLAGS) $< $@

# Convert SREC to .mif file
%.mif: %.srec
	srec_cat $< -offset=-0x04000000 -o $@ -mif 32

%.rpt: %.elf
	$(DUMP) -x $< | grep _romend   #  End of Boot ROM
	$(DUMP) -x $< | grep __bss_start__   #  Start of BSS data in SDRAM
	$(DUMP) -x $< | grep __bss_end__   #  End of BSS data in SDRAM

# Link - this produces an ELF binary.

$(BOOT_PRJ).elf: $(MINSTARTUP_OBJ) $(BOOT_OBJ)
	$(LD) $(LFLAGS) -T boot.ld -o $@ $+ $(LIBS)

$(BUILD_DIR)/%.o: %.c
	$(CC) $(CFLAGS)  -o $@ -c $<

$(BUILD_DIR)/%.o: ../Common/%.c
	$(CC) $(CFLAGS)  -o $@ -c $<

$(BUILD_DIR)/%.o: %.s
	$(AS) -o $@ $<

$(BUILD_DIR)/%.o: ../Common/%.s
	$(AS) -o $@ $<

$(BUILD_DIR):
	mkdir $(BUILD_DIR)

