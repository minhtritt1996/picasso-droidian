# Kernel config rationale (picasso_defconfig, lineage-18.1 base)

## Must stay as-is (each violated once, each caused silent SoC resets)
- `MODVERSIONS=n`, `SIG_FORCE=n` — vendor .ko load (vermagic patched at runtime)
- `LOCALVERSION=-lineage-picasso`, `LOCALVERSION_AUTO=n` — stable vermagic
  (git auto-abbrev changed length between builds, breaking all modules)
- `REMOTEPROC=n` — kills container-alone ~70s after start (bisect-proven)
- `QCA_CLD_WLAN=y` (built-in) — vendor wifi needs its side effects at FW-attach
- No `console=` on cmdline (ttyMSM0 never binds; VT default works)

## DroidSpaces
- ON (tested, wifi-safe): namespaces, seccomp, cgroups base, overlay,
  veth/bridge/iptables NAT44, IPv6 base, macvlan, user-ns, MEMCG, CPUACCT,
  DEVTMPFS, FW_LOADER.
- OFF (deferred, each singly-or-combined crashes vendor wifi FW-attach):
  POSIX_MQUEUE, CGROUP_NET_PRIO, CFS_BANDWIDTH, CGROUP_PIDS,
  NF_TABLES, BRIDGE_NETFILTER, IP6_NF_NAT/NF_NAT_IPV6, IP_SET*,
  MATCH_RECENT. Prime suspect: MQUEUE (GKI docs warn of task_struct shifts).
- Non-GKI patches applied (docs: harmless, kept): xt_qtaguid panic,
  cgroup prefix restore.
