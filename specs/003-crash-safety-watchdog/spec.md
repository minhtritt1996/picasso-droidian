# Feature Specification: Kernel Oops & Watchdog Reboot Elimination

**Feature ID**: 003-crash-safety-watchdog  
**Status**: Implemented & Verified  
**Component**: Linux Kernel 4.19 / `sysctl` / `adaptation-xiaomi-picasso`

## 1. Context & User Story
* **As a** user running Droidian on Xiaomi Redmi K30 5G (`picasso`),  
* **I want** application crashes (e.g. SIGSEGV, SIGABRT) to terminate cleanly with standard exit codes without crashing the Linux kernel or triggering hardware watchdog reboots,  
* **So that** the phone remains completely stable, reachable via SSH, and responsive even if user-space applications encounter faults.

## 2. Requirements & Acceptance Criteria
1. **Crash Handling Isolation**:
   - Crashing a user process (e.g., `kill -SEGV $$`) must exit cleanly with code `139`.
   - Kernel dmesg must show zero Translation Fault Oops, zero null pointer dereferences in `call_usermodehelper`, and zero watchdog bite resets.
2. **Persistence Across Reboots**:
   - `/etc/sysctl.d/99-disable-coredump.conf` applied automatically during boot.
   - Postinst script sets `kernel.core_pattern = core` and `fs.suid_dumpable = 0`.
3. **Safety Constraints**:
   - Never use pipe helpers (`|/bin/...`).
   - Never point `core_pattern` directly to `/dev/null` (which causes truncation of device nodes).

## 3. Architecture & Root Cause Analysis
* **Root Cause**:
  - Upstream configuration used `kernel.core_pattern = |/bin/false`.
  - In Linux 4.19 `fs/coredump.c`, whenever `core_pattern` begins with `|`, kernel `rlimit` checks are bypassed and `call_usermodehelper` is spawned.
  - On Qualcomm downstream 4.19 kernels, this helper triggers a Translation Fault Oops (`Unable to handle kernel paging request`), which panics the kernel or stalls the IPC thread, triggering MSM watchdog timeout reboot after 5 seconds.
* **Resolution**:
  - Configured `kernel.core_pattern = core` (no pipe) with `fs.suid_dumpable = 0`.
  - With `rlimit_core = 0` (default for systemd sessions), the kernel detects rlimit 0 before attempting any core dump operations, skipping file creation and process spawning entirely.
