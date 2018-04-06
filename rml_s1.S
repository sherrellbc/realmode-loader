.intel_syntax noprefix

#define RMLS2_STACK       0x2000
#define RMLS2_RELOC_ADDR  0x0600

.section .text
.code16

jmp _start

/*
 * Disk Address Packet
 * 
 * struct {
 *     uint8_t  size;
 *     uint8_t  pad; 
 *     uint16_t block_count;
 *     uint16_t offset;
 *     uint16_t segment;
 *     uint32_t lba_lower;
 *     uint32_t lba_upper;
 * }
 */
.align 2
da_packet:
    .byte 0x10      // Size of this structure
    .byte 0x00      // Zero
da_blk_cnt:
    .word 0x0000    // Number of blocks to read
da_buf:
    .word 0x0000    // Offset
    .word 0x0000    // Segment

da_lba_addr:
    .long 0x00000000 // Logical Block Address (LBA) to read (lower)
    .long 0x00000000 // 64-bit flat address of trasnfer buffer (used if dword at 0x04 is ffff:ffff and EDD-3.0)

loaded_lba_low:    .word 0x0000
loaded_lba_high:   .word 0x0000


//TODO: explain the ABI here
_start:

    /* Then relocate ourselves to make room for stage 3 */
    push cx
    mov si, 0x7c00
    mov di, RMLS2_RELOC_ADDR
    mov cx, 0x200
    rep movsw
    pop cx

    /* The MBR jumps to us with ((cx << 16) | dx)=LBA of disk 0x80 where we were loaded from */
    lea si, loaded_lba_low
    mov word ptr [si + 0], dx
    mov word ptr [si + 2], cx
    jmp 0x0,relocated_start // This works _only if_ we are linked at this relocated address

relocated_start:
    /* Let's get everything into a known state */
    mov sp, RMLS2_STACK
    xor ax, ax
    mov ss, ax
    mov ds, ax
    mov es, ax

    /* 
     * Check to see if the LBA/DA packet extensions exist. This
     * is currently the only case this MBR stage handles.
     * TODO: Use CHS from the MBR
     */
    call check_int13_extensions
    jnz no_int13_ext_support

    /* Load the second stage of the bootloader and jump there */
    call load_stage2
    test ax, ax
    jnz error_loop    
    jmp 0x0,0x7c00
    

no_int13_ext_support:
    //Print characters
error_loop:
    cli
    hlt
    jmp error_loop

/*
 * Determine if the LBA extensions are suppored for the first disk (0x80)
 * ax = 0 (success) or non-zero (error) on return
 */
check_int13_extensions:
    mov ah, 0x41
    mov bx, 0x55aa
    mov dl, 0x80
    int 0x13
    jc err_or_unsupported
    cmp bx, 0xaa55
    jnz err_or_unsupported
    mov ax, 0
    jmp ext_determined

err_or_unsupported:
    mov ax, 0xffff
ext_determined:
    ret

/*
 * Uses the LBA extensions to read from the first disk (0x80).
 * si = address of DA packet structure
 * ax = 0 (success) or non-zero (error) on return
 */
sector_read:
    mov ah, 0x42
    mov dl, 0x80
    int 0x13
    shr ah, 4  // return
    ret

/*
 * Load the stage2 bootloader
 *
 * The MBR code would have left the LBA of where we were loaded 
 * from in dx (upper) and cx (lower). The disk we were loaded from is
 * also available in bx. So, to load the final stage we just have to load 
 * from block ((dx << 16) + cx) + 1!
 */
load_stage2:
    lea si, loaded_lba_low
    mov dx, word ptr [si + 0]
    mov cx, word ptr [si + 2]
    add dx, 1
    adc cx, 0   // In case of overflow
    lea si, da_packet
    mov byte ptr [si + 2],  0x01    // Data block count
    mov word ptr [si + 4],  0x7c00  // Offset
    mov word ptr [si + 6],  0x0000  // Segment
    mov word ptr [si + 8],  dx      // LBA (lower)
    mov word ptr [si + 10], cx      // LBA (upper)

    call sector_read
    ret

# Pad the loader out to 512 bytes (510 + 2 bytes for the signature)
.org 510
.word 0xaa55
