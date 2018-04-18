target remote localhost:10000
set disassembly-flavor intel

source tools/gdb_realmode_macros.gdb

file rml_s2.o 

# Default breakpoints
break *0x7c00

# Layout schema
layout asm
layout regs 
#layout src
focus cmd 

# MBR
c

# Stage1
c   

# Stage2
c

# Reload the assembly (since it changed after we loaded stage 3)
layout asm
layout regs

# Delete fixed addr breakpoint
del break 1

# Break on stage2 C entry point
break rml_entry

c
