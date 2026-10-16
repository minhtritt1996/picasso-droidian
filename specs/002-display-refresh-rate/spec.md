# Feature Specification: Native Display Refresh Rate Selection (60Hz / 120Hz)

**Feature ID**: 002-display-refresh-rate  
**Status**: Implemented & Verified  
**Component**: `wlroots` (`hwcomposer` backend) / `phoc` / `phosh` / `gnome-control-center`

## 1. Context & User Story
* **As a** user running Droidian on Xiaomi Redmi K30 5G (`picasso`),  
* **I want** to select the screen refresh rate between 60Hz (battery saver) and 120Hz (ultra-smooth) directly inside GNOME Settings (Cài đặt -> Màn hình) or via a quick shortcut,  
* **So that** I have full control over display smoothness and power consumption.

## 2. Requirements & Acceptance Criteria
1. **Wayland Output Mode Advertisement**:
   - `HWCOMPOSER-1` output must advertise both fixed modes:
     - `1080x2400 @ 60.00 Hz`
     - `1080x2400 @ 120.00 Hz` (marked as `preferred`)
2. **GNOME Settings Integration**:
   - In `gnome-control-center` (Settings -> Displays), the "Refresh Rate" (Tần số quét) drop-down must be visible and functional, displaying 60.00 Hz and 120.00 Hz options.
   - Selecting a mode and applying it must immediately reconfigure compositor VSync interval without crashing `phoc` or disconnecting Wayland clients.
3. **Compositor & Configuration Flexibility**:
   - `/etc/phosh/phoc.ini` must not hardcode `mode = 1080x2400@60Hz`, allowing user selections via `monitors.xml` or D-Bus to persist across sessions.
4. **Quick Toggle Shortcut**:
   - `/usr/share/applications/k30-refreshrate.desktop` provides 1-tap toggling between 60Hz and 120Hz with native system notifications.

## 3. Architecture & Technical Details
* **Root Cause of Missing Refresh Rate Setting**:
  - `wlr_hwcomposer_add_output` in wlroots previously called `wlr_output_state_set_custom_mode`, leaving `wlr_output->modes` empty.
  - GNOME Display Settings hides the refresh rate selector when an output has fewer than 2 modes for a given resolution.
* **Resolution**:
  - Allocated and linked `mode120` (120000 mHz) and `mode60` (60000 mHz) into `wlr_output->modes`.
  - Added mode change handling (`WLR_OUTPUT_STATE_MODE`) in `output_commit` to dynamically recalculate `hwc_refresh` (8.33ms vs 16.6ms) and VSync timer.
  - Packaged updated `libwlroots.so.12a` into `adaptation-xiaomi-picasso_1.2.5_arm64.deb`.
