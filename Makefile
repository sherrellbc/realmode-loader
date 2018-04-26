.PHONY: all clean dump_mbr dump_s1 dump_s2 dump_all disk run rml_mbr.bin rml_s1.bin rml_s2.bin rml view_log
.SUFFIXES: .o .c .S

# Config
INCLUDEDIR  = /usr/include
HOST        = i686-elf
OBJCOPY     = ${HOST}-objcopy
OBJDUMP     = ${HOST}-objdump
CC          = ${HOST}-gcc
GDB         = gdb
QEMU_LOG    = rml.log
QEMU_HD     = qemu_hd.bin

CFLAGS      = -MD -O0 -g -ffreestanding -nostartfiles -nostdlib -Wall -Wextra -Werror -Istage2/include/ -Istage2/libs/libc-utils/include/
LDFLAGS     = -nostdlib

# Each stage will relocate itself to a final load address after getting execution at 0000:7c00
# Note this must be in sync with what is defined in the corresponding source files
RML_MBR_RELOC   = 0x0600
RML_S1_RELOC    = 0x0600
RML_S2_RELOC    = 0x7c00

RML_S2_SRC  = rml_s2.S stage2/entry.c stage2/vesa.c stage2/vga.c stage2/rml_utils.c
RML_S2_OBJS = $(addsuffix .o, $(basename $(RML_S2_SRC)))

all: rml_mbr.bin rml_s1.bin rml_s2.bin

# Include all the rules to make dependent libraries
include stage2/libs/Makefile

# We have to LINK here as well. Otherwise we default to a load address of 0x0000
rml : rml_mbr.bin rml_s1.bin rml_s2.bin
rml_mbr.bin rml_s1.bin rml_s2.bin : %.bin:%
	$(OBJCOPY) -O binary $<.o --only-section=.text --only-section=.rodata $@

rml_mbr:
	@echo "\nBuilding RML Master Boot Record (MBR)"
	$(CC) -m16 $(CFLAGS) -Wl,$(LDFLAGS),-Ttext=$(RML_MBR_RELOC) $@.S -o $@.o

rml_s1:
	@echo "\nBuilding RML stage1"
	$(CC) -m16 $(CFLAGS) -Wl,$(LDFLAGS),-Ttext=$(RML_S1_RELOC) $@.S -o $@.o

rml_s2: libs $(RML_S2_OBJS)
	@echo "\nBuilding RML stage2"
	$(CC) -m32 $(CFLAGS) -Wl,$(LDFLAGS),-Ttext=$(RML_S2_RELOC),-Lstage2/libs/lib_archives/ $(RML_S2_SRC) -o $@.o -lc -lgcc


# Unfortunately, GCC creates object files with bfd type i386 even for 16-bit code. Recall
# that GCC outputs i386 code with in the 16 bit case as well, save for extended address
# and data modifiers (66/67 prefixes on opcodes). So, such a result makes sense given this
# limitation of GCC. As such, to get _real_ 16-bit dissassembly we must objdump the resulting
# bin file, otherwise objdump interprets the code as i386 due to the "Machine" type of the object
# file
dump: dump_mbr dump_s1 dump_s2
dump_mbr: rml_mbr.bin
	$(OBJDUMP) $< -Mintel -D -bbinary -mi8086 --adjust-vma=$(RML_MBR_RELOC) | tee $<.decomp

dump_s1: rml_s1.bin
	$(OBJDUMP) $< -Mintel -D -bbinary -mi8086 --adjust-vma=$(RML_S1_RELOC) | tee $<.decomp

# Stage is is primarily 32-bit code, save for a few 16-bit routines and the entry point
# Thus, we can just objdump the object file directly (as opposed to objcopying it first
# like we had to do for the other stages) and, consequentially, keep all the symbols!
dump_s2: rml_s2
	$(OBJDUMP) $<.o -Mintel -d | tee $<.decomp
#	$(OBJDUMP) $< -Mintel -D -bbinary -mi8086 --adjust-vma=$(RML_S2_RELOC) | tee $<.decomp

view_log:
	tail -f $(QEMU_LOG)

disk:
	tools/create_hd_img.sh $(QEMU_HD)

ifneq ($(DEBUG),)
    GDB_DEBUG=-S -gdb tcp::10000
endif
run: rml disk
#	    -d int,pcall,cpu,cpu_reset
	qemu-system-i386 $(GDB_DEBUG)   \
	    -serial file:$(QEMU_LOG)    \
        -boot c $(QEMU_HD) &        \
        if [ $(DEBUG) ]; then       \
            sleep 1;                \
            $(GDB) -x tools/qemu_debug.gdb; \
        fi;                         \
        wait;

clean: clean_libs
	rm -rf *.o *.d *.bin *.decomp \
        $(RML_S2_OBJS) \
        $(addsuffix .d, $(basename $(RML_S2_OBJS)))
