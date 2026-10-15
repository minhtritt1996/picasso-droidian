#include <EGL/egl.h>
#include <GLES2/gl2.h>
#include <stdio.h>

int main() {
  EGLDisplay d = eglGetDisplay(EGL_DEFAULT_DISPLAY);
  EGLint maj, mn;
  eglInitialize(d, &maj, &mn);
  eglBindAPI(EGL_OPENGL_ES_API);
  EGLint ca[] = {EGL_RENDERABLE_TYPE, EGL_OPENGL_ES2_BIT, EGL_SURFACE_TYPE, EGL_PBUFFER_BIT, EGL_RED_SIZE,8,EGL_GREEN_SIZE,8,EGL_BLUE_SIZE,8,EGL_ALPHA_SIZE,8, EGL_NONE};
  EGLConfig cfg; EGLint n;
  eglChooseConfig(d, ca, &cfg, 1, &n);
  EGLint pa[] = {EGL_WIDTH, 64, EGL_HEIGHT, 64, EGL_NONE};
  EGLSurface s = eglCreatePbufferSurface(d, cfg, pa);
  EGLint xa[] = {EGL_CONTEXT_CLIENT_VERSION, 2, EGL_NONE};
  EGLContext c = eglCreateContext(d, cfg, EGL_NO_CONTEXT, xa);
  eglMakeCurrent(d, s, s, c);

  printf("Vendor: %s, Renderer: %s, Version: %s\n", glGetString(GL_VENDOR), glGetString(GL_RENDERER), glGetString(GL_VERSION));

  GLuint tex, fbo;
  glGenTextures(1, &tex);
  glBindTexture(GL_TEXTURE_2D, tex);
  glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, 64, 64, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);

  glGenFramebuffers(1, &fbo);
  glBindFramebuffer(GL_FRAMEBUFFER, fbo);
  glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, tex, 0);

  GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
  printf("FBO status: 0x%x (expected 0x8cd5)\n", status);

  glClearColor(1.0f, 0.0f, 0.0f, 1.0f);
  glClear(GL_COLOR_BUFFER_BIT);
  glFinish();

  unsigned char px[4] = {0, 0, 0, 0};
  glReadPixels(32, 32, 1, 1, GL_RGBA, GL_UNSIGNED_BYTE, px);
  printf("FBO ReadPixels: %d %d %d %d\n", px[0], px[1], px[2], px[3]);

  return 0;
}
