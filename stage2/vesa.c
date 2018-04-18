#include <vesa.h>
#include <rml_debug.h>
#include <x86_reg.h>


void vesa_setmode(void){
    struct x86_reg reg = {0};
    struct vbe_info vi;
    struct vbe_mode_info vmi;

    vi.sig = 0x32454256;
    reg.ax = 0x4f00;
    reg.bx = 0;
    reg.cx = 0;
    reg.dx = 0;
    reg.si = 0;
    reg.di = (((uint32_t)(&vi)) & 0xffff);
    x86int(&reg, 0x10);
    
    if(0x41534556 == vi.sig){
        serial_puts("Successful VESA call!");
    }   

    reg.ax = 0x4f01;
    reg.bx = 0;
    reg.cx = ((uint16_t *)vi.res)[0];
    reg.dx = 0;
    reg.si = 0;
    reg.di = (((uint32_t)(&vmi)) & 0xffff);
    x86int(&reg, 0x10);

}

