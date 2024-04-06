// Based on https://abyz.me.uk/rpi/pigpio/examples.html#Misc_minimal_gpio

#include <stdio.h>
#include <unistd.h>
#include <stdint.h>
#include <stdlib.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <linux/i2c-dev.h>
#include <sys/ioctl.h>

static void checkHardwareRevision(void)
{
	uint32_t piPeriphBase;
	FILE *filp;
	char buf[512];

	if ((filp = fopen("/proc/device-tree/soc/ranges", "rb"))) {
		if (fread(buf, 1, sizeof(buf), filp) >= 8) {
			piPeriphBase = buf[4] << 24 | buf[5] << 16 | buf[6] << 8 | buf[7];
			if (!piPeriphBase) {
				piPeriphBase = buf[8] << 24 | buf[9] << 16 | buf[10] << 8 | buf[11];
			}

			if (piPeriphBase != 0xFE000000) {
				fprintf(stderr, "Only Pi 4 is supported (got %lx).\n", (unsigned long)piPeriphBase);
				exit(1);
			}
		} else {
			fprintf(stderr, "Only Pi 4 is supported.\n");
			exit(1);
		}
		fclose(filp);
	} else {
		fprintf(stderr, "Only Pi 4 is supported.\n");
		exit(1);
	}
}

static uint32_t *initMapMem(int fd, uint32_t addr, uint32_t len)
{
	return (uint32_t *)mmap(0, len, PROT_READ | PROT_WRITE | PROT_EXEC, MAP_SHARED | MAP_LOCKED, fd, addr);
}

void *helperGpioInitialise(void)
{
	int fd;
	uint32_t *gpioReg = MAP_FAILED;

	checkHardwareRevision(); /* sets rev and peripherals base address */

	fd = open("/dev/mem", O_RDWR | O_SYNC);

	if (fd < 0) {
		fprintf(stderr, "This program needs root privileges.  Try using sudo\n");
		exit(1);
	}

	gpioReg = initMapMem(fd, 0xFE200000, 0xF4);

	close(fd);

	if (gpioReg == MAP_FAILED) {
		fprintf(stderr, "mmap failed\n");
		exit(1);
	}
	return gpioReg;
}

void helperLockMemory(void)
{
	if (mlockall(MCL_CURRENT | MCL_FUTURE)) {
		fprintf(stderr, "mlockall failed\n");
		exit(1);
	}
}

int helperI2cInitialise(void)
{
	int fd = open("/dev/i2c-22", O_RDWR);

	if (fd < 0) {
		fprintf(stderr, "i2c open failed\n");
		exit(1);
	}

	if (ioctl(fd, I2C_SLAVE, 115) < 0) {
		fprintf(stderr, "i2c ioctl failed\n");
		exit(1);
	}

	return fd;
}
