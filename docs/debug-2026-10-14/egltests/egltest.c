#include <EGL/egl.h>
#include <GLES2/gl2.h>
#include <stdio.h>
int main() {
  EGLDisplay d = eglGetDisplay(EGL_DEFAULT_DISPLAY);
  printf("display=%p\n", (void*)d); fflush(stdout);
  EGLint maj = 0, mn = 0;
  if (!eglInitialize(d, &maj, &mn)) { printf("init fail\n"); return 1; }
  printf("egl %d.%d vendor=%s\n", maj, mn, eglQueryString(d, EGL_VENDOR)); fflush(stdout);
  eglBindAPI(EGL_OPENGL_ES_API);
  EGLint ca[] = {EGL_RENDERABLE_TYPE, EGL_OPENGL_ES2_BIT, EGL_SURFACE_TYPE, EGL_PBUFFER_BIT, EGL_RED_SIZE,8,EGL_GREEN_SIZE,8,EGL_BLUE_SIZE,8,EGL_ALPHA_SIZE,8, EGL_NONE};
  EGLConfig cfg; EGLint n = 0;
  if (!eglChooseConfig(d, ca, &cfg, 1, &n) || n < 1) { printf("cfg fail\n"); return 1; }
  printf("config ok\n"); fflush(stdout);
  EGLint pa[] = {EGL_WIDTH, 64, EGL_HEIGHT, 64, EGL_NONE};
  EGLSurface s = eglCreatePbufferSurface(d, cfg, pa);
  printf("surface=%p\n", (void*)s); fflush(stdout);
  EGLint xa[] = {EGL_CONTEXT_CLIENT_VERSION, 2, EGL_NONE};
  EGLContext c = eglCreateContext(d, cfg, EGL_NO_CONTEXT, xa);
  printf("ctx=%p\n", (void*)c); fflush(stdout);
  if (!eglMakeCurrent(d, s, s, c)) { printf("current fail\n"); return 1; }
  printf("current ok\n"); fflush(stdout);
  glClearColor(1,0,0,1); glClear(GL_COLOR_BUFFER_BIT);
  printf("clear submitted\n"); fflush(stdout);
  glFinish();
  printf("finish ok\n"); fflush(stdout);
  unsigned char px[4] = {0,0,0,0};
  glReadPixels(0,0,1,1,GL_RGBA,GL_UNSIGNED_BYTE,px);
  printf("pixel: %d %d %d %d\n", px[0],px[1],px[2],px[3]);
  return 0;
}
