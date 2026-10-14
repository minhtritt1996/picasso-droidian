#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <wayland-client.h>
#include "xdg-shell.h"
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
static void ping(void *d, struct xdg_wm_base *b, uint32_t s) { xdg_wm_base_pong(b, s); }
static const struct xdg_wm_base_listener bl = { ping };
static void regg(void *d, struct wl_registry *r, uint32_t n, const char *i, uint32_t v) {
  if (!strcmp(i, wl_compositor_interface.name)) comp = wl_registry_bind(r, n, &wl_compositor_interface, 4);
  else if (!strcmp(i, wl_shm_interface.name)) shm = wl_registry_bind(r, n, &wl_shm_interface, 1);
  else if (!strcmp(i, xdg_wm_base_interface.name)) base = wl_registry_bind(r, n, &xdg_wm_base_interface, 1);
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
  uint32_t color = (frames / 30 % 2) ? 0xFF00FF00 : 0xFFFF0000;
  for (int i = 0; i < W * H; i++) px[i] = color;
  wl_surface_attach(surf, buf, 0, 0);
  wl_surface_damage(surf, 0, 0, W, H);
  struct wl_callback *ncb = wl_surface_frame(surf);
  wl_callback_add_listener(ncb, &fl, 0);
  wl_surface_commit(surf);
  wl_display_flush(dpy);
  if (frames % 10 == 1) { printf("frame %d\n", frames); fflush(stdout); }
}
int main() {
  dpy = wl_display_connect("wayland-0");
  if (!dpy) { printf("no display\n"); return 1; }
  struct wl_registry *reg = wl_display_get_registry(dpy);
  wl_registry_add_listener(reg, &rl, 0);
  wl_display_roundtrip(dpy);
  if (!comp || !shm || !base) { printf("missing globals\n"); return 1; }
  xdg_wm_base_add_listener(base, &bl, 0);
  int stride = W * 4, sz = stride * H;
  char t[] = "/tmp/wlshm-XXXXXX";
  int fd = mkstemp(t); fcntl(fd, F_SETFD, FD_CLOEXEC); ftruncate(fd, sz);
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
  printf("configured\n"); fflush(stdout);
  frame_done(dpy, 0, 0);
  while (frames < 300 && wl_display_dispatch(dpy) != -1) {}
  printf("done frames=%d\n", frames);
  return 0;
}
