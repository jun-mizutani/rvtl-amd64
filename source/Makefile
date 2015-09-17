# Makefile for rvtl
#     2010/07/03  Jun Mizutani


INSTALLDIR = /usr/bin/
#INSTALLDIR = /bin/

SOURCE = errno64.inc fb64.inc mman64.inc rvtl64.asm syscall64.inc \
         vtlfb64.inc ext.inc fblib64.inc mt19937.inc signal64.inc \
         syserror64.inc vtllib64.inc

all : rvtl64

rvtlm : ${SOURCE}
	nasm -f elf64 rvtl64.asm -dNO_FB
	ld -s -melf_x86_64 -o rvtlm rvtl.o

rvtls : ${SOURCE}
	nasm -f elf64 rvtl64.asm -dSMALL_VTL
	ld -s -melf_x86_64 -o rvtls64 rvtl64.o

rvtl64 : ${SOURCE}
	nasm -f elf64 rvtl64.asm
	ld -s -melf_x86_64 -o rvtl64 rvtl64.o

debug : ${SOURCE}
	nasm -f elf64 rvtl64.asm -dDEBUG
	ld -s -melf_x86_64 -o rvtld64 rvtl64.o

install :
	cp rvtl64 ${INSTALLDIR}
	ln -s ${INSTALLDIR}rvtl64 ${INSTALLDIR}rvtlw
	ln -s ${INSTALLDIR}rvtl64 ${INSTALLDIR}rvtl

uninstall :
	rm ${INSTALLDIR}rvtl64

dist :
	rm *.o
	mv rvtl64 ..

clean :
	rm *.o rvtl64

disasm :
	objdump -d -M x86-64,intel rvtl64 >rvtl64.list.txt

listelf :
	objdump -h rvtl64
