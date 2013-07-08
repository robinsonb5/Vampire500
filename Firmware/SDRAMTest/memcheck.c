#include <stdio.h>
#include <string.h>
#include <malloc.h>

#include "minisoc_hardware.h"

#ifndef DEBUG
#include "small_printf.h"
#endif

//#define CYCLE_LFSR {lfsr<<=1; if(lfsr&0x80000000) lfsr|=1; if(lfsr&0x10000000) lfsr^=1;}

//#define CYCLE_LFSR {lfsr<<=1; if(lfsr&0x80000000) lfsr|=1; if(lfsr&0x10000000) lfsr^=1;}
#define CYCLE_LFSR {lfsr<<=1; if(lfsr&0x400000) lfsr|=1; if(lfsr&0x200000) lfsr^=1;}

// Force a read-read of cache contents.  Takes the size of the cache (in bytes) as a parameter.
// Works using a brute-force read of four times as much data as will fit in the cache, ensuring
// that everything has to be flushed out.
void refreshcache(volatile int *base,int size)
{
	int t;
	int i;

	for(i=0;i<size;++i)
		t=*base++;
}


// Sanity check.  First stage check, writes and reads a bit pattern, and ensures that the same
// bit pattern is read back, before and after a cache refresh.

static const int sanitycheck_bitpatterns[]={0x00000000,0x55555555,0xaaaaaaaa,0xffffffff};

int sanitycheck(volatile int *base,int cachesize)
{
	int result=1;
	int i;
	for(i=0;i<(sizeof(sanitycheck_bitpatterns)/sizeof(int));++i)
	{
		*base=sanitycheck_bitpatterns[i];
		if (*base!=sanitycheck_bitpatterns[i])
		{
			printf("Sanity check failed (before cache refresh) on %d\n",sanitycheck_bitpatterns[i]);
			result=0;
		}
		refreshcache(base,cachesize);
		if (*base!=sanitycheck_bitpatterns[i])
		{
			printf("Sanity check failed (after cache refresh) on %d\n",sanitycheck_bitpatterns[i]);
			result=0;
		}
	}
	return(result);
}

#define LFSRSEED 12467

int lfsrcheck(volatile int *base)
{
	int result;
	int cycles=15;

	printf("Checking memory...\n");

	unsigned int lfsr=LFSRSEED;
	while(--cycles)
	{
		int i;
		unsigned int lfsrtemp=lfsr;
		for(i=0;i<262144;++i)
		{
			unsigned int w=lfsr&0xfffff;
			unsigned int j=lfsr&0xfffff;
			CYCLE_LFSR;
			unsigned int x=lfsr&0xfffff;
			unsigned int k=lfsr&0xfffff;
			base[j]=w;
			base[k]=x;
			CYCLE_LFSR;
		}
		lfsr=lfsrtemp;
		for(i=0;i<262144;++i)
		{
			unsigned int w=lfsr&0xfffff;
			unsigned int j=lfsr&0xfffff;
			CYCLE_LFSR;
			unsigned int x=lfsr&0xfffff;
			unsigned int k=lfsr&0xfffff;
			if(base[j]!=w)
			{
				result=0;
				printf("Error at %x\n",w);
				printf("expected %x, got %x\n",w,base[j]);
			}
			if(base[k]!=x)
			{
				result=0;
				printf("Error at %x\n",w);
				printf("expected %x, got %x\n",w,base[k]);
			}
			CYCLE_LFSR;
		}
	}
	return(result);
}


// Check for bad address bits and aliases.

int addresscheck(volatile int *base,int cachesize)
{
	int result=1;
	int i,j,k;
	int a1,a2;
	int aliases=0;
	int size=64;
	// Seed the RAM;
	a1=1;
	*base=0x5555aaaa;
	for(j=1;j<25;++j)
	{
		a2=1;
		for(i=1;i<25;++i)
		{
			base[a1|a2]=0x5555aaaa;
			a2<<=1;
		}
		a1<<=1;
	}	
	refreshcache(base,cachesize);

	// Now check for aliases
	a1=1;
	*base=0xf0f0f0f0;
	for(j=1;j<25;++j)
	{
		a2=0;
//		a2=1;
//		for(i=1;i<25;++i)
//		{
			if(base[a1|a2]==0xf0f0f0f0)
			{
				result=0;
				aliases|=a1|a2;
			}
			else if(base[a1|a2]!=0x5555aaaa)
			{
				result=0;
				printf("Bad data found at %d (%d)\n",(a1|a2)<<2, base[a1|a2]);
			}
			a2<<=1;
//		}
		a1<<=1;
	}
	if(aliases)
		printf("Aliases found at %d\n",aliases<<2);

	while(aliases)
	{
		aliases=(aliases<<1)&0xffffff;	// Test currently supports up to 16m longwords = 64 megabytes.
		size>>=1;
	}
	printf("SDRAM size (assuming no address faults) is %d megabytes\n",size);
	
	return(result);
}


#define CACHESIZE 4096

int main(int argc, char **argv)
{
	volatile int *base=0;
#ifdef DEBUG
	base=(volatile int *)malloc(64*1024*1024);	// Standalone, buildable on Linux for testing
#else
	HW_PER(PER_UART_CLKDIV)=1250000/1152;	// Running on the ZPU
#endif

	if(sanitycheck(base,CACHESIZE))
		printf("First stage sanity check passed.\n");
	if(addresscheck(base,CACHESIZE))
		printf("Address check passed.\n");
	if(lfsrcheck(base))
		printf("LFSR check passed.\n");

	return(0);
}

