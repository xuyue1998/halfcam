#include "spektrafilm/spk_engine.h"

#ifndef SPEKTRA_ENGINE

static const char *k_err = "spektra engine not linked; LUT fallback";

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
