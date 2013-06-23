#include "minisoc_hardware.h"

#include <stdarg.h>

#ifndef DISABLE_PRINTF

static char temp[80];

static int
_cvt(unsigned int val, char *buf, int radix, char *digits)
{
    char *cp = temp;
    int length = 0;

    if (val == 0) {
        /* Special case */
        *cp++ = '0';
    } else {
        while (val) {
#ifdef PRINTF_HEX_ONLY
            *cp++ = digits[val &15]; // % radix];
            val >>=4; // /= radix;
#else
            *cp++ = digits[val % radix];
            val /= radix;
#endif
        }
    }
    while (cp != temp) {
        *buf++ = *--cp;
        length++;
    }
    *buf = '\0';
    return (length);
}

#define is_digit(c) ((c >= '0') && (c <= '9'))


char vpfbuf[sizeof(long long)*8];

static int
_vprintf(void (*putc)(char c, void **param), void **param, const char *fmt, va_list ap)
{
    char c, sign, *cp=vpfbuf;
    int left_prec, right_prec, zero_fill, pad, pad_on_right, 
        i, islong, islonglong;
    unsigned int val = 0;
    int res = 0, length = 0;

    while ((c = *fmt++) != '\0') {
		char tmp[2];
        if (c == '%') {
            c = *fmt++;
            left_prec = right_prec = pad_on_right = islong = islonglong = 0;
            sign = '\0';
            // Fetch value [numeric descriptors only]
            switch (c) {
            case 'd':
                    val = (long)va_arg(ap, unsigned int);
                break;
            default:
                break;
            }
            // Process output
            switch (c) {
            case 'd':
                switch (c) {
                case 'd':
                    length = _cvt(val, vpfbuf, 10, "0123456789ABCDEF");
                    break;
                }
                cp = vpfbuf;
                break;
            case 's':
                cp = va_arg(ap, char *);
                length = 0;
                while (cp[length] != '\0') length++;
                break;
            case 'c':
                c = va_arg(ap, int /*char*/);
                (*putc)(c, param);
                res++;
                continue;
            default:
                (*putc)('%', param);
                (*putc)(c, param);
                res += 2;
                continue;
            }
            while (length-- > 0) {
                c = *cp++;
                (*putc)(c, param);
                res++;
            }
        } else {
            (*putc)(c, param);
            res++;
        }
    }
    return (res);
}


// Default wrapper function used by diag_printf
static void
_diag_write_char(char c, void **param)
{
	while(!(HW_PER(PER_UART)&(1<<PER_UART_TXREADY)))
		;
	HW_PER(PER_UART)=c;
}


int
small_printf(const char *fmt, ...)
{
    va_list ap;
    int ret;

    va_start(ap, fmt);
    ret = _vprintf(_diag_write_char, (void **)0, fmt, ap);
    va_end(ap);
    return (ret);
}
#endif

