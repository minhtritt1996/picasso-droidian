// Thermal and performance optimizations for Xiaomi Redmi K30 5G (Snapdragon 765G / picasso)
// 1. Force YouTube and web video players to stream lightweight H.264 (AVC) instead of AV1 / VP9.
//    Qualcomm SM7250 does not have AV1 hardware decode. Software AV1 pushes all 8 CPU cores to 100%,
//    causing extreme heat and thermal throttling. H.264 runs efficiently at 10-15% CPU load.
pref("media.av1.enabled", false);

// 2. Optimized Software WebRender (Swgl)
pref("gfx.webrender.all", false);
pref("gfx.webrender.software", true);
pref("layers.acceleration.disabled", true);
