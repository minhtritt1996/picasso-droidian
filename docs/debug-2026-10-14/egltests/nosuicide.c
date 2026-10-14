#define _GNU_SOURCE
#include <stdio.h>
#include <unistd.h>
#include <signal.h>
#include <sys/prctl.h>
#include <linux/seccomp.h>
#include <linux/filter.h>
#include <sys/syscall.h>
#define A2 32
int main(int argc, char **argv, char **envp) {
  if (argc < 2) { printf("usage: nosuicide cmd...\n"); return 1; }
  struct sock_filter f[] = {
    BPF_STMT(BPF_LD | BPF_W | BPF_ABS, 0),
    BPF_JUMP(BPF_JMP | BPF_JEQ | BPF_K, __NR_tgkill, 0, 3),
    BPF_STMT(BPF_LD | BPF_W | BPF_ABS, A2),
    BPF_JUMP(BPF_JMP | BPF_JEQ | BPF_K, SIGKILL, 0, 1),
    BPF_STMT(BPF_RET | BPF_K, SECCOMP_RET_ERRNO | 1),
    BPF_STMT(BPF_RET | BPF_K, SECCOMP_RET_ALLOW),
  };
  struct sock_fprog p = { 6, f };
  if (prctl(PR_SET_NO_NEW_PRIVS, 1, 0, 0, 0)) { perror("nonewprivs"); return 1; }
  if (prctl(PR_SET_SECCOMP, SECCOMP_MODE_FILTER, &p)) { perror("seccomp"); return 1; }
  execvpe(argv[1], argv+1, envp);
  perror("exec");
  return 1;
}
