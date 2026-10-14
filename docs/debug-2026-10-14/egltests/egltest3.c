#include <EGL/egl.h>
#include <GLES2/gl2.h>
#include <stdio.h>
#define CK(x) do { x; EGLint e = eglGetError(); if (e != EGL_SUCCESS) printf("EGL err %x after " #x "\n", e); GLenum g = glGetError(); if (g) printf("GL err %x after " #x "\n", g); } while(0)
static const char *vs = "attribute vec4 p; void main(){ gl_Position = p; }";
static const char *fs = "precision mediump float; void main(){ gl_FragColor = vec4(0.0,0.0,1.0,1.0); }";
int main() {
  EGLDisplay d = eglGetDisplay(EGL_DEFAULT_DISPLAY);
  EGLint maj, mn; eglInitialize(d, &maj, &mn);
  eglBindAPI(EGL_OPENGL_ES_API);
  EGLint ca[] = {EGL_RENDERABLE_TYPE, EGL_OPENGL_ES2_BIT, EGL_SURFACE_TYPE, EGL_PBUFFER_BIT, EGL_RED_SIZE,8,EGL_GREEN_SIZE,8,EGL_BLUE_SIZE,8,EGL_ALPHA_SIZE,8, EGL_NONE};
  EGLConfig cfg; EGLint n; eglChooseConfig(d, ca, &cfg, 1, &n);
  EGLint pa[] = {EGL_WIDTH, 64, EGL_HEIGHT, 64, EGL_NONE};
  EGLSurface s = eglCreatePbufferSurface(d, cfg, pa);
  EGLint w = 0, h = 0;
  eglQuerySurface(d, s, EGL_WIDTH, &w); eglQuerySurface(d, s, EGL_HEIGHT, &h);
  printf("surface=%p size=%dx%d\n", (void*)s, w, h); fflush(stdout);
  EGLint xa[] = {EGL_CONTEXT_CLIENT_VERSION, 2, EGL_NONE};
  EGLContext c = eglCreateContext(d, cfg, EGL_NO_CONTEXT, xa);
  CK(eglMakeCurrent(d, s, s, c));
  printf("vendor=%s version=%s\n", glGetString(GL_VENDOR), glGetString(GL_VERSION)); fflush(stdout);
  GLuint v = glCreateShader(GL_VERTEX_SHADER), f = glCreateShader(GL_FRAGMENT_SHADER);
  glShaderSource(v, 1, &vs, 0); glCompileShader(v);
  glShaderSource(f, 1, &fs, 0); glCompileShader(f);
  GLint ok = 0; glGetShaderiv(v, GL_COMPILE_STATUS, &ok); printf("vs=%d ", ok);
  glGetShaderiv(f, GL_COMPILE_STATUS, &ok); printf("fs=%d\n", ok); fflush(stdout);
  GLuint p = glCreateProgram();
  glAttachShader(p, v); glAttachShader(p, f);
  glBindAttribLocation(p, 0, "p"); glLinkProgram(p);
  glGetProgramiv(p, GL_LINK_STATUS, &ok); printf("link=%d\n", ok); fflush(stdout);
  glViewport(0, 0, 64, 64); glUseProgram(p);
  float tri[] = {-1,-1,0, 3,-1,0, -1,3,0};
  glVertexAttribPointer(0, 3, GL_FLOAT, 0, 0, tri);
  glEnableVertexAttribArray(0);
  glDrawArrays(GL_TRIANGLES, 0, 3);
  printf("draw submitted err=%x\n", glGetError()); fflush(stdout);
  glFinish();
  unsigned char px[4] = {7,7,7,7};
  glReadPixels(32, 32, 1, 1, GL_RGBA, GL_UNSIGNED_BYTE, px);
  printf("center pixel: %d %d %d %d\n", px[0],px[1],px[2],px[3]);
  return 0;
}
