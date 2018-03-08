.PHONY: all clean
.SUFFIXES: .o .c .S

# Config
INCLUDEDIR  = /usr/include
HOST        = i686-elf
OBJCOPY     = ${HOST}-objcopy
OBJDUMP     = ${HOST}-objdump
CC          = ${HOST}-gcc

# The relocated address of the MBR code once it gets execution at 0x0000:0x7c00
# Note this must be in sync with what is defined in the mbr source file
MBR_RELOC   = 0x0600

CFLAGS      = -c -MD -O0 -g -ffreestanding -Wall -Wextra -Werror
LDFLAGS     = -nostdlib,-Ttext=$(MBR_RELOC)

# We have to compile and link here (i.e. no -c option) to get the linker to run and load us at 0x7c00
rm_mbr:
	$(CC) -m16 $(CFLAGS) -Wl,$(LDFLAGS) $@.S -o $@.o
	$(OBJCOPY) -O binary $@.o --only-section=.text $@.bin

# TODO: 
rm_stage2:
rm_stage3:

# This does not have any symbols. Attempting to dump the *.o caused the disassembly to be 32-bit
# due to the bfd type of the object file (e.g. i386)
dump: rm_mbr.bin
	$(OBJDUMP) $< -D -bbinary -mi8086 --adjust-vma=$(MBR_RELOC)

clean:
	rm -f *.o *.d *.bin
