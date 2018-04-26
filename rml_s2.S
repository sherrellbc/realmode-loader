.intel_syntax noprefix

#define RMLS2_STACK       0x2000
#define RMLS2_RELOC_ADDR  0x0600

.section .text

/*
 * GCC insists on generating 16-bit (generated from C source) code as 32-bit
 * code with 66/67 prefixes (e.g. data32/addr32). Though this _does_ work, it
 * relies on this prefix being available, which is true only for systems
 * beginning with the i386. That is, such code is invalid on machines prior
 * to this era and will not be interpreted correctly by the instruction decoder.
 * Unfortunately, having some hand-crafted 16-bit assembly that is intended to work
 * with GCC's C-based 16-bit assembly causes interoperability issues. Namely, 
 * the C-based 16-bit code uses word length 4, while the hand-crafted 16-bit code
 * uses 2. Obviously this causes issues when calling either way. Using the global
 * 'code16gcc' setting informs the assembler (GAS, in this case) to use these 66/67
 * prefixes even with our 16-bit hand-crafted code. This allows our two code domains
 * to interact, but it makes for weird 16-bit code (i.e. use of stack offsets to
 * parameters that look like those used in natural 32-bit code). We also would, for
 * example, lose 2 byte per call if the C-based code pushed 32-bits of return while
 * the hand-crafted 16-bit code only pulled 16-bits off the stack when ret'ing. Note
 * that now, even this hand-crafted 16-bit code, will push 4 bytes onto the stack
 * when calling, and also pull 4 bytes off the stack when ret'ing.
 *
 * Unfortunately, this _also_ means we must limit outselves to using the GAS assembler
*/
.code16gcc

_start:
jmp rml_s2_setup

.align 16
early_gdtr:
    .word early_gdt_end - early_gdt - 1
    .long early_gdt

.align 8
early_gdt:
    .quad 0x0000000000000000    // NULL selector
    .quad 0x00cf9a000000ffff    // DPL=0, 32-bit, flat 4GiB, code
    .quad 0x00cf92000000ffff    // DPL=0, 32-bit, flat 4Gib, data
    .quad 0x00009a000000ffff    // DPL=0, 16-bit, base=0, limit=0xffff (pm -> rm), code
    .quad 0x000092000000ffff    // DPL=0, 16-bit, base=0, limit=0xffff (pm -> rm), data
early_gdt_end:


rml_s2_setup:
    /* Let's get everything into a known state */
    mov sp, RMLS2_STACK
    xor ax, ax
    mov ss, ax
    mov ds, ax
    mov es, ax

    /*
     * From the Intel SDM (March 2018, section 9.9.1) "Switching to Protected Mode"
     * 1) Disable interrupts
     * 2) Execute LGDT to load the GDTR 
     * 3) Set the PE bit in CR0 
     * 4) Exeute a far jump to protected mode code (either 32 or 64 bit, depending on the GDT) 
     *      - The destination must be identity mapped if paging is also enabled during this step (PG bit)
     * 5) Execute LLDT to load the selector for the LDT into LDTR, if applicable 
     * 6) Execute LTR to load the task register, if applicable 
     * 7) Load the segment registers with the appropriate selectors (ES,FS,GS can be set to the NULL selector)
     * 8) Execute LIDT to load the protected mode IDT, if applicable 
     * 9) Reenable interrupts, if applicable
     */
    cli
    lgdt early_gdtr
    mov eax, cr0
    or al, 1
    mov cr0, eax
    ljmp 0x08, enter_pm

.code32
enter_pm:
    mov ax, 0x10
    mov ss, ax
    mov ds, ax 
    xor ax, ax
    mov es, ax 
    mov fs, ax 
    mov gs, ax 

    /* Initialize COM1 so we can debug our runtime */
    call serial_init

    //TODO: clear bss
    call rml_entry

/* We should never get here */
loop:
    hlt
    jmp loop


/*
 * Execute a specific interrupt with the register set specified by
 * the passed structure
 */
.global x86int
x86int:
    push ebp
    mov ebp, esp
    pushad          // Protect against badly written interrupt handlers
    push ss
    push ds
    push es
    push fs
    push gs

    /*
     * From the Intel SDM (March 2018, section 9.9.2) "Switching Back to Real-Address Mode"
     * 1) Disable interrupts
     * 2) If paging enabled:
     *      - Transfer control to linear addresses with identity mapped page table entries
     *      - Ensure GDT/IDT are in identity mapped pages
     *      - Clear PG bit in CR0
     *      - Flush TLB by setting CR3=0
     * 3) Transfer control to a GDT readable segment with a 64K (0xffff) limit
     * 4) Load segment registers with a selector entry with:
     *      - 64K limit, Byte granularity, Expand up, Writable, Present, Base=any
     * 5) Execute an LIDT instruction to load an IDT from the first 1MB of real-mode memory
     * 6) Clear PE in CR0
     * 7) Far jump to real-mode code (flushes the instruciton queue and reloads the CS base)
     * 8) Load the real-mode _segment_ registers with appropriate values
     * 9) Reenable interrupts, if applicable
     */

    /* Protected mode (32-bit) -> Real mode (16-bit) */
    ljmp 0x18, load_limited_rm_segment
load_limited_rm_segment:
    mov ax, 0x20
    mov ss, ax
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax

    mov eax, cr0
    and eax, 0xfffffffe
    mov cr0, eax

    ljmp 0x18, to_rm

.code16
to_rm:
    xor ax, ax
    mov ss, ax
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax

    /* 
     * Modify the immediate value in the int_instruction such
     * that we call the desired interrupt
     */
    mov ax, word ptr [bp + 0x0c]   // Offset of the interrupt number parameter
    lea di, int_instr
    mov byte ptr [di + 1], al

    /* Load the registers per the pased structure */
    mov di, word ptr [bp + 0x08]
    mov ax, word ptr [di + 0]
    mov bx, word ptr [di + 2]
    mov cx, word ptr [di + 4]
    mov dx, word ptr [di + 6]
    mov si, word ptr [di + 8]
    mov di, word ptr [di + 10]
    
int_instr:
    int 0 

    /* Move the return register state back into the structure */
    push di
    mov di, word ptr [bp + 0x08]
    mov word ptr [di + 0], ax
    mov word ptr [di + 2], bx
    mov word ptr [di + 4], cx
    mov word ptr [di + 6], dx
    mov word ptr [di + 8], si
    pop ax                      // original di
    mov word ptr [di + 10], ax
    mov ax, word ptr [di + 0]   // restore ax

    /* Real mode (16-bit) -> Protected mode (32-bit) */
    cli
    lgdt early_gdtr
    mov eax, cr0
    or al, 1
    mov cr0, eax
    ljmp 0x08, to_pm

.code32
to_pm:
    pop gs
    pop fs
    pop es
    pop ds
    pop ss

    popad
    mov esp, ebp
    pop ebp
    ret


/*
 * Writing a string to the serial port. Note that this routine blocks between
 * characters
 */
.global serial_puts
serial_puts:
    push bp 
    mov bp, sp

    // Get string address, test for NULL
    mov si, word ptr [bp + 6]
    mov al, byte ptr [si]  
    jz 2f
    
    // Walk the string until we find a NULL
1:  
    mov ah, 0
    push ax
    call serial_putc
    inc si
    mov al, byte ptr [si]
    test al, al
    jnz 1b

2:
    mov sp, bp
    pop bp
    ret


/*
 * Write a single character to the serial port. Note that this routine
 * blocks while waiting for thet transmit buffer to clear
 */
.global serial_putc
serial_putc:
    push ebp
    mov ebp, esp

    // Wait until the transmit buffer is empty
1:
    mov dx, 0x3fd
    inb al, dx
    test al, 0x20
    jz 1b

    // Send the character
    mov al, byte ptr [bp + 0x08]
    mov dx, 0x3f8
    outb dx, al

    mov esp, ebp
    pop ebp
    ret


/*
 * Initialize the _first_ serial port on the x86 platform (e.g. COM1/0x3f8)
 * Settings: 115200,8N1
 */
serial_init:
    // Disable interrupts
    mov dx, 0x3f9
    mov al, 0x00
    outb dx, al
   
    // Enable DLAB bit to allow baud rate to be set 
    mov dx, 0x3fb
    mov al, 0x80
    outb dx, al

    //Set divisor=1 (baud=115200) in to writes; LSB then MSB
    mov dx, 0x3f8
    mov al, 0x01
    outb dx, al
    inc dx
    xor al, al
    outb dx, al

    // Set 8bit trasfer, no parity, one stop bit (Also clears DLAB)
    mov dx, 0x3fb
    mov al, 0x03
    outb dx, al

    // Enable FIFO, clear, 14-byte threshold
    mov dx, 0x3fa
    mov al, 0xc7
    outb dx, al

    ret

