# WiFi bring-up (TESTED 2026-10-11/12, kernel 4.19.113-lineage-picasso+)

## Result
Scan + NM connect + ping 8.8.8.8. Automated by `picasso-wifi.service`
(~55s after boot, zero manual waiting).

## Recipe
1. `/lib/firmware`: adsp.*, bdwlan.*, bdf_*.bin, wlanmdsp.mbn (see firmware-list.txt)
2. `lxc-start -d -n android`, poll `dmesg` for `WLAN FW is ready` (~25-30s)
3. Wait 30s more (settle), then:
   - `insmod /root/logkstub.ko` (stub EXPORTs `uncached_logk`;
     proper fix = CONFIG_QCOM_RTB=y, kept OFF because RTB was a
     bisect suspect — retest later)
   - `insmod /root/vmods/qca_cld3_wlan.ko` (vermagic-patched, see patch-modules.sh)
4. `wlan0/wlan1/p2p0` appear. `nmcli connection up '<SSID>' ifname wlan0`
   with the profile set to `autoconnect no`.

## Two hard lessons (each cost multiple silent SoC resets)
1. **Settle wait is mandatory.** insmod while cnss-daemon initializes
   (~first minutes after container start) wedges the SoC with no logs.
   Polling FW-ready + 30s is proven; 4.5min also proven (slower, safer).
2. **NM autoconnect must stay off** on wifi profiles. Autoconnect firing
   at interface appearance races FW-attach the same way. Connect manually.

## Open
- Drop logkstub by re-enabling QCOM_RTB (needs retest).
- QCA_CLD_WLAN built-in is ON (harmless; vendor module loads by name
  since autoconnect is off and no ghost collision occurs at load time).
