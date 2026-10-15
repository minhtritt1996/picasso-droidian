#include <EGL/egl.h>
#include <GLES2/gl2.h>
#include <stdio.h>

int main() {
  EGLDisplay d = eglGetDisplay(EGL_DEFAULT_DISPLAY);
  printf("eglGetDisplay: %p\n", (void*)d);

  EGLint maj = 0, mn = 0;
  if (!eglInitialize(d, &maj, &mn)) {
    printf("eglInitialize failed: 0x%x\n", eglGetError());
    return 1;
  }
  printf("eglInitialize OK: %d.%d, Vendor: %s\n", maj, mn, eglQueryString(d, EGL_VENDOR));

  if (!eglBindAPI(EGL_OPENGL_ES_API)) {
    printf("eglBindAPI failed: 0x%x\n", eglGetError());
  }

  EGLint ca[] = {
    EGL_RENDERABLE_TYPE, EGL_OPENGL_ES2_BIT,
    EGL_SURFACE_TYPE, EGL_PBUFFER_BIT,
    EGL_RED_SIZE, 8, EGL_GREEN_SIZE, 8, EGL_BLUE_SIZE, 8, EGL_ALPHA_SIZE, 8,
    EGL_NONE
  };
  EGLConfig cfg = 0;
  EGLint n = 0;
  if (!eglChooseConfig(d, ca, &cfg, 1, &n) || n < 1) {
    printf("eglChooseConfig failed: 0x%x, count=%d\n", eglGetError(), n);
    return 1;
  }
  printf("eglChooseConfig OK: %p\n", (void*)cfg);

  EGLint pa[] = {EGL_WIDTH, 64, EGL_HEIGHT, 64, EGL_NONE};
  EGLSurface s = eglCreatePbufferSurface(d, cfg, pa);
  if (s == EGL_NO_SURFACE) {
    printf("eglCreatePbufferSurface failed: 0x%x\n", eglGetError());
    return 1;
  }
  printf("eglCreatePbufferSurface OK: %p\n", (void*)s);

  EGLint xa[] = {EGL_CONTEXT_CLIENT_VERSION, 2, EGL_NONE};
  EGLContext c = eglCreateContext(d, cfg, EGL_NO_CONTEXT, xa);
  if (c == EGL_NO_CONTEXT) {
    printf("eglCreateContext failed: 0x%x\n", eglGetError());
    return 1;
  }
  printf("eglCreateContext OK: %p\n", (void*)c);

  if (!eglMakeCurrent(d, s, s, c)) {
    printf("eglMakeCurrent failed: 0x%x\n", eglGetError());
    return 1;
  }
  printf("eglMakeCurrent OK!\n");

  printf("GL_VENDOR: %s\n", glGetString(GL_VENDOR));
  printf("GL_RENDERER: %s\n", glGetString(GL_RENDERER));
  printf("GL_VERSION: %s\n", glGetString(GL_VERSION));

  GLuint tex, fbo;
  glGenTextures(1, &tex);
  glBindTexture(GL_TEXTURE_2D, tex);
  glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, 64, 64, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);

  glGenFramebuffers(1, &fbo);
  glBindFramebuffer(GL_FRAMEBUFFER, fbo);
  glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, tex, 0);

  GLenum fbo_status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
  printf("FBO status: 0x%x (0x8cd5 is GL_FRAMEBUFFER_COMPLETE)\n", fbo_status);

  glViewport(0, 0, 64, 64);
  glClearColor(1.0f, 0.0f, 0.0f, 1.0f); // RED
  glClear(GL_COLOR_BUFFER_BIT);
  glFinish();

  unsigned char px[4] = {0, 0, 0, 0};
  glReadPixels(32, 32, 1, 1, GL_RGBA, GL_UNSIGNED_BYTE, px);
  printf("Pixel at (32,32): R=%d G=%d B=%d A=%d\n", px[0], px[1], px[2], px[3]);

  return 0;
}
