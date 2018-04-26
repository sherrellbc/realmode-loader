#include <stdarg.h>
#include <stdio.h>
#include <rml_debug.h>


int rml_print(const char *format, ...)
{
    static char buf[1024]; //TODO: remove this static buffer requirement
    int ret;

    va_list arg;
    va_start(arg, format);
    ret = vsnprintf(buf, sizeof(buf), format, arg);
    va_end(arg);

    serial_puts(buf);
    return ret;
}
