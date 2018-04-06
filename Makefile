.PHONY: all clean dump_mbr dump_s1 dump_s2 dump_all disk run rml_mbr.bin rml_s1.bin rml_s2.bin rml
.SUFFIXES: .o .c .S

# Config
INCLUDEDIR  = /usr/include
HOST        = i686-elf
OBJCOPY     = ${HOST}-objcopy
OBJDUMP     = ${HOST}-objdump
CC          = ${HOST}-gcc
GDB         = gdb

# Each stage will relocate itself to a final load address after getting execution at 0000:7c00
# Note this must be in sync with what is defined in the mbr source file
RML_MBR_RELOC   = 0x0600
RML_S1_RELOC    = 0x0600
RML_S2_RELOC    = 0x7c00

RML_S3_SRC  = stage2/entry.c
RML_S3_OBJS = $(addsuffix .o, $(basename $(RML_S3_SRC)))

CFLAGS      = -m16 -MD -O0 -g -ffreestanding -nostartfiles -nostdlib -Wall -Wextra -Werror
LDFLAGS     = -nostdlib


all: rml_mbr.bin rml_s1.bin rml_s2.bin

# We have to compile and link here (i.e. no -c option) to get the linker to run and load us at 0x7c00
rml : rml_mbr.bin rml_s1.bin rml_s2.bin
rml_mbr.bin rml_s1.bin rml_s2.bin : %.bin:%
	$(OBJCOPY) -O binary $<.o --only-section=.text --only-section=.rodata $@

rml_mbr:
	$(CC) $(CFLAGS) -Wl,$(LDFLAGS),-Ttext=$(RML_MBR_RELOC) $@.S -o $@.o

rml_s1:
	$(CC) $(CFLAGS) -Wl,$(LDFLAGS),-Ttext=$(RML_S1_RELOC) $@.S -o $@.o

rml_s2: $(RML_S3_OBJS)
	$(CC) $(CFLAGS) -Wl,$(LDFLAGS),-Ttext=$(RML_S2_RELOC) $@.S $(RML_S3_OBJS) -o $@.o


# This does not have any symbols. Attempting to dump the *.o caused the disassembly to be 32-bit
# due to the bfd type of the object file (e.g. i386)
dump: dump_mbr dump_s1 dump_s2
dump_mbr: rml_mbr.bin
	$(OBJDUMP) $< -D -bbinary -mi8086 --adjust-vma=$(RML_MBR_RELOC) | tee $<.decomp

dump_s1: rml_s1.bin
	$(OBJDUMP) $< -D -bbinary -mi8086 --adjust-vma=$(RML_S1_RELOC) | tee $<.decomp

# TODO: This one will change as it will be 16 and 32 bit code eventually
dump_s2: rml_s2.bin
	$(OBJDUMP) $< -D -bbinary -mi8086 --adjust-vma=$(RML_S2_RELOC) | tee $<.decomp

disk:
	tools/create_hd_img.sh qemu_hd.bin

ifneq ($(DEBUG),)
    GDB_DEBUG=-S -gdb tcp::10000
endif
run: rml disk
	qemu-system-i386 $(GDB_DEBUG) -boot c qemu_hd.bin & if [ $(DEBUG) ]; then sleep 1; $(GDB) -x tools/qemu_debug.gdb; fi; wait;

clean:
	rm -f *.o *.d *.bin *.decomp $(RML_S3_OBJS) $(addsuffix .d, $(basename $(RML_S3_OBJS)))
