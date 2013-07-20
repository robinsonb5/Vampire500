#include "minisoc_hardware.h"

#ifndef DISABLE_UART_TX
__inline int putchar(int c)
{
	while(!(HW_PER(PER_UART)&(1<<PER_UART_TXREADY)))
		;
	HW_PER(PER_UART)=c;
	return(c);
}

int puts(const char *msg)
{
	int result=0;
	while(*msg)
	{
		putchar(*msg++);
		++result;
	}
	return(result);
}
#endif

#ifndef DISABLE_UART_RX
char getserial()
{
	int r=0;
	while(!(r&(1<<PER_UART_RXINT)))
		r=HW_PER(PER_UART);
	return(r);
}
#endif

