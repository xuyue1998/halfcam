# HALF CAM 商店物料

执行规范见 `docs/APPSTORE.md`。本目录是已生成的图。

## 产出

| 路径 | 用途 |
|---|---|
| `screenshots/zh-Hans/01-diptych.png` … `06-album.png` | App Store 6.7" 主故事图，`1320×2868` |
| `screenshots/zh-Hans/_preview.jpg` | 六张并排预览 |
| `icon/AppIcon-1024.png` | 精修 Icon |
| `icon/AppIcon-180.png` | 主屏预览 |
| `src/*.jpg` | 样片源文件，不进商店、不进 git |

Xcode 图标已同步到：

`HalfCam/Assets.xcassets/AppIcon.appiconset/AppIcon.png`

## 重出

```sh
python3 scripts/store_art.py
```

样片来自 Unsplash，脚本会缓存到 `src/`。无网时走程序化兜底。

## 注意

- 截图里的胶卷名是商店安全版：`COLOR 400` / `GOLD 200` / `SLIDE 100` / `VISION 250`
- 不要把 `src/` 里带可识别模特的原图直接上传商店或提交进仓库（已在 `.gitignore`）
- 英文 / 日文 / 繁中字层还没出，改 `scripts/store_art.py` 的标题字典即可复用画面
