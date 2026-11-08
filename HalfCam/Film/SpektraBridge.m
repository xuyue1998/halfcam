#include "hc_spk.h"
#include "spektrafilm/spk_engine.h"

#include <stdlib.h>
#include <string.h>

#ifndef SPEKTRA_ENGINE

static const char *k_err = "spektra engine not linked";

spk_engine *spk_engine_create(const char *resources_dir, void *device) {
    (void)resources_dir;
    (void)device;
    return 0;
}

void spk_engine_destroy(spk_engine *engine) { (void)engine; }

const char *spk_capabilities(spk_engine *engine) {
    (void)engine;
    return "{}";
}

const char *spk_params_schema(spk_engine *engine) {
    (void)engine;
    return "{}";
}

const char *spk_memory_report(spk_engine *engine) {
    (void)engine;
    return "{}";
}

spk_status spk_warm_up(spk_engine *engine, const char *film_stock, const char *print_stock, char **out_json) {
    (void)engine;
    (void)film_stock;
    (void)print_stock;
    if (out_json) *out_json = 0;
    return SPK_ERR_IO;
}

spk_session *spk_open(spk_engine *engine, const spk_image *input, const char *params_delta_json, char **out_json) {
    (void)engine;
    (void)input;
    (void)params_delta_json;
    if (out_json) *out_json = 0;
    return 0;
}

spk_session *spk_open_device(spk_engine *engine, const spk_device_image *input, const char *params_delta_json, char **out_json) {
    (void)engine;
    (void)input;
    (void)params_delta_json;
    if (out_json) *out_json = 0;
    return 0;
}

spk_status spk_set_params(spk_session *session, const char *params_delta_json, char **out_json) {
    (void)session;
    (void)params_delta_json;
    if (out_json) *out_json = 0;
    return SPK_ERR_IO;
}

spk_status spk_get_params(spk_session *session, char **out_json) {
    (void)session;
    if (out_json) *out_json = 0;
    return SPK_ERR_IO;
}

spk_status spk_solve(spk_session *session, const char *target, char **out_json) {
    (void)session;
    (void)target;
    if (out_json) *out_json = 0;
    return SPK_ERR_IO;
}

spk_status spk_contrast_mask_field(spk_session *session, const char *tier, const float **out_delta, uint32_t *out_grid_w, uint32_t *out_grid_h) {
    (void)session;
    (void)tier;
    if (out_delta) *out_delta = 0;
    if (out_grid_w) *out_grid_w = 0;
    if (out_grid_h) *out_grid_h = 0;
    return SPK_ERR_UNSUPPORTED;
}

spk_status spk_scene_latitude(spk_session *session, const char *request_json, char **out_json) {
    (void)session;
    (void)request_json;
    if (out_json) *out_json = 0;
    return SPK_ERR_UNSUPPORTED;
}

spk_status spk_overscan_geometry(spk_session *session, char **out_json) {
    (void)session;
    if (out_json) *out_json = 0;
    return SPK_ERR_UNSUPPORTED;
}

spk_status spk_reprint(spk_session *session, const char *tier, spk_result *out) {
    (void)session;
    (void)tier;
    if (out) {
        out->rgba16 = 0;
        out->texture = 0;
        out->width = 0;
        out->height = 0;
        out->row_stride_px = 0;
        out->elapsed_ms = 0;
        out->reprint = 0;
        out->negative_was_cached = 0;
        out->progress_id[0] = 0;
    }
    return SPK_ERR_IO;
}

spk_status spk_render(spk_session *session, const char *tier, spk_result *out) {
    return spk_reprint(session, tier, out);
}

const char *spk_print_lut_catalog(spk_engine *engine) {
    (void)engine;
    return "{}";
}

spk_status spk_print_lut_table(spk_engine *engine, const char *print_stock, const float **out_table, uint32_t *out_size) {
    (void)engine;
    (void)print_stock;
    if (out_table) *out_table = 0;
    if (out_size) *out_size = 0;
    return SPK_ERR_IO;
}

spk_status spk_preview_stock_lut(spk_session *session, const char *print_stock, const char *tier, spk_result *out, char **out_json) {
    (void)print_stock;
    if (out_json) *out_json = 0;
    return spk_reprint(session, tier, out);
}

spk_status spk_export_di(spk_session *session, const char *print_stock, spk_result *out, char **out_json) {
    (void)print_stock;
    if (out_json) *out_json = 0;
    return spk_reprint(session, "full", out);
}

spk_status spk_render_digital_intermediate(spk_session *session, spk_result *out, char **out_json) {
    if (out_json) *out_json = 0;
    return spk_reprint(session, "full", out);
}

spk_status spk_output_transform(spk_engine *engine, const char *src_cs, const char *dst_cs, const char *gamut_compress_json, char **out_json, const float **out_cmax, uint32_t *out_cmax_count) {
    (void)engine;
    (void)src_cs;
    (void)dst_cs;
    (void)gamut_compress_json;
    if (out_json) *out_json = 0;
    if (out_cmax) *out_cmax = 0;
    if (out_cmax_count) *out_cmax_count = 0;
    return SPK_ERR_UNSUPPORTED;
}

void spk_result_free(spk_result *result) { (void)result; }
void spk_session_release(spk_session *session) { (void)session; }
void spk_cancel(spk_session *session, const char *progress_id) {
    (void)session;
    (void)progress_id;
}

spk_status spk_progress(spk_session *session, const char *progress_id, char **out_json) {
    (void)session;
    (void)progress_id;
    if (out_json) *out_json = 0;
    return SPK_ERR_IO;
}

void spk_string_free(char *s) { (void)s; }

const char *spk_last_error(spk_engine *engine) {
    (void)engine;
    return k_err;
}

const char *spk_build_info(void) { return "halfcam-stub"; }

#endif

static spk_engine *g_engine = NULL;
static int g_tried = 0;

static spk_engine *engine_handle(const char *resources_dir, void *device) {
    if (g_tried) return g_engine;
    g_tried = 1;
    const char *dir = resources_dir && resources_dir[0] ? resources_dir : "engine";
    g_engine = spk_engine_create(dir, device);
    return g_engine;
}

int hc_spk_ready(const char *resources_dir, void *device) {
    return engine_handle(resources_dir, device) != NULL;
}

int hc_spk_warm_up(const char *film_stock, const char *print_stock) {
    if (!g_engine) return -1;
    char *json = NULL;
    spk_status st = spk_warm_up(g_engine, film_stock, print_stock, &json);
    if (json) spk_string_free(json);
    return st == SPK_OK ? 0 : -1;
}

const char *hc_spk_last_error(void) {
    return spk_last_error(g_engine);
}

void *hc_spk_open(
    const float *rgb,
    uint32_t width,
    uint32_t height,
    const char *params_json
) {
    if (!rgb || !width || !height || !g_engine) return NULL;
    spk_image image;
    memset(&image, 0, sizeof image);
    image.data = rgb;
    image.width = width;
    image.height = height;
    image.channels = 3;
    char *opened = NULL;
    spk_session *session = spk_open(g_engine, &image, params_json, &opened);
    if (opened) spk_string_free(opened);
    if (!session) return NULL;
    char *solved = NULL;
    spk_status st = spk_solve(session, "both", &solved);
    if (solved) spk_string_free(solved);
    if (st != SPK_OK) {
        spk_session_release(session);
        return NULL;
    }
    return session;
}

int hc_spk_reprint(
    void *session,
    const char *tier,
    uint16_t **rgba,
    uint32_t *width,
    uint32_t *height,
    uint32_t *stride,
    void **texture,
    void **hold
) {
    if (rgba) *rgba = NULL;
    if (texture) *texture = NULL;
    if (hold) *hold = NULL;
    if (!session || !tier) return -1;
    spk_result *result = (spk_result *)calloc(1, sizeof(spk_result));
    if (!result) return -1;
    spk_status st = spk_reprint((spk_session *)session, tier, result);
    if (st != SPK_OK || !result->rgba16 || !result->width || !result->height) {
        spk_result_free(result);
        free(result);
        return -1;
    }
    if (rgba) *rgba = (uint16_t *)(uintptr_t)result->rgba16;
    if (width) *width = result->width;
    if (height) *height = result->height;
    if (stride) *stride = result->row_stride_px ? result->row_stride_px : result->width;
    if (texture) *texture = result->texture;
    if (hold) *hold = result;
    else {
        spk_result_free(result);
        free(result);
        return -1;
    }
    return 0;
}

void hc_spk_result_free(void *hold) {
    if (!hold) return;
    spk_result *result = (spk_result *)hold;
    spk_result_free(result);
    free(result);
}

void hc_spk_close(void *session) {
    if (session) spk_session_release((spk_session *)session);
}

void hc_pack_rgbaf_to_rgb(float *rgba, uint32_t pixels) {
    if (!rgba || !pixels) return;
    float *dst = rgba;
    const float *src = rgba;
    for (uint32_t i = 0; i < pixels; i++) {
        dst[0] = src[0];
        dst[1] = src[1];
        dst[2] = src[2];
        dst += 3;
        src += 4;
    }
}
