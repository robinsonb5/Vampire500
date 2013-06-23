BASE	= zpu-elf
CC      = $(BASE)-gcc
LD      = $(BASE)-gcc
AS      = $(BASE)-as
CP      = $(BASE)-objcopy
DUMP    = $(BASE)-objdump

BUILD_DIR=zpu_obj

DIAG_PRJ = VampireDiag
COMMON_SRC = ../Common/minisoc_hardware.c ../Common/minisoc_hardware.h ../Common/small_printf.c ../Common/small_printf.h
COMMON_OBJ = $(patsubst ../Common/%.c,$(BUILD_DIR)/%.o,$(COMMON_SRC))

DIAG_SRC_C = main.c md5.c font8.h font8.c amiga.c amiga.h
DIAG_OBJ_C = $(patsubst %.c,$(BUILD_DIR)/%.o,$(DIAG_SRC_C))
DIAG_OBJ = $(DIAG_OBJ_C) $(COMMON_OBJ)

LINKMAP  = dhry.ld
LIBDIR   = 

# Commandline options for each tool.
#ZPUOPTS= -mno-poppcrel -mno-compare -mno-byteop -mno-shortop -mno-callpcrel \
#  -mno-call -mno-neqbranch -mno-pushspadd \
#  -mno-neg -mno-mod -mno-div

ZPUOPTS= # -mno-poppcrel -mno-pushspadd -mno-callpcrel -mno-mult -mno-div # -mno-neg

CFLAGS  = -I. -I../Common/ -c -O6 $(ZPUOPTS) -DPRINTF_HEX_ONLY # -DDISABLE_PRINTF -DDISABLE_UART
AFLAGS  = 
LFLAGS  = -mboard=abel -O6 -Wl,--relax
CP_HEXFLAGS = -Oihex
CP_SRECFLAGS = -Osrec --gap-fill 0

# Libraries.
LIBS       =

# Our target.
all: $(BUILD_DIR) $(DIAG_PRJ).bin

mif: $(DIAG_PRJ).mif

clean:
	rm -f $(BUILD_DIR)/*.o *.hex *.elf *.map *.lst *.srec $(PRJ).mif *~ */*.o *.bin

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
	srec_cat $< -o $@ -mif 32

# Link - this produces an ELF binary.

$(DIAG_PRJ).elf: $(DIAG_OBJ)
	$(LD) $(LFLAGS) -o $@ $+ $(LIBS)

$(BUILD_DIR)/%.o: ../Common/%.c
	$(CC) $(CFLAGS)  -o $@ -c $<

$(BUILD_DIR)/%.o: %.c
	$(CC) $(CFLAGS)  -o $@ -c $<

$(BUILD_DIR):
	mkdir $(BUILD_DIR)

