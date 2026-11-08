# 光谱引擎接入

HalfCam 显影只走 SpektraLab C ABI（`spk_engine.h`）。引擎失败该格跳过，不再回退 LUT。

## 现在这版能做什么

- 许可证：GPL-3.0（`LICENSE`）+ CC BY-SA 4.0 胶片配置声明（`LICENSE-SPEKTRAFILM.txt`）
- Swift 桥：`HalfCam/Film/SpektraEngine.swift`
- 输入：ProRAW 优先，JPEG/HEIC 线性化回退（`Ingest.swift`）
- 一格一次 4032 ingest：`spk_open` → `spk_solve("both")` → `spk_reprint("live")` 出 thumb → 释放 live → `spk_reprint("full")` 出正片并 stamp
- 装卷仍只选胶片；相纸用 `FilmCatalog.spkPaper`
- 相机：设备支持就拍 Apple ProRAW

## 把真引擎编进来

1. 按 SpektraLab 的 `engine/build.sh` 给 **iphoneos arm64** 编 metallib / 静态库
2. 把 `engine/resources/` 拷进 app bundle（`HalfCam/Resources/engine/`）
3. 加 `SPEKTRA_ENGINE=1`
4. Header Search Path 指向 `vendor/spektralab/include`

注意：`row_stride_px` 单位是像素。每卷第一次显影前会 `spk_warm_up`。
