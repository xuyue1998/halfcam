#pragma once
#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

int hc_spk_ready(const char *resources_dir);

int hc_spk_render(
    const float *rgb,
    uint32_t width,
    uint32_t height,
    const char *params_json,
    uint16_t **out_rgba,
    uint32_t *out_width,
    uint32_t *out_height,
    uint32_t *out_stride
);

void hc_spk_free(uint16_t *rgba);

#ifdef __cplusplus
}
#endif
