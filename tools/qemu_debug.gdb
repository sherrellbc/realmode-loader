target remote localhost:10000
set disassembly-flavor intel

source ../../tools/gdb_realmode_macros.gdb

# Default breakpoints
break *0x7c00

# Layout schema
layout asm
layout regs 
#layout src
focus cmd 

c
