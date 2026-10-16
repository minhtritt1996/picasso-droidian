#define _GNU_SOURCE
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <fcntl.h>
#include <unistd.h>

/* =========================================================================
 * 1. Xiaomi Redmi K30 5G (picasso) Backlight sysfs mapping for Phosh
 * ========================================================================= */
typedef int gboolean;
typedef unsigned int guint;

#define BACKLIGHT_SYSFS "/sys/class/backlight/panel0-backlight/brightness"
#define MAX_BRIGHTNESS 4095

typedef struct _DroidLeds DroidLeds;

typedef enum _DroidLedsKind {
    DROID_LEDS_KIND_BACKLIGHT = 0,
    DROID_LEDS_KIND_NOTIFICATION,
} DroidLedsKind;

DroidLeds *droid_leds_new(void **error) {
    static int dummy = 1;
    return (DroidLeds *)&dummy;
}

gboolean droid_leds_is_kind_supported(DroidLeds *self, DroidLedsKind kind) {
    if (kind == DROID_LEDS_KIND_BACKLIGHT) {
        return 1;
    }
    return 0;
}

guint droid_leds_get_backlight(DroidLeds *self) {
    int fd = open(BACKLIGHT_SYSFS, O_RDONLY);
    if (fd < 0) {
        return 255;
    }
    char buf[16] = {0};
    int n = read(fd, buf, sizeof(buf) - 1);
    close(fd);
    if (n <= 0) return 255;
    int val = atoi(buf);
    int level = (val * 255) / MAX_BRIGHTNESS;
    if (level < 0) level = 0;
    if (level > 255) level = 255;
    return (guint)level;
}

gboolean droid_leds_set_backlight(DroidLeds *self, guint level, gboolean save) {
    if (level > 255) level = 255;
    int val = (level == 0) ? 20 : (level * MAX_BRIGHTNESS / 255);
    if (val < 20) val = 20;
    if (val > MAX_BRIGHTNESS) val = MAX_BRIGHTNESS;

    int fd = open(BACKLIGHT_SYSFS, O_WRONLY);
    if (fd >= 0) {
        char buf[16];
        int len = snprintf(buf, sizeof(buf), "%d\n", val);
        write(fd, buf, len);
        close(fd);
    }
    return 1;
}

void droid_leds_set_notification(DroidLeds *self, guint r, guint g, guint b, guint on_ms, guint off_ms) {
}

void droid_leds_clear_notification(DroidLeds *self) {
}

/* =========================================================================
 * 2. Status Bar Height Expansion (32px -> 54px logical) for Dual Punch-Hole
 * ========================================================================= */
#define ORIGINAL_TOP_BAR_HEIGHT 32
#define TARGET_TOP_BAR_HEIGHT   54
#define HEIGHT_DELTA            (TARGET_TOP_BAR_HEIGHT - ORIGINAL_TOP_BAR_HEIGHT) // +22px

struct wl_proxy;
struct wl_interface;
struct wl_object;

union wl_argument {
    int32_t i;
    uint32_t u;
    int32_t f;
    const char *s;
    struct wl_object *o;
    uint32_t n;
    void *a;
    int32_t h;
};

typedef struct wl_proxy *(*pfn_marshal_array_flags)(
    struct wl_proxy *proxy, uint32_t opcode,
    const struct wl_interface *interface,
    uint32_t version, uint32_t flags,
    union wl_argument *args
);
typedef const char *(*pfn_get_class)(struct wl_proxy *);

struct wl_proxy *wl_proxy_marshal_array_flags(struct wl_proxy *proxy, uint32_t opcode,
                                             const struct wl_interface *interface,
                                             uint32_t version, uint32_t flags,
                                             union wl_argument *args)
{
    static pfn_marshal_array_flags real_marshal = NULL;
    static pfn_get_class real_get_class = NULL;

    if (!real_marshal) {
        real_marshal = (pfn_marshal_array_flags)dlsym(RTLD_NEXT, "wl_proxy_marshal_array_flags");
        if (!real_marshal) {
            return NULL;
        }
    }
    if (!real_get_class) {
        real_get_class = (pfn_get_class)dlsym(RTLD_DEFAULT, "wl_proxy_get_class");
    }

    const char *cls = (proxy && real_get_class) ? real_get_class(proxy) : NULL;

    /* Intercept requests before execution safely without pointer dereferences */
    if (cls && args) {
        /* zwlr_layer_surface_v1 */
        if (strcmp(cls, "zwlr_layer_surface_v1") == 0) {
            /* opcode 0: set_size(width, height) */
            if (opcode == 0) {
                if (args[1].u == ORIGINAL_TOP_BAR_HEIGHT) {
                    args[1].u = TARGET_TOP_BAR_HEIGHT;
                }
            }
            /* opcode 2: set_exclusive_zone(zone) */
            else if (opcode == 2) {
                if (args[0].i == ORIGINAL_TOP_BAR_HEIGHT) {
                    args[0].i = TARGET_TOP_BAR_HEIGHT;
                }
            }
        }
        /* zphoc_draggable_layer_surface_v1 */
        else if (strcmp(cls, "zphoc_draggable_layer_surface_v1") == 0) {
            /* opcode 0: set_margins(margin_folded, margin_unfolded) */
            if (opcode == 0) {
                /*
                 * In Phosh top-panel: margin_folded = (-1 * height) + 32.
                 * To make 54px visible instead of 32px:
                 * margin_folded = (-1 * height) + 54.
                 * Bottom home bar has height 15 (folded margin ~ -height + 15).
                 * We only adjust top-panel where folded margin is based on 32.
                 */
                if (args[0].i < -30) {
                    args[0].i += HEIGHT_DELTA;
                }
            }
            /* opcode 2: set_exclusive(exclusive) */
            else if (opcode == 2) {
                if (args[0].u == ORIGINAL_TOP_BAR_HEIGHT) {
                    args[0].u = TARGET_TOP_BAR_HEIGHT;
                }
            }
            /* opcode 4: set_drag_handle(handle) */
            else if (opcode == 4) {
                if (args[0].u >= HEIGHT_DELTA) {
                    args[0].u -= HEIGHT_DELTA;
                }
            }
        }
    }

    return real_marshal(proxy, opcode, interface, version, flags, args);
}
