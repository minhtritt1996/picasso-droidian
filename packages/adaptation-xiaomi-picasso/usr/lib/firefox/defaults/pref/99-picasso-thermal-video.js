// Thermal and performance optimizations for Xiaomi Redmi K30 5G (Snapdragon 765G / picasso)
// 1. Force YouTube and web video players to avoid AV1.
//    Qualcomm SM7250 does not have AV1 hardware decode.
pref("media.av1.enabled", false);

// 2. Allow media audio autoplay without blocking/muting
pref("media.autoplay.default", 0);
pref("media.autoplay.blocking_policy", 0);
