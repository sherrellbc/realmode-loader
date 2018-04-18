#include <vga.h>
#include <stdint.h>


void vga_textmode_print(char *str, uint8_t color)
{
    uint16_t vga_char;
    int offset = 0;

    for(; '\0' != *str; str++, offset+=2){
        vga_char = ((uint16_t) *str) | ((uint16_t) color << 8);
        *((uint16_t *)(0xB8000 + offset)) = vga_char;
    }
}


void fill_screen(uint8_t color)
{
    uint8_t *fb = (uint8_t *)0xa0000;
    for(int i=0; i<320; i++){
        for(int j=0; j<200; j++){
            *(fb + i*j) = color;
        }
    }
}
