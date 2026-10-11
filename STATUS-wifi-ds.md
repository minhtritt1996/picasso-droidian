# WiFi + DroidSpaces final status
## WiFi: WORKS (automated)
- Kernel: bis8-equivalent (4.19.113-lineage-picasso+, CLD builtin ON,
  REMOTEPROC/RTB/core-4/netfilter-7 OFF, DS patches reverted).
  Running image: halium-boot-bis8.img (6c93c803).
- Recipe (automated by picasso-wifi.service, ~55s after boot):
  lxc-start -> poll FW-ready -> settle 30s -> insmod logkstub.ko ->
  insmod qca_cld3_wlan.ko (vermagic-patched, ORIGINAL name OK since
  autoconnect is off) -> nmcli up saved profile.
- Two gotchas: (1) insmod during cnss-daemon init race = silent SoC reset;
  (2) NM autoconnect firing at interface appearance = same reset.
  Fix: settle wait + autoconnect=no.
## DroidSpaces: CORE works, limits/NAT66/ipset do NOT
- Present: namespaces, seccomp, cgroups, overlay, veth, bridge, iptables
  NAT44, IPv6 base, macvlan, user-ns, MEMCG, CPUACCT, DEVTMPFS.
- Absent (crash vendor wifi FW-attach, singly or combined):
  POSIX_MQUEUE, CGROUP_NET_PRIO, CFS_BANDWIDTH, CGROUP_PIDS,
  NF_TABLES, BRIDGE_NETFILTER, IP6_NF_NAT, IP_SET*, MATCH_RECENT.
  Root cause TBD (struct-layout vs vendor driver suspected, esp. MQUEUE).
- REMOTEPROC=y kills container-alone (~70s) - stays OFF permanently.
- Decision: ship working wifi + DS-core; revisit limits later.
## Phone-side files (NOT in git, on rootfs /root):
- vmods/ (41 vermagic-patched .ko for picasso+), logkstub.ko,
  wlan_cld3_picasso.ko, ko_*.tgz sets, boot-*.img backups,
  /usr/local/bin/picasso-wifi.sh + picasso-wifi.service (enabled),
  /lib/firmware: adsp.* bdwlan.* bdf_*.bin wlanmdsp.mbn,
  WIFI-WORKS.txt, /etc/sysctl.d/99-nocore.conf,
  pulseaudio+phosh masked, lxc@android masked.
