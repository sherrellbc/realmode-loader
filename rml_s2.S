.intel_syntax noprefix

#define RMLS2_STACK       0x2000
#define RMLS2_RELOC_ADDR  0x0600

.section .text
.code16

_start:
    /* Let's get everything into a known state */
    mov sp, RMLS2_STACK
    xor ax, ax
    mov ss, ax
    mov ds, ax
    mov es, ax

    //Switch to 32 bit code 
    mov ah, 0x00
    mov al, 0x02
    int 0x10
    call rml_entry

loop:
    hlt
    jmp loop
