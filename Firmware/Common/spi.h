#ifndef SPI_H
#define SPI_H

int spi_init();
int sd_read_sector(unsigned long lba,unsigned char *buf);
int sd_write_sector(unsigned long lba,unsigned char *buf); // FIXME - stub

#endif
