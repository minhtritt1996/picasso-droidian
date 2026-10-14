#include <EGL/egl.h>
#include <GLES2/gl2.h>
#include <stdio.h>
int main() {
  EGLDisplay d = eglGetDisplay(EGL_DEFAULT_DISPLAY);
  EGLint maj, mn; eglInitialize(d, &maj, &mn);
  eglBindAPI(EGL_OPENGL_ES_API);
  EGLint ca[] = {EGL_RENDERABLE_TYPE, EGL_OPENGL_ES2_BIT, EGL_SURFACE_TYPE, EGL_PBUFFER_BIT, EGL_RED_SIZE,8,EGL_GREEN_SIZE,8,EGL_BLUE_SIZE,8,EGL_ALPHA_SIZE,8, EGL_NONE};
  EGLConfig cfg; EGLint n; eglChooseConfig(d, ca, &cfg, 1, &n);
  EGLint pa[] = {EGL_WIDTH, 64, EGL_HEIGHT, 64, EGL_NONE};
  EGLSurface s = eglCreatePbufferSurface(d, cfg, pa);
  EGLint xa[] = {EGL_CONTEXT_CLIENT_VERSION, 2, EGL_NONE};
  EGLContext c = eglCreateContext(d, cfg, EGL_NO_CONTEXT, xa);
  eglMakeCurrent(d, s, s, c);
  printf("setup ok\n"); fflush(stdout);
  glClearColor(0,1,0,1); glClear(GL_COLOR_BUFFER_BIT);
  if (!eglSwapBuffers(d, s)) printf("swap1 fail\n"); else printf("swap1 ok\n"); fflush(stdout);
  unsigned char px[4] = {9,9,9,9};
  glReadPixels(0,0,1,1,GL_RGBA,GL_UNSIGNED_BYTE,px);
  printf("pixel: %d %d %d %d\n", px[0],px[1],px[2],px[3]);
  return 0;
}
