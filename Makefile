all: a3a2em-check

%.lst %.p: %.asm
	asl $< -o $@ -L

a3a2em.po: a3a2em.dsk
	reinterleave do a3a2em.dsk po a3a2em.po

a3a2em-orig.bin: a3a2em.po
	dd if=a3a2em.po of=a3a2em-orig.bin bs=256 count=24

a3a2em.bin: a3a2em.p
	p2bin -r '$$a000-$$b7ff' a3a2em.p

a3a2em-check: a3a2em.bin
	echo "a6e3d7330dd286e30cae1bb8ee1b3bee8161f33172006a3d320715fd6454fd51 a3a2em.bin" | sha256sum -c -

#a3a2em.asm: a3a2em-orig.bin
#	dis6502 -a -r 0xa000 -7 -e 0xa000 -e 0xa379 a3a2em-orig.bin >a3a2em.asm

a3a2em.dis: a3a2em-orig.bin
	dis6502 -r 0xa000 -7 -e 0xa000 -e 0xa379 -e 0xa39f a3a2em-orig.bin >a3a2em.dis

clean:
	rm a3a2em.bin *.p *.lst
