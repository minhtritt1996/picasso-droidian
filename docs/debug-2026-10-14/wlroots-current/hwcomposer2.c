#include <android-config.h>
#include <assert.h>
#include <stdlib.h>
#include <stdio.h>
#include <math.h>
#include <stddef.h>
#include <malloc.h>
#include <sys/cdefs.h> // for __BEGIN_DECLS/__END_DECLS found in sync.h
#include <sync/sync.h>

#include <hybris/hwcomposerwindow/hwcomposer.h>

#include <hybris/hwc2/hwc2_compatibility_layer.h>

#include <wlr/util/log.h>
#include <wlr/interfaces/wlr_output.h>

#include "backend/hwcomposer.h"

typedef struct
{
	struct HWC2EventListener listener;
	struct wlr_hwcomposer_backend_hwc2 *hwc2;
} hwc_procs_v20;

const struct hwcomposer_impl hwcomposer_hwc2;

struct wlr_hwcomposer_backend_hwc2
{
	struct wlr_hwcomposer_backend hwc_backend;

	hwc2_compat_device_t *hwc2_device;
};

struct wlr_hwcomposer_output_hwc2
{
	struct wlr_hwcomposer_output output;

	hwc2_compat_display_t *hwc2_display;
	hwc2_compat_layer_t *hwc2_layer;
	int hwc2_last_present_fence;
	ANativeWindowBuffer *prev_buffer;
};

static struct wlr_hwcomposer_backend_hwc2 *hwc2_backend_from_base(struct wlr_hwcomposer_backend *hwc_backend)
{
	assert(hwc_backend->impl == &hwcomposer_hwc2);
	return (struct wlr_hwcomposer_backend_hwc2 *)hwc_backend;
}

static struct wlr_hwcomposer_output_hwc2 *hwc2_output_from_base(struct wlr_hwcomposer_output *output)
{
	// TODO: ensure it's the correct one?
	return (struct wlr_hwcomposer_output_hwc2 *)output;
}

static void hwcomposer2_vsync_callback(HWC2EventListener* listener, int32_t sequence_id,
		hwc2_display_t display, int64_t timestamp)
{
	struct wlr_hwcomposer_backend_hwc2 *hwc2 = ((hwc_procs_v20 *)listener)->hwc2;

	hwc2->hwc_backend.hwc_vsync_last_timestamp = timestamp;
}

static void hwcomposer2_hotplug_callback(HWC2EventListener* listener, int32_t sequence_id,
		hwc2_display_t display, bool connected,
		bool primary_display)
{
	struct wlr_hwcomposer_backend_hwc2 *hwc2 = ((hwc_procs_v20*) listener)->hwc2;

	wlr_log(WLR_INFO, "onHotplugReceived(%d, %" PRIu64 ", %s, %s)",
		sequence_id, display,
		connected ? "connected" : "disconnected",
		primary_display ? "primary\n" : "external\n");

	hwc2_compat_device_on_hotplug(hwc2->hwc2_device, display, connected);

	wlr_hwcomposer_backend_handle_hotplug((struct wlr_backend *)hwc2,
		(uint64_t)display, connected, primary_display);
}

static void hwcomposer2_refresh_callback(HWC2EventListener* listener, int32_t sequence_id,
		hwc2_display_t display)
{
}

struct wlr_hwcomposer_backend* hwcomposer2_api_init(hw_device_t *hwc_device)
{
	struct wlr_hwcomposer_backend_hwc2 *hwc2 =
		calloc(1, sizeof(struct wlr_hwcomposer_backend_hwc2));
	if (!hwc2) {
		wlr_log(WLR_ERROR, "Failed to allocate wlr_hwcomposer_backend_hwc2");
		return NULL;
	}

	hwcomposer_init (&hwc2->hwc_backend);

	hwc2_compat_device_t* hwc2_device = hwc2->hwc2_device = hwc2_compat_device_new(false);
	assert(hwc2_device);

	hwc2->hwc_backend.impl = &hwcomposer_hwc2;

	return &hwc2->hwc_backend;
}
static void hwcomposer2_close(struct wlr_hwcomposer_backend *hwc_backend)
{
}

static bool hwcomposer2_vsync_control(struct wlr_hwcomposer_output *output, bool enable)
{
	struct wlr_hwcomposer_backend *hwc_backend = output->hwc_backend;
	struct wlr_hwcomposer_output_hwc2 *hwc2_output = hwc2_output_from_base(output);

	wlr_log(WLR_DEBUG, "hwcomposer2: vsync_control: display %p, enable %d",
		hwc2_output->hwc2_display, enable);

	if (!output->hwc_is_primary || hwc_backend->hwc_vsync_enabled == enable) {
		return true;
	}

	if (hwc2_compat_display_set_vsync_enabled(hwc2_output->hwc2_display, enable ?
		HWC2_VSYNC_ENABLE : HWC2_VSYNC_DISABLE) == HWC2_ERROR_NONE) {
		hwc_backend->hwc_vsync_enabled = enable;

		return true;
	}

	return false;
}

static bool hwcomposer2_set_power_mode(struct wlr_hwcomposer_output *output, bool enable)
{
	struct wlr_hwcomposer_output_hwc2 *hwc2_output = hwc2_output_from_base(output);

	wlr_log(WLR_ERROR, ">>> hwcomposer2: FORCE POWER_MODE_ON (requested %d)", enable);
	hwc2_error_t err = hwc2_compat_display_set_power_mode(hwc2_output->hwc2_display, HWC2_POWER_MODE_ON);
	wlr_log(WLR_ERROR, ">>> hwcomposer2: set_power_mode result: %d", err);

	return true;
}

static void hwcomposer2_present(void *user_data, struct ANativeWindow *window,
		struct ANativeWindowBuffer *buffer)
{
	struct wlr_hwcomposer_output *output = (struct wlr_hwcomposer_output *)user_data;
	struct wlr_hwcomposer_output_hwc2 *hwc2_output = hwc2_output_from_base(output);

	uint32_t num_types = 0;
	uint32_t num_requests = 0;
	hwc2_error_t error = HWC2_ERROR_NONE;

	int acquireFenceFd = HWCNativeBufferGetFence(buffer);
	hwc2_compat_display_t* hwc_display = hwc2_output->hwc2_display;
	static int frame_count = 0;
	frame_count++;

	static bool power_on_done = false;
	if (!power_on_done) {
		hwc2_error_t perr = hwc2_compat_display_set_power_mode(hwc_display, HWC2_POWER_MODE_ON);
		wlr_log(WLR_ERROR, ">>> hwcomposer2_present: initial set_power_mode(ON) = %d", perr);
		power_on_done = true;
	}

	hwc2_compat_layer_set_composition_type(hwc2_output->hwc2_layer, HWC2_COMPOSITION_DEVICE);
	hwc2_compat_layer_set_buffer(hwc2_output->hwc2_layer, 0, buffer, acquireFenceFd);

	error = hwc2_compat_display_validate(hwc_display, &num_types,
		&num_requests);
	if (frame_count <= 10 || frame_count % 60 == 0) {
		wlr_log(WLR_ERROR, ">>> validate display %ld: err=%d types=%u reqs=%u",
			output->hwc_display_id, error, num_types, num_requests);
	}
	if (error != HWC2_ERROR_NONE && error != HWC2_ERROR_HAS_CHANGES) {
		wlr_log(WLR_ERROR, "prepare: validate failed for display %ld: %d",
			output->hwc_display_id, error);
		return;
	}

	if (num_types > 0 || num_requests > 0 || error == HWC2_ERROR_HAS_CHANGES) {
		error = hwc2_compat_display_accept_changes(hwc_display);
		if (error != HWC2_ERROR_NONE) {
			wlr_log(WLR_ERROR, "prepare: acceptChanges failed: %d", error);
			return;
		}
	}

	error = hwc2_compat_display_set_client_target(hwc_display, /* slot */0, buffer,
		acquireFenceFd,
		HAL_DATASPACE_UNKNOWN);

	int present_fence = -1;
	error = hwc2_compat_display_present(hwc_display, &present_fence);

	hwc2_compat_out_fences_t *release_fences = NULL;
	int rel_fence = -1;
	if (hwc2_compat_display_get_release_fences(hwc_display, &release_fences) == HWC2_ERROR_NONE && release_fences) {
		rel_fence = hwc2_compat_out_fences_get_fence(release_fences, hwc2_output->hwc2_layer);
		hwc2_compat_out_fences_destroy(release_fences);
	}

	if (output->hwc_last_present_fence != -1) {
		sync_wait(output->hwc_last_present_fence, 100);
		close(output->hwc_last_present_fence);
		hwc2_output->output.hwc_last_present_fence = -1;
	}
	if (rel_fence >= 0) {
		sync_wait(rel_fence, 100);
		close(rel_fence);
	}
	if (present_fence >= 0) {
		output->hwc_last_present_fence = dup(present_fence);
		HWCNativeBufferSetFence(buffer, present_fence);
	}

	if (frame_count <= 10 || frame_count % 60 == 0) {
		wlr_log(WLR_ERROR, ">>> hwcomposer2_present frame #%d: acq=%d rel=%d pres=%d err=%d",
			frame_count, acquireFenceFd, rel_fence, present_fence, error);
	}
}

static struct wlr_hwcomposer_output* hwcomposer2_add_output(struct wlr_hwcomposer_backend *hwc_backend, int display)
{
	struct wlr_hwcomposer_backend_hwc2 *hwc2 = hwc2_backend_from_base(hwc_backend);
	struct wlr_hwcomposer_output_hwc2 *hwc2_output =
		calloc(1, sizeof(struct wlr_hwcomposer_output_hwc2));
	if (hwc2_output == NULL) {
		wlr_log(WLR_ERROR, "Failed to allocate wlr_hwcomposer_output_hwc2");
		return NULL;
	}

	hwc2_output->output.hwc_last_present_fence = -1;
	hwc2_output->hwc2_display = hwc2_compat_device_get_display_by_id(hwc2->hwc2_device, display);
	hwc2_output->output.hwc_is_primary = (display == 0);

	HWC2DisplayConfig *config = hwc2_compat_display_get_active_config(hwc2_output->hwc2_display);
	assert(config);

	hwc2_output->output.hwc_width = config->width;
	hwc2_output->output.hwc_height = config->height;
	if (config->dpiX > 0 && config->dpiY > 0) {
		hwc2_output->output.hwc_phys_width = config->width / config->dpiX * 25.4; // inches to mm
		hwc2_output->output.hwc_phys_height = config->height / config->dpiY * 25.4; // inches to mm
	} else {
		hwc2_output->output.hwc_phys_width = 0;
		hwc2_output->output.hwc_phys_height = 0;
	}
	hwc2_output->output.hwc_refresh = (config->vsyncPeriod == 8333333LL || config->vsyncPeriod == 0) ?
		8333333LL : 8333333LL; // Force 120Hz (8.333ms)
	wlr_log(WLR_ERROR, ">>> Forced 120Hz: width=%d height=%d refresh=%ld (config vsyncPeriod=%d)",
		config->width, config->height, hwc2_output->output.hwc_refresh, config->vsyncPeriod);

	hwc2_compat_layer_t* layer = hwc2_output->hwc2_layer =
		hwc2_compat_display_create_layer(hwc2_output->hwc2_display);

	hwc2_compat_layer_set_blend_mode(layer, HWC2_BLEND_MODE_NONE);
	hwc2_compat_layer_set_composition_type(layer, HWC2_COMPOSITION_CLIENT);
	hwc2_compat_layer_set_source_crop(layer, 0.0f, 0.0f, hwc2_output->output.hwc_width, hwc2_output->output.hwc_height);
	hwc2_compat_layer_set_display_frame(layer, 0, 0, hwc2_output->output.hwc_width, hwc2_output->output.hwc_height);
	hwc2_compat_layer_set_visible_region(layer, 0, 0, hwc2_output->output.hwc_width, hwc2_output->output.hwc_height);
	hwc2_compat_layer_set_plane_alpha(layer, 1.0f);

	hwc2_output->output.hwc_last_present_fence = -1;

	// FIXME: This being here is wrong
	if (hwc2_output->output.hwc_is_primary) {
		hwc2->hwc_backend.hwc_device_refresh = hwc2_output->output.hwc_refresh;
	}

	return &hwc2_output->output;
}

static void hwcomposer2_destroy_output(struct wlr_hwcomposer_output *output)
{
	struct wlr_hwcomposer_output_hwc2 *hwc2_output = hwc2_output_from_base(output);
	struct wlr_hwcomposer_backend_hwc2 *hwc2 = hwc2_backend_from_base(output->hwc_backend);

	if (hwc2_output->prev_buffer) {
		int old_fence = HWCNativeBufferGetFence(hwc2_output->prev_buffer);
		if (old_fence >= 0) {
			close(old_fence);
		}
		hwc2_output->prev_buffer->common.decRef(&hwc2_output->prev_buffer->common);
		hwc2_output->prev_buffer = NULL;
	}

	hwc2_compat_device_destroy_display(hwc2->hwc2_device, hwc2_output->hwc2_display);

	free(hwc2_output);
}

static void hwcomposer2_register_callbacks(struct wlr_hwcomposer_backend *hwc_backend)
{
	int composer_sequence_id = 0;
	struct wlr_hwcomposer_backend_hwc2 *hwc2 = hwc2_backend_from_base(hwc_backend);

	hwc_procs_v20* procs = malloc(sizeof(hwc_procs_v20));
	procs->listener.on_vsync_received = hwcomposer2_vsync_callback;
	procs->listener.on_hotplug_received = hwcomposer2_hotplug_callback;
	procs->listener.on_refresh_received = hwcomposer2_refresh_callback;
	procs->hwc2 = hwc2;

	hwc2_compat_device_register_callback(hwc2->hwc2_device, &procs->listener,
		composer_sequence_id++);

	wlr_log(WLR_DEBUG, "hwcomposer2: register_callbaks: callbacks registered");
}

const struct hwcomposer_impl hwcomposer_hwc2 = {
	.register_callbacks = hwcomposer2_register_callbacks,
	.present = hwcomposer2_present,
	.vsync_control = hwcomposer2_vsync_control,
	.set_power_mode = hwcomposer2_set_power_mode,
	.add_output = hwcomposer2_add_output,
	.destroy_output = hwcomposer2_destroy_output,
	.close = hwcomposer2_close,
};
