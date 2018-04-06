#include <stdint.h>

enum vga_color {
	VGA_COLOR_BLACK =           0,
	VGA_COLOR_BLUE =            1,
	VGA_COLOR_GREEN =           2,
	VGA_COLOR_CYAN =            3,
	VGA_COLOR_RED =             4,
	VGA_COLOR_MAGENTA =         5,
	VGA_COLOR_BROWN =           6,
	VGA_COLOR_LIGHT_GREY =      7,
	VGA_COLOR_DARK_GREY =       8,
	VGA_COLOR_LIGHT_BLUE =      9,
	VGA_COLOR_LIGHT_GREEN =     10,
	VGA_COLOR_LIGHT_CYAN =      11,
	VGA_COLOR_LIGHT_RED =       12,
	VGA_COLOR_LIGHT_MAGENTA =   13,
	VGA_COLOR_LIGHT_BROWN =     14,
	VGA_COLOR_WHITE =           15,
};


void print(char *str, uint8_t color)
{
    uint16_t vga_char;
    int offset = 0;

    for(; '\0' != *str; str++, offset+=2){
        vga_char = ((uint16_t) *str) | ((uint16_t) color << 8);
        *((uint16_t *)(0xB8000 + offset)) = vga_char;
    }
}

void rml_entry(void)
{
    print("We made it!", VGA_COLOR_LIGHT_MAGENTA);
    volatile int test = 0;
    while(!test);
}
