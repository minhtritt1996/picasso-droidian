#include <time.h>

struct pollfd {
    int fd;
    short events;
    short revents;
};
typedef unsigned long nfds_t;

#define POLLNVAL 0x0020

static inline long sys_ppoll(struct pollfd *fds, nfds_t nfds,
                             const struct timespec *tmo_p,
                             const void *sigmask) {
    register long x0 __asm__("x0") = (long)fds;
    register long x1 __asm__("x1") = (long)nfds;
    register long x2 __asm__("x2") = (long)tmo_p;
    register long x3 __asm__("x3") = (long)sigmask;
    register long x4 __asm__("x4") = 8; /* Android/Linux kernel sigsetsize = 8 */
    register long x8 __asm__("x8") = 73; /* __NR_ppoll on aarch64 */
    __asm__ __volatile__(
        "svc #0\n"
        : "=r"(x0)
        : "r"(x0), "r"(x1), "r"(x2), "r"(x3), "r"(x4), "r"(x8)
        : "memory"
    );
    return x0;
}

static inline int filter_pollnval(struct pollfd *fds, nfds_t nfds, int ret) {
    if (ret > 0 && fds) {
        for (nfds_t i = 0; i < nfds; i++) {
            if (fds[i].revents & POLLNVAL) {
                fds[i].fd = -1;
                fds[i].revents = 0;
                ret--;
            }
        }
    }
    return ret;
}

int ppoll(struct pollfd *fds, nfds_t nfds, const struct timespec *tmo_p, const void *sigmask) {
    int ret = (int)sys_ppoll(fds, nfds, tmo_p, sigmask);
    return filter_pollnval(fds, nfds, ret);
}

int poll(struct pollfd *fds, nfds_t nfds, int timeout) {
    struct timespec ts;
    struct timespec *tmo_p = (void*)0;
    if (timeout >= 0) {
        ts.tv_sec = timeout / 1000;
        ts.tv_nsec = (long)(timeout % 1000) * 1000000L;
        tmo_p = &ts;
    }
    int ret = (int)sys_ppoll(fds, nfds, tmo_p, (void*)0);
    return filter_pollnval(fds, nfds, ret);
}
