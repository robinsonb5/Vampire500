
PROJECT=Vampire500
QPF=mc68k_probe.qpf

DATE=`date +%Y%m%d`

all:
	make -C Firmware
	quartus_sh --flow compile $(QPF) -c Vampire500

snapshot:
	touch ../Vampire500_$(DATE).zip
	rm ../Vampire500_$(DATE).zip
	git archive HEAD --format=zip --prefix=Vampire500_$(DATE)/ -o ../Vampire500_$(DATE).zip
	zip a ../Vampire500_$(DATE).zip *.sof

