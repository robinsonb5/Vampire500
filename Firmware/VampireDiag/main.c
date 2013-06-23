#include "small_printf.h"

#include "md5.h"

int main(int argc, char **argv) {
    char *msg = argv[1];
    size_t len;
    int i;
    unsigned char result[16];
 
    if (argc < 2) {
        printf("usage: %s 'string'\n", argv[0]);
        return 1;
    }
 
    len = strlen(msg);
 
    // benchmark
//    for (i = 0; i < 1000000; i++) {
        md5((unsigned char*)msg, len, result);
//    }
 
    // display result
    for (i = 0; i < 16; i++)
        printf("%2.2x", result[i]);
    puts("");
 
    return 0;
}

