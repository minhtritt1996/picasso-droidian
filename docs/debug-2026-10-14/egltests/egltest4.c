#include <EGL/egl.h>
#include <GLES2/gl2.h>
#include <stdio.h>
static const char *vs = "attribute vec4 p; attribute vec2 t; varying vec2 v; void main(){ gl_Position = p; v = t; }";
static const char *fsC = "precision mediump float; void main(){ gl_FragColor = vec4(0.0,0.0,1.0,1.0); }";
static const char *fsT = "precision mediump float; varying vec2 v; uniform sampler2D s; void main(){ gl_FragColor = texture2D(s, v); }";
GLuint mkprog(const char *fss) {
  GLuint v = glCreateShader(GL_VERTEX_SHADER), f = glCreateShader(GL_FRAGMENT_SHADER);
  glShaderSource(v, 1, &vs, 0); glCompileShader(v);
  glShaderSource(f, 1, &fss, 0); glCompileShader(f);
  GLuint p = glCreateProgram();
  glAttachShader(p, v); glAttachShader(p, f);
  glBindAttribLocation(p, 0, "p"); glBindAttribLocation(p, 1, "t");
  glLinkProgram(p); return p;
}
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
  glViewport(0, 0, 64, 64);
  GLuint pc = mkprog(fsC);
  glUseProgram(pc);
  float tri[] = {-1,-1,0, 3,-1,0, -1,3,0};
  glVertexAttribPointer(0, 3, GL_FLOAT, 0, 0, tri);
  glEnableVertexAttribArray(0);
  glDisableVertexAttribArray(1);
  glDrawArrays(GL_TRIANGLES, 0, 3);
  printf("draw-blue err=%x\n", glGetError()); fflush(stdout);
  GLuint tex; glGenTextures(1, &tex);
  glBindTexture(GL_TEXTURE_2D, tex);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
  glCopyTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, 0, 0, 64, 64, 0);
  printf("copy err=%x\n", glGetError()); fflush(stdout);
  glClearColor(0,1,0,1); glClear(GL_COLOR_BUFFER_BIT);
  GLuint pt = mkprog(fsT);
  glUseProgram(pt);
  glBindTexture(GL_TEXTURE_2D, tex);
  float q[] = {-1,-1,0, 0,0,  1,-1,0, 1,0,  -1,1,0, 0,1,  1,1,0, 1,1};
  glVertexAttribPointer(0, 3, GL_FLOAT, 0, 20, q);
  glVertexAttribPointer(1, 2, GL_FLOAT, 0, 20, q+3);
  glEnableVertexAttribArray(0); glEnableVertexAttribArray(1);
  glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
  printf("draw-tex err=%x\n", glGetError()); fflush(stdout);
  glFinish();
  unsigned char px[4] = {7,7,7,7};
  glReadPixels(32, 32, 1, 1, GL_RGBA, GL_UNSIGNED_BYTE, px);
  printf("center: %d %d %d %d (want 0 0 255 255 if loopback works)\n", px[0],px[1],px[2],px[3]);
  return 0;
}
