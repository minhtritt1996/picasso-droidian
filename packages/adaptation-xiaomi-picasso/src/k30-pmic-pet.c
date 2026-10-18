#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <string.h>
#include <sched.h>
#include <sys/resource.h>
#include <sys/mount.h>
#include <time.h>
#include <syslog.h>
#include <errno.h>

int main(void) {
    openlog("k30-pmic-pet", LOG_PID | LOG_CONS, LOG_DAEMON);
    syslog(LOG_INFO, "k30-pmic-pet watchdog guardian started");

    setpriority(PRIO_PROCESS, 0, -20);
    struct sched_param sp;
    sp.sched_priority = 90;
    sched_setscheduler(0, SCHED_RR, &sp);

    mount("none", "/sys/kernel/debug", "debugfs", 0, NULL);

    const char *reg_path = "/sys/kernel/debug/regmap/spmi0-02/registers";
    const char *cmd_dis = "0x1651 0x00\n";
    const char *cmd_pet = "0x1643 0x01\n";
    size_t len_dis = strlen(cmd_dis);
    size_t len_pet = strlen(cmd_pet);

    int fd = open(reg_path, O_WRONLY);
    if (fd < 0) {
        syslog(LOG_ERR, "Failed to open %s at startup: %m", reg_path);
    } else {
        syslog(LOG_INFO, "Successfully opened %s (fd=%d), keeping permanent handle", reg_path, fd);
        write(fd, cmd_dis, len_dis);
        write(fd, cmd_pet, len_pet);
    }

    int fail_count = 0;
    while (1) {
        if (fd < 0) {
            fd = open(reg_path, O_WRONLY);
            if (fd >= 0) {
                syslog(LOG_INFO, "Reopened %s (fd=%d)", reg_path, fd);
                fail_count = 0;
            } else {
                fail_count++;
                if (fail_count % 10 == 0) {
                    syslog(LOG_ERR, "CRITICAL: Unable to open %s for %d attempts: %m", reg_path, fail_count);
                }
            }
        }

        if (fd >= 0) {
            ssize_t w1 = write(fd, cmd_dis, len_dis);
            ssize_t w2 = write(fd, cmd_pet, len_pet);
            if (w1 < 0 || w2 < 0) {
                syslog(LOG_ERR, "Write to PMIC failed: w1=%zd, w2=%zd: %m", w1, w2);
                close(fd);
                fd = -1;
            }
        }

        usleep(500000);
    }
    return 0;
}
