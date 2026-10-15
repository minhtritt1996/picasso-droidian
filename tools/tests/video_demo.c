#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <wayland-client.h>
#include "/root/tools/xdg-shell.h"

#define W 1080
#define H 2400

static struct wl_display *dpy;
static struct wl_compositor *comp;
static struct wl_shm *shm;
static struct xdg_wm_base *base;
static struct wl_surface *surf;
static struct xdg_surface *xs;
static struct wl_buffer *buf;
static uint32_t *px;
static int frames = 0, configured = 0;

static const uint32_t bg_colors[] = {
    0xFFFFFFFF, // Pure White
    0xFF0055FF, // Electric Blue
    0xFF00FF44, // Neon Green
    0xFFFF00AA, // Hot Pink
    0xFF00FFFF, // Cyan
    0xFFFFCC00, // Gold / Yellow
    0xFFFF2200, // Crimson Red
};
#define NUM_COLORS (sizeof(bg_colors) / sizeof(bg_colors[0]))

static int box_x = 100, box_y = 100;
static int box_vx = 12, box_vy = 16;
static int box_size = 350;

static void ping(void *d, struct xdg_wm_base *b, uint32_t s) {
    xdg_wm_base_pong(b, s);
}

static const struct xdg_wm_base_listener bl = { ping };

static void regg(void *d, struct wl_registry *r, uint32_t n, const char *i, uint32_t v) {
    if (!strcmp(i, wl_compositor_interface.name))
        comp = wl_registry_bind(r, n, &wl_compositor_interface, 4);
    else if (!strcmp(i, wl_shm_interface.name))
        shm = wl_registry_bind(r, n, &wl_shm_interface, 1);
    else if (!strcmp(i, xdg_wm_base_interface.name))
        base = wl_registry_bind(r, n, &xdg_wm_base_interface, 1);
}

static void regr(void *d, struct wl_registry *r, uint32_t n) {}
static const struct wl_registry_listener rl = { regg, regr };

static void frame_done(void *d, struct wl_callback *cb, uint32_t t);
static const struct wl_callback_listener fl = { frame_done };

static void xconf(void *d, struct xdg_surface *s, uint32_t serial) {
    xdg_surface_ack_configure(s, serial);
    configured = 1;
}

static const struct xdg_surface_listener xl = { xconf };

static void frame_done(void *d, struct wl_callback *cb, uint32_t t) {
    if (cb) wl_callback_destroy(cb);
    if (!configured) return;

    frames++;

    // Pick background color (changes every 60 frames = ~1s)
    uint32_t bg = bg_colors[(frames / 60) % NUM_COLORS];
    uint32_t box_color = ~bg | 0xFF000000; // Invert color for maximum contrast

    // Update bouncing box
    box_x += box_vx;
    box_y += box_vy;
    if (box_x <= 0) { box_x = 0; box_vx = -box_vx; }
    if (box_x + box_size >= W) { box_x = W - box_size; box_vx = -box_vx; }
    if (box_y <= 0) { box_y = 0; box_vy = -box_vy; }
    if (box_y + box_size >= H) { box_y = H - box_size; box_vy = -box_vy; }

    // Fill background
    for (int i = 0; i < W * H; i++) {
        px[i] = bg;
    }

    // Draw bouncing box
    for (int r = box_y; r < box_y + box_size && r < H; r++) {
        uint32_t *row = &px[r * W];
        for (int c = box_x; c < box_x + box_size && c < W; c++) {
            row[c] = box_color;
        }
    }

    // Draw a thick border around the box for extra visibility
    int border = 20;
    uint32_t border_color = 0xFF000000;
    for (int r = box_y; r < box_y + box_size && r < H; r++) {
        uint32_t *row = &px[r * W];
        for (int c = box_x; c < box_x + box_size && c < W; c++) {
            if (r < box_y + border || r >= box_y + box_size - border ||
                c < box_x + border || c >= box_x + box_size - border) {
                row[c] = border_color;
            }
        }
    }

    wl_surface_attach(surf, buf, 0, 0);
    wl_surface_damage(surf, 0, 0, W, H);

    struct wl_callback *ncb = wl_surface_frame(surf);
    wl_callback_add_listener(ncb, &fl, 0);

    wl_surface_commit(surf);
    wl_display_flush(dpy);

    if (frames % 60 == 0) {
        printf("[VIDEO DEMO] frame %d, color #%lu\n", frames, (frames / 60) % NUM_COLORS);
        fflush(stdout);
    }
}

int main() {
    printf("Connecting to Wayland...\n");
    dpy = wl_display_connect("wayland-0");
    if (!dpy) {
        fprintf(stderr, "Cannot connect to wayland-0\n");
        return 1;
    }

    struct wl_registry *reg = wl_display_get_registry(dpy);
    wl_registry_add_listener(reg, &rl, 0);
    wl_display_roundtrip(dpy);

    if (!comp || !shm || !base) {
        fprintf(stderr, "Missing Wayland globals\n");
        return 1;
    }

    xdg_wm_base_add_listener(base, &bl, 0);

    int stride = W * 4, sz = stride * H;
    char t[] = "/tmp/wlshm-XXXXXX";
    int fd = mkstemp(t);
    fcntl(fd, F_SETFD, FD_CLOEXEC);
    ftruncate(fd, sz);
    void *mem = mmap(0, sz, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
    unlink(t);
    px = mem;

    struct wl_shm_pool *pool = wl_shm_create_pool(shm, fd, sz);
    buf = wl_shm_pool_create_buffer(pool, 0, W, H, stride, WL_SHM_FORMAT_ARGB8888);

    surf = wl_compositor_create_surface(comp);
    xs = xdg_wm_base_get_xdg_surface(base, surf);
    xdg_surface_add_listener(xs, &xl, 0);

    struct xdg_toplevel *top = xdg_surface_get_toplevel(xs);
    xdg_toplevel_set_fullscreen(top, 0);

    wl_surface_commit(surf);

    while (!configured && wl_display_dispatch(dpy) != -1) {}
    printf("Wayland configured! Starting video animation loop...\n");
    fflush(stdout);

    frame_done(dpy, 0, 0);

    while (wl_display_dispatch(dpy) != -1) {
        // Runs continuously
    }

    return 0;
}
