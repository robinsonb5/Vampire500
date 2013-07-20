all: zpuromgen VampireDiag.gen SDRAMTest.gen MicroSDTest.gen

clean:
	make -C VampireDiag clean
	make -C SDRAMTest clean
	make -C MicroSDTest clean
	rm *.vhd
	rm zpuromgen

zpuromgen: zpuromgen.c
	gcc -o zpuromgen zpuromgen.c

# Generic rom-generation rule - only works if the Project directories are carefully named

%.gen: 
	make -C $*/
	sed 's/dualportram/$*_ROM/' >$*_ROM.vhd <rom_prologue
	./zpuromgen $*/$*.bin >>$*_ROM.vhd
	cat >>$*_ROM.vhd rom_epilogue

