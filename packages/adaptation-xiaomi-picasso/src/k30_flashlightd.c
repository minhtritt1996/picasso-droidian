#include <gio/gio.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <unistd.h>
#include <fcntl.h>

#define CUSTOM_SYSFS_NODES_FILE "/usr/lib/droidian/device/flashlightd-sysfs-nodes"
#define CUSTOM_BRIGHTNESS_FILE  "/usr/lib/droidian/device/flashlightd-brightness"
#define DEFAULT_ON_BRIGHTNESS   500

static const gchar introspection_xml[] =
  "<node>"
  "  <interface name='org.droidian.Flashlightd'>"
  "    <method name='SetBrightness'>"
  "      <arg type='u' name='bvalue' direction='in'/>"
  "    </method>"
  "    <property type='i' name='Brightness' access='readwrite'/>"
  "  </interface>"
  "</node>";

static gint current_brightness = 0;
static GList *sysfs_nodes = NULL;
static gint on_brightness_val = DEFAULT_ON_BRIGHTNESS;
static guint registration_id = 0;
static GDBusConnection *global_connection = NULL;

static void trim_inplace(char *s) {
    char *p = s;
    while (isspace((unsigned char)*p)) p++;
    if (p != s) memmove(s, p, strlen(p) + 1);
    size_t len = strlen(s);
    while (len > 0 && isspace((unsigned char)s[len - 1])) {
        s[len - 1] = '\0';
        len--;
    }
}

static void load_config(void) {
    /* 1. Target brightness */
    FILE *bfp = fopen(CUSTOM_BRIGHTNESS_FILE, "r");
    if (bfp) {
        int val = 0;
        if (fscanf(bfp, "%d", &val) == 1 && val > 0) {
            on_brightness_val = val;
        }
        fclose(bfp);
    }

    /* 2. Sysfs nodes */
    FILE *nfp = fopen(CUSTOM_SYSFS_NODES_FILE, "r");
    if (nfp) {
        char line[256];
        while (fgets(line, sizeof(line), nfp)) {
            char *token = strtok(line, ",\n\r");
            while (token) {
                trim_inplace(token);
                if (token[0] != '\0' && token[0] != '#') {
                    sysfs_nodes = g_list_append(sysfs_nodes, g_strdup(token));
                }
                token = strtok(NULL, ",\n\r");
            }
        }
        fclose(nfp);
    }

    /* Fallback default nodes if none specified */
    if (!sysfs_nodes) {
        sysfs_nodes = g_list_append(sysfs_nodes, g_strdup("/sys/class/leds/flashlight/brightness"));
        sysfs_nodes = g_list_append(sysfs_nodes, g_strdup("/sys/class/leds/torch-light/brightness"));
        sysfs_nodes = g_list_append(sysfs_nodes, g_strdup("/sys/class/leds/led:torch_0/brightness"));
        sysfs_nodes = g_list_append(sysfs_nodes, g_strdup("/sys/class/leds/led:torch_1/brightness"));
        sysfs_nodes = g_list_append(sysfs_nodes, g_strdup("/sys/class/leds/led:switch_0/brightness"));
        sysfs_nodes = g_list_append(sysfs_nodes, g_strdup("/sys/class/leds/led:switch_1/brightness"));
        sysfs_nodes = g_list_append(sysfs_nodes, g_strdup("/sys/class/leds/led:switch_2/brightness"));
    }
}

static gint get_node_max_brightness(const gchar *path) {
    gchar *max_path = g_strdup(path);
    gchar *p = g_strrstr(max_path, "/brightness");
    if (p) {
        strcpy(p, "/max_brightness");
        FILE *fp = fopen(max_path, "r");
        if (fp) {
            int val = 0;
            if (fscanf(fp, "%d", &val) == 1 && val > 0) {
                fclose(fp);
                g_free(max_path);
                return val;
            }
            fclose(fp);
        }
    }
    g_free(max_path);
    return on_brightness_val;
}

static void apply_flashlight_state(gint brightness) {
    GList *l;
    for (l = sysfs_nodes; l != NULL; l = l->next) {
        const gchar *path = (const gchar *)l->data;
        if (access(path, F_OK) != 0) continue;

        int fd = open(path, O_WRONLY);
        if (fd < 0) continue;

        char buf[32];
        int write_val = 0;
        if (brightness > 0) {
            if (strstr(path, "switch")) {
                write_val = 255;
            } else if (on_brightness_val > 0) {
                write_val = on_brightness_val;
            } else {
                write_val = get_node_max_brightness(path);
            }
        } else {
            write_val = 0;
        }

        int len = snprintf(buf, sizeof(buf), "%d\n", write_val);
        if (len > 0) {
            ssize_t ret = write(fd, buf, (size_t)len);
            (void)ret;
        }
        close(fd);
    }
}

static void emit_properties_changed(GDBusConnection *connection) {
    if (!connection) return;

    GVariantBuilder changed_builder;
    GVariantBuilder invalidated_builder;

    g_variant_builder_init(&changed_builder, G_VARIANT_TYPE("a{sv}"));
    g_variant_builder_init(&invalidated_builder, G_VARIANT_TYPE("as"));

    g_variant_builder_add(&changed_builder, "{sv}", "Brightness", g_variant_new_int32(current_brightness));

    g_dbus_connection_emit_signal(
        connection,
        NULL,
        "/org/droidian/Flashlightd",
        "org.freedesktop.DBus.Properties",
        "PropertiesChanged",
        g_variant_new("(sa{sv}as)",
                      "org.droidian.Flashlightd",
                      &changed_builder,
                      &invalidated_builder),
        NULL
    );
}

static void set_brightness_internal(GDBusConnection *connection, gint val) {
    if (val < 0) val = 0;
    current_brightness = val;
    apply_flashlight_state(current_brightness);
    emit_properties_changed(connection);
}

static void handle_method_call(GDBusConnection *connection,
                               const gchar *sender,
                               const gchar *object_path,
                               const gchar *interface_name,
                               const gchar *method_name,
                               GVariant *parameters,
                               GDBusMethodInvocation *invocation,
                               gpointer user_data) {
    (void)sender;
    (void)object_path;
    (void)interface_name;
    (void)user_data;

    if (g_strcmp0(method_name, "SetBrightness") == 0) {
        guint32 bval = 0;
        g_variant_get(parameters, "(u)", &bval);
        set_brightness_internal(connection, (gint)bval);
        g_dbus_method_invocation_return_value(invocation, NULL);
    } else {
        g_dbus_method_invocation_return_error(invocation,
                                              G_DBUS_ERROR,
                                              G_DBUS_ERROR_UNKNOWN_METHOD,
                                              "Unknown method %s", method_name);
    }
}

static GVariant *handle_get_property(GDBusConnection *connection,
                                     const gchar *sender,
                                     const gchar *object_path,
                                     const gchar *interface_name,
                                     const gchar *property_name,
                                     GError **error,
                                     gpointer user_data) {
    (void)connection;
    (void)sender;
    (void)object_path;
    (void)interface_name;
    (void)user_data;

    if (g_strcmp0(property_name, "Brightness") == 0) {
        return g_variant_new_int32(current_brightness);
    }

    g_set_error(error, G_DBUS_ERROR, G_DBUS_ERROR_UNKNOWN_PROPERTY,
                "Unknown property %s", property_name);
    return NULL;
}

static gboolean handle_set_property(GDBusConnection *connection,
                                    const gchar *sender,
                                    const gchar *object_path,
                                    const gchar *interface_name,
                                    const gchar *property_name,
                                    GVariant *value,
                                    GError **error,
                                    gpointer user_data) {
    (void)sender;
    (void)object_path;
    (void)interface_name;
    (void)user_data;

    if (g_strcmp0(property_name, "Brightness") == 0) {
        gint val = g_variant_get_int32(value);
        set_brightness_internal(connection, val);
        return TRUE;
    }

    g_set_error(error, G_DBUS_ERROR, G_DBUS_ERROR_UNKNOWN_PROPERTY,
                "Unknown property %s", property_name);
    return FALSE;
}

static const GDBusInterfaceVTable interface_vtable = {
    handle_method_call,
    handle_get_property,
    handle_set_property,
    { 0 }
};

static void on_bus_acquired(GDBusConnection *connection,
                            const gchar *name,
                            gpointer user_data) {
    (void)name;
    (void)user_data;

    global_connection = connection;
    GError *error = NULL;
    GDBusNodeInfo *introspection_data = g_dbus_node_info_new_for_xml(introspection_xml, &error);
    if (!introspection_data) {
        g_printerr("Failed to parse introspection XML: %s\n", error ? error->message : "unknown");
        if (error) g_error_free(error);
        return;
    }

    registration_id = g_dbus_connection_register_object(
        connection,
        "/org/droidian/Flashlightd",
        introspection_data->interfaces[0],
        &interface_vtable,
        NULL,
        NULL,
        &error
    );

    if (registration_id == 0) {
        g_printerr("Failed to register object: %s\n", error ? error->message : "unknown");
        if (error) g_error_free(error);
    }
}

static void on_name_acquired(GDBusConnection *connection,
                             const gchar *name,
                             gpointer user_data) {
    (void)connection;
    (void)name;
    (void)user_data;
}

static void on_name_lost(GDBusConnection *connection,
                         const gchar *name,
                         gpointer user_data) {
    (void)connection;
    (void)user_data;
    g_printerr("Could not acquire name %s\n", name);
}

int main(int argc, char **argv) {
    (void)argc;
    (void)argv;

    load_config();

    GMainLoop *loop = g_main_loop_new(NULL, FALSE);

    g_bus_own_name(
        G_BUS_TYPE_SESSION,
        "org.droidian.Flashlightd",
        G_BUS_NAME_OWNER_FLAGS_REPLACE,
        on_bus_acquired,
        on_name_acquired,
        on_name_lost,
        NULL,
        NULL
    );

    g_main_loop_run(loop);
    g_main_loop_unref(loop);
    return 0;
}
