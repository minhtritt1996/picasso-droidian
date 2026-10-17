#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <pthread.h>
#include <linux/input.h>
#include <time.h>

#define DEFAULT_BRIGHTNESS 1024

static volatile int s_screen_locked = 0;
static volatile int s_last_brightness = DEFAULT_BRIGHTNESS;

static int read_brightness(void) {
    FILE *f = fopen("/sys/class/backlight/backlight/brightness", "r");
    if (!f) f = fopen("/sys/class/backlight/panel0-backlight/brightness", "r");
    if (!f) return -1;
    int val = 0;
    if (fscanf(f, "%d", &val) != 1) val = -1;
    fclose(f);
    return val;
}

static void write_brightness(int val) {
    FILE *f1 = fopen("/sys/class/backlight/backlight/brightness", "w");
    if (f1) {
        fprintf(f1, "%d\n", val);
        fclose(f1);
    }
    FILE *f2 = fopen("/sys/class/backlight/panel0-backlight/brightness", "w");
    if (f2) {
        fprintf(f2, "%d\n", val);
        fclose(f2);
    }
}

static void apply_screen_state(int locked) {
    if (locked) {
        int cur = read_brightness();
        if (cur > 0) s_last_brightness = cur;
        write_brightness(0);
    } else {
        int b = s_last_brightness;
        if (b <= 100) b = DEFAULT_BRIGHTNESS;
        write_brightness(b);
        system("/usr/local/bin/k30-display-power.sh >/dev/null 2>&1 &");
    }
}

static void *monitor_thread(void *arg) {
    (void)arg;
    while (1) {
        // Run busctl monitor on org.gnome.ScreenSaver
        FILE *fp = popen("busctl --user -M droidian@ monitor org.gnome.ScreenSaver 2>/dev/null", "r");
        if (!fp) {
            sleep(1);
            continue;
        }

        char line[512];
        int saw_active_changed = 0;

        while (fgets(line, sizeof(line), fp)) {
            if (strstr(line, "Member=ActiveChanged")) {
                saw_active_changed = 1;
                continue;
            }
            if (saw_active_changed) {
                if (strstr(line, "BOOLEAN true")) {
                    s_screen_locked = 1;
                    apply_screen_state(1);
                    saw_active_changed = 0;
                } else if (strstr(line, "BOOLEAN false")) {
                    s_screen_locked = 0;
                    apply_screen_state(0);
                    saw_active_changed = 0;
                }
            }
        }
        pclose(fp);
        sleep(1);
    }
    return NULL;
}

static int get_initial_screensaver_state(void) {
    FILE *fp = popen("busctl --user -M droidian@ call org.gnome.ScreenSaver /org/gnome/ScreenSaver org.gnome.ScreenSaver GetActive 2>/dev/null", "r");
    if (!fp) return 0;
    char buf[64] = {0};
    int active = 0;
    if (fgets(buf, sizeof(buf), fp)) {
        if (strstr(buf, "true")) active = 1;
    }
    pclose(fp);
    return active;
}

static void toggle_screen(void) {
    if (s_screen_locked) {
        printf("Power key: Wake screen\n");
        fflush(stdout);
        s_screen_locked = 0;
        apply_screen_state(0);
        system("busctl --user -M droidian@ call org.gnome.ScreenSaver /org/gnome/ScreenSaver org.gnome.ScreenSaver SetActive b false >/dev/null 2>&1 &");
    } else {
        printf("Power key: Lock and sleep screen\n");
        fflush(stdout);
        s_screen_locked = 1;
        apply_screen_state(1);
        system("busctl --user -M droidian@ call org.gnome.ScreenSaver /org/gnome/ScreenSaver org.gnome.ScreenSaver SetActive b true >/dev/null 2>&1 &");
    }
}

int main(void) {
    int cur_b = read_brightness();
    if (cur_b > 0) s_last_brightness = cur_b;

    s_screen_locked = get_initial_screensaver_state();
    printf("k30-powerkey-daemon starting. Initial locked state: %d, brightness: %d\n", s_screen_locked, s_last_brightness);
    fflush(stdout);

    // Initial sync
    apply_screen_state(s_screen_locked);

    pthread_t tid;
    pthread_create(&tid, NULL, monitor_thread, NULL);
    pthread_detach(tid);

    int fd = open("/dev/input/event0", O_RDONLY);
    if (fd < 0) {
        perror("Failed to open /dev/input/event0");
        return 1;
    }

    struct input_event ev;
    struct timespec last_press = {0, 0};

    while (read(fd, &ev, sizeof(ev)) == sizeof(ev)) {
        if (ev.type == EV_KEY && ev.code == KEY_POWER && ev.value == 1) {
            struct timespec now;
            clock_gettime(CLOCK_MONOTONIC, &now);
            long diff_ms = (now.tv_sec - last_press.tv_sec) * 1000 + (now.tv_nsec - last_press.tv_nsec) / 1000000;
            if (diff_ms < 400) continue;
            last_press = now;

            toggle_screen();
        }
    }

    close(fd);
    return 0;
}
