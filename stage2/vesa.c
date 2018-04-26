#include <vesa.h>
#include <rml_debug.h>
#include <x86_reg.h>
#include <stdio.h>
#include <string.h>

#define VBE2_SIG    0x32454256      // "VBE2", Little Endian
#define VESA_SIG    0x41534556      // "VESA", Little Endian

void vesa_fillscreen_fb(uint32_t color);

void vesa_setmode(void){
    struct x86_reg reg = {0};
    struct vbe_info vi = {0};
    struct vbe_mode_info vmi = {0};
    char buf[256];

    vi.sig = VBE2_SIG;
    memset(&reg, 0, sizeof(struct x86_reg));
    reg.ax = 0x4f00;
    reg.di = (((uint32_t)(&vi)) & 0xffff);
    x86int(&reg, 0x10);
    
    if(VESA_SIG == vi.sig){
        snprintf(buf, sizeof(buf), "Successful VESA call: 0x%x\n", vi.sig);
        serial_puts(buf);
    }

    for(unsigned int i=0; i<sizeof(vi.res)/sizeof(uint16_t); i++){
        memset(&reg, 0, sizeof(struct x86_reg));
        reg.ax = 0x4f01;
        reg.cx = ((uint16_t *)vi.res)[i];
        reg.di = (((uint32_t)(&vmi)) & 0xffff);
        x86int(&reg, 0x10);

        if(0x004f != reg.ax){
            snprintf(buf, sizeof(buf), "Bad VESA call. End of video modes\n");
            serial_puts(buf);
            break;
       }

        snprintf(buf, sizeof(buf), "Mode 0x%x: %dx%d, bpp: 0x%hhx, Loc: 0x%x\n", ((uint16_t *)vi.res)[i], vmi.width, vmi.height, vmi.bpp, vmi.framebuffer);
        serial_puts(buf);

        if( (1024 == vmi.width) && (768 == vmi.height) && (24 == vmi.bpp) ){
            memset(&reg, 0, sizeof(struct x86_reg));
            reg.ax = 0x4f02;
            reg.bx = (1 << 14) | ((uint16_t *)vi.res)[i];
            reg.di = (((uint32_t)(&vmi)) & 0xffff);

            snprintf(buf, sizeof(buf), "Setting mode 0x%hx; sending bx = 0x%hx\n", ((uint16_t *)vi.res)[i], reg.bx);
            serial_puts(buf);

            x86int(&reg, 0x10);
            break;
        }
    }

    vesa_fillscreen_fb(0x00dd0bba);
}

void vesa_fillscreen_fb(uint32_t color)
{
    struct rgb {
        uint8_t blue;
        uint8_t green;
        uint8_t red;
    } __attribute__((packed));
    struct rgb *fb = (struct rgb *)0xfc000000;
    
    for(int i=0; i<1024; i++){
        for(int j=0; j<768; j++){
           fb[i + j*1024 + 0].red = (uint8_t) ( (color >> 16) & 0xff);
           fb[i + j*1024 + 1].green = (uint8_t) ( (color >> 8) & 0xff);
           fb[i + j*1024 + 2].blue = (uint8_t) ( color & 0xff);
        }
    }
}
