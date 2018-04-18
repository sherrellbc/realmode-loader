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

rml_s2_setup:
    /* Let's get everything into a known state */
    mov sp, RMLS2_STACK
    xor ax, ax
    mov ss, ax
    mov ds, ax
    mov es, ax

    //TODO: Switch to 32 bit code 
    //TODO: clear bss

    // Initialize COM1 
    call serial_init
    call rml_entry

loop:
    hlt
    jmp loop


.global put_pixel
put_pixel:
# ah = 0x0c
# al = color
# bh = page
# cx = x
# dx = y
    push bp
    mov bp, sp
    mov cx, word ptr [bp + 6]   // X
    mov dx, word ptr [bp + 10]   // Y
    mov ax, word ptr [bp + 14]  // Color
    mov bx, 0
    mov ah, 0x0c
    int 0x10
    mov sp, bp
    pop bp
    ret


/*
 * Execute a specific interrupt with the register set specified by
 * the passed structure
 */
.global x86int
x86int:
    push bp
    mov bp, sp

    /* 
     * Modify the immediate value in the int_instruction such
     * that we call the desired interrupt
     */
    mov ax, word ptr [bp + 10]   // interrupt number
    lea di, int_instruction
    mov byte ptr [di + 1], al

    mov di, word ptr [bp + 6]
    mov ax, word ptr [di + 0]
    mov bx, word ptr [di + 2]
    mov cx, word ptr [di + 4]
    mov dx, word ptr [di + 6]
    mov si, word ptr [di + 8]
    mov di, word ptr [di + 10]
    
int_instruction:
    int 0 

    mov sp, bp
    pop bp
    ret

int10:
    int 0x10
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
    jz 1f
    
    // Walk the string until we find a NULL
1:  
    mov ah, 0
    push ax
    call serial_putc
    inc si
    mov al, byte ptr [si]
    test al, al
    jnz 1b

1:
    mov sp, bp
    pop bp
    ret

/*
 * Write a single character to the serial port
 */
.global serial_putc
serial_putc:
    push bp
    mov bp, sp

    // Wait until the transmit buffer is empty
1:
    mov dx, 0x3fd
    inb al, dx
    test al, 0x20
    jz 1b

    // Send the character
    mov al, byte ptr [bp + 6]
    mov dx, 0x3f8
    outb dx, al

    mov sp, bp
    pop bp
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

