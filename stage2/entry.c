#include <stdint.h>
#include <vesa.h>
#include <rml_debug.h>
#include <x86_reg.h>


void rml_entry(void)
{
    serial_puts("We made it to rml_entry!\n");
    vesa_setmode();
}
