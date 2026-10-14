#include <stdio.h>
#include <unistd.h>
#include <stdint.h>
#include <hybris/hwc2/hwc2_compatibility_layer.h>

void *android_dlopen(const char *filename, int flags);
void *android_dlsym(void *handle, const char *symbol);

static hwc2_compat_device_t *g_dev = NULL;
static uint64_t g_disp_id = 0;

static void on_vsync(HWC2EventListener* self, int32_t s, hwc2_display_t d, int64_t t) {}
static void on_hotplug(HWC2EventListener* self, int32_t s, hwc2_display_t d, bool c, bool p) {
    g_disp_id = d;
    if (g_dev) hwc2_compat_device_on_hotplug(g_dev, d, c);
}
static void on_refresh(HWC2EventListener* self, int32_t s, hwc2_display_t d) {}

int main() {
    printf("Listing HWC configs...\n");
    return 0;
}
