#include <EGL/egl.h>
#include <EGL/eglext.h>
#include <GLES2/gl2.h>
#include <stdio.h>
static const char *vs = "attribute vec4 p; void main(){ gl_Position = p; }";
static const char *fs = "precision mediump float; void main(){ gl_FragColor = vec4(1.0,0.0,0.0,1.0); }";
int main() {
  PFNEGLGETPLATFORMDISPLAYEXTPROC getPlat = (void*)eglGetProcAddress("eglGetPlatformDisplayEXT");
  EGLDisplay d = getPlat ? getPlat(EGL_PLATFORM_SURFACELESS_MESA, EGL_DEFAULT_DISPLAY, 0) : eglGetDisplay(EGL_DEFAULT_DISPLAY);
  printf("display=%p\n", (void*)d); fflush(stdout);
  EGLint maj, mn;
  if (!eglInitialize(d, &maj, &mn)) { printf("init fail\n"); return 1; }
  printf("init %d.%d\n", maj, mn); fflush(stdout);
  eglBindAPI(EGL_OPENGL_ES_API);
  EGLint ca[] = {EGL_RENDERABLE_TYPE, EGL_OPENGL_ES2_BIT, EGL_SURFACE_TYPE, EGL_WINDOW_BIT, EGL_RED_SIZE,8,EGL_GREEN_SIZE,8,EGL_BLUE_SIZE,8,EGL_ALPHA_SIZE,8, EGL_NONE};
  EGLConfig cfg; EGLint n; eglChooseConfig(d, ca, &cfg, 1, &n);
  EGLint xa[] = {EGL_CONTEXT_CLIENT_VERSION, 2, EGL_NONE};
  EGLContext c = eglCreateContext(d, cfg, EGL_NO_CONTEXT, xa);
  printf("ctx=%p\n", (void*)c); fflush(stdout);
  if (!eglMakeCurrent(d, EGL_NO_SURFACE, EGL_NO_SURFACE, c)) { printf("surfaceless current fail\n"); return 1; }
  printf("surfaceless current ok\n"); fflush(stdout);
  GLuint tex, fbo;
  glGenTextures(1, &tex);
  glBindTexture(GL_TEXTURE_2D, tex);
  glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, 64, 64, 0, GL_RGBA, GL_UNSIGNED_BYTE, 0);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
  glGenFramebuffers(1, &fbo);
  glBindFramebuffer(GL_FRAMEBUFFER, fbo);
  glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, tex, 0);
  printf("fbo status=%x (8cd5=complete)\n", glCheckFramebufferStatus(GL_FRAMEBUFFER)); fflush(stdout);
  GLuint v = glCreateShader(GL_VERTEX_SHADER), f = glCreateShader(GL_FRAGMENT_SHADER);
  glShaderSource(v, 1, &vs, 0); glCompileShader(v);
  glShaderSource(f, 1, &fs, 0); glCompileShader(f);
  GLuint p = glCreateProgram();
  glAttachShader(p, v); glAttachShader(p, f);
  glBindAttribLocation(p, 0, "p"); glLinkProgram(p);
  GLint ok = 0; glGetProgramiv(p, GL_LINK_STATUS, &ok); printf("link=%d\n", ok); fflush(stdout);
  glViewport(0, 0, 64, 64); glUseProgram(p);
  float tri[] = {-1,-1,0, 3,-1,0, -1,3,0};
  glVertexAttribPointer(0, 3, GL_FLOAT, 0, 0, tri);
  glEnableVertexAttribArray(0);
  glDrawArrays(GL_TRIANGLES, 0, 3);
  printf("draw err=%x\n", glGetError()); fflush(stdout);
  glFinish();
  unsigned char px[4] = {7,7,7,7};
  glReadPixels(32, 32, 1, 1, GL_RGBA, GL_UNSIGNED_BYTE, px);
  printf("FBO pixel: %d %d %d %d (want 255 0 0 255)\n", px[0],px[1],px[2],px[3]);
  return 0;
}
