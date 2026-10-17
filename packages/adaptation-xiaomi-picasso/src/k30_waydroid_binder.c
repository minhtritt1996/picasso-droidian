#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <unistd.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/stat.h>
#include <sys/mount.h>
#include <linux/types.h>

#define BINDERFS_MAX_NAME 255

/* Linux 4.19 downstream binderfs device request struct */
struct binderfs_device_k419 {
    char name[BINDERFS_MAX_NAME + 1];
    __u8 major;
    __u8 minor;
};

#define BINDER_CTL_ADD_K419 _IOWR('b', 1, struct binderfs_device_k419)

static const char *NODES[] = {
    "anbox-binder",
    "anbox-vndbinder",
    "anbox-hwbinder"
};

int main(void) {
    int fd = open("/dev/binderfs/binder-control", O_RDWR);
    if (fd < 0) {
        mkdir("/dev/binderfs", 0755);
        mount("binder", "/dev/binderfs", "binder", 0, NULL);
        fd = open("/dev/binderfs/binder-control", O_RDWR);
    }
    if (fd < 0) {
        perror("open /dev/binderfs/binder-control");
        return 1;
    }

    for (size_t i = 0; i < sizeof(NODES) / sizeof(NODES[0]); i++) {
        const char *name = NODES[i];
        char bpath[256];
        char dpath[256];
        snprintf(bpath, sizeof(bpath), "/dev/binderfs/%s", name);
        snprintf(dpath, sizeof(dpath), "/dev/%s", name);

        struct binderfs_device_k419 dev;
        memset(&dev, 0, sizeof(dev));
        strncpy(dev.name, name, sizeof(dev.name) - 1);

        if (ioctl(fd, BINDER_CTL_ADD_K419, &dev) < 0) {
            /* Node may already exist */
        }

        chmod(bpath, 0666);
        unlink(dpath);
        (void)symlink(bpath, dpath);
    }

    close(fd);
    return 0;
}
