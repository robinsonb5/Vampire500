#ifndef SMALL_PRINTF_H
#define SMALL_PRINTF_H

#include "minisoc_hardware.h"

#ifdef DISABLE_PRINTF
#define small_printf(x,...)
#define printf(x,...)
#else
int small_printf(const char *fmt, ...);
#define printf small_printf
#endif

#define puts(x) putserial(x)

#endif

