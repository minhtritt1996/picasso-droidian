# Feature Specification: Camera Viewfinder and Video Mode Optimization

**Feature ID**: 001-camera-optimization  
**Status**: Implemented & Verified  
**Component**: `droidian-camera` / GStreamer / QML / `adaptation-xiaomi-picasso`

## 1. Context & User Story
* **As a** user running Droidian on Xiaomi Redmi K30 5G (`picasso`),  
* **I want** the Camera application to launch, stream real-time preview smoothly, and transition seamlessly between Photo and Video capture modes without hanging or causing device crashes,  
* **So that** I can take pictures and record video reliably on my device.

## 2. Requirements & Acceptance Criteria
1. **Viewfinder Preview**:
   - Camera preview streams smoothly at 30 fps using Qualcomm ISP and hardware sensor drivers (IMX686 via `droidcamsrc`).
   - Unused/virtual camera sensors (ID 1, 4) blacklisted to prevent initialization failures.
2. **Mode Switching (Photo <-> Video)**:
   - Tapping "Video" or swiping the screen switches mode instantly within 400ms.
   - CPU usage during mode transition must remain negligible (no thread stalls, no UI freezes).
3. **Audio/Video Recording Pipeline**:
   - Audio encoder must use a functional GStreamer element (`voaacenc` / `avenc_aac`), avoiding non-functional HAL wrappers.
   - Recording filenames dynamically generated with unique timestamps in `/home/droidian/Videos/droidian-camera/`.
4. **Asset Resolution**:
   - Shutter sounds and SVG icons resolve reliably from embedded Qt resources (`qrc:/`).

## 3. Failure Mode & Root Cause Analysis
* **Symptom**: Switching to Video mode froze the application completely, pinning CPU at 100%.
* **Root Cause**: `main-gst.qml` enabled `FastBlur` with `radius: 128` across 1080x2400 pixels upon mode switch (`blurView = 1`). Because Mesa renders via CPU software rasterizer (`llvmpipe`), calculating a 128-pixel Gaussian blur across 2.6 million pixels starved the Qt event loop, preventing `swappingDelay` timer (400ms) from ever firing.
* **Resolution**: Replaced `FastBlur` and `Glow` with a lightweight black opacity overlay (`Rectangle { opacity: blurView ? 1 : 0; color: "#40000000" }`), eliminating CPU overhead completely.
