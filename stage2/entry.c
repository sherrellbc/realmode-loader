#include <stdint.h>
#include <stdio.h>
#include <vesa.h>
#include <rml_debug.h>


void rml_entry(void)
{
    rml_print("\n ******* Realmode Loader final stage ******* \n"); 
    vesa_setmode();
}
