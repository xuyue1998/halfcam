# SpektraLab

HALF CAM 的显影只走 SpektraLab C ABI（`spk_engine.h`）。引擎失败则跳过该格，不再回退 LUT。

## English

Development in HALF CAM uses only the SpektraLab C ABI (`spk_engine.h`). If the engine fails, that frame is skipped. There is no LUT fallback.

### What this build does

- Licence: GPL-3.0 (`LICENSE`) plus CC BY-SA 4.0 film-profile notice (`LICENSE-SPEKTRAFILM.txt`)
- Swift bridge: `HalfCam/Film/SpektraEngine.swift`
- Input: Apple ProRAW when the device supports it; JPEG / HEIC linearized fallback (`Ingest.swift`)
- One frame, one 4032 ingest: `spk_open` → `spk_solve("both")` → `spk_reprint("live")` for the thumb → release live → `spk_reprint("full")` for the print, then stamp
- Loading a roll still chooses film only; paper comes from `FilmCatalog.spkPaper`

### Building the engine into the app

1. Follow SpektraLab’s `engine/build.sh`, or run `./scripts/build-spektra-ios.sh`, for **iphoneos arm64** metallib / static library
2. Copy `engine/resources/` into the app bundle (`HalfCam/Resources/engine/`)
3. Keep `SPEKTRA_ENGINE=1` (already set in this project)
4. Point Header Search Paths at `vendor/spektralab/include`

`row_stride_px` is in pixels. The first develop of each roll calls `spk_warm_up`.

Fetch a pinned SpektraLab commit with `./scripts/fetch-spektralab.sh`.

---

## 中文

HALF CAM 显影只走 SpektraLab C ABI（`spk_engine.h`）。引擎失败该格跳过，不再回退 LUT。

### 现在这版能做什么

- 许可证：GPL-3.0（`LICENSE`）+ CC BY-SA 4.0 胶片配置声明（`LICENSE-SPEKTRAFILM.txt`）
- Swift 桥：`HalfCam/Film/SpektraEngine.swift`
- 输入：设备支持则拍 Apple ProRAW；JPEG / HEIC 线性化回退（`Ingest.swift`）
- 一格一次 4032 ingest：`spk_open` → `spk_solve("both")` → `spk_reprint("live")` 出缩略图 → 释放 live → `spk_reprint("full")` 出正片并 stamp
- 装卷仍只选胶片；相纸用 `FilmCatalog.spkPaper`

### 把真引擎编进来

1. 按 SpektraLab 的 `engine/build.sh`，或运行 `./scripts/build-spektra-ios.sh`，给 **iphoneos arm64** 编 metallib / 静态库
2. 把 `engine/resources/` 拷进 app bundle（`HalfCam/Resources/engine/`）
3. 保持 `SPEKTRA_ENGINE=1`（本工程已打开）
4. Header Search Path 指向 `vendor/spektralab/include`

注意：`row_stride_px` 单位是像素。每卷第一次显影前会 `spk_warm_up`。

用 `./scripts/fetch-spektralab.sh` 拉取钉死的 SpektraLab commit。
