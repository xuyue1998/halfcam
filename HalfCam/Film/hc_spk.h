#pragma once
#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

int hc_spk_ready(const char *resources_dir, void *device);
int hc_spk_warm_up(const char *film_stock, const char *print_stock);
const char *hc_spk_last_error(void);

void *hc_spk_open(
    const float *rgb,
    uint32_t width,
    uint32_t height,
    const char *params_json
);

int hc_spk_reprint(
    void *session,
    const char *tier,
    uint16_t **rgba,
    uint32_t *width,
    uint32_t *height,
    uint32_t *stride,
    void **texture,
    void **hold
);

void hc_spk_result_free(void *hold);
void hc_spk_close(void *session);

void hc_pack_rgbaf_to_rgb(float *rgba, uint32_t pixels);

#ifdef __cplusplus
}
#endif
