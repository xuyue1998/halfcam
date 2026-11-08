#include "hc_spk.h"
#include "spektrafilm/spk_engine.h"

#include <stdlib.h>
#include <string.h>

static spk_engine *engine_handle(const char *resources_dir) {
    static spk_engine *engine = NULL;
    static int tried = 0;
    if (tried) return engine;
    tried = 1;
    const char *dir = resources_dir && resources_dir[0] ? resources_dir : "engine";
    engine = spk_engine_create(dir, NULL);
    return engine;
}

int hc_spk_ready(const char *resources_dir) {
    return engine_handle(resources_dir) != NULL;
}

int hc_spk_render(
    const float *rgb,
    uint32_t width,
    uint32_t height,
    const char *params_json,
    uint16_t **out_rgba,
    uint32_t *out_width,
    uint32_t *out_height,
    uint32_t *out_stride
) {
    if (!rgb || !width || !height || !out_rgba) return -1;
    *out_rgba = NULL;
    spk_engine *engine = engine_handle(NULL);
    if (!engine) return -1;

    spk_image image;
    memset(&image, 0, sizeof image);
    image.data = rgb;
    image.width = width;
    image.height = height;
    image.channels = 3;

    char *opened = NULL;
    spk_session *session = spk_open(engine, &image, params_json, &opened);
    if (opened) spk_string_free(opened);
    if (!session) return -1;

    char *solved = NULL;
    spk_status st = spk_solve(session, "both", &solved);
    if (solved) spk_string_free(solved);
    if (st != SPK_OK) {
        spk_session_release(session);
        return -1;
    }

    spk_result result;
    memset(&result, 0, sizeof result);
    st = spk_render(session, "live", &result);
    if (st != SPK_OK || !result.rgba16 || !result.width || !result.height) {
        spk_result_free(&result);
        spk_session_release(session);
        return -1;
    }

    uint32_t stride = result.row_stride_px ? result.row_stride_px : result.width;
    size_t count = (size_t)stride * result.height * 4;
    uint16_t *copy = (uint16_t *)malloc(count * sizeof(uint16_t));
    if (!copy) {
        spk_result_free(&result);
        spk_session_release(session);
        return -1;
    }
    memcpy(copy, result.rgba16, count * sizeof(uint16_t));
    *out_rgba = copy;
    if (out_width) *out_width = result.width;
    if (out_height) *out_height = result.height;
    if (out_stride) *out_stride = stride;

    spk_result_free(&result);
    spk_session_release(session);
    return 0;
}

void hc_spk_free(uint16_t *rgba) {
    free(rgba);
}
