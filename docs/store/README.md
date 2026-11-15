# HALF CAM 商店物料

执行规范见 `docs/APPSTORE.md`。本目录是已生成的图。

## 产出

| 路径 | 用途 |
|---|---|
| `screenshots/` | 当前设备栏支持的 1206 × 2622 竖版截屏，本地生成，不进 git |
| `creative/` | 标题 3840 × 1646、搜索结果 3840 × 2560，五语创意素材，不进 git |
| `icon/AppIcon-1024.png` | 精修 Icon |
| `icon/AppIcon-180.png` | 主屏预览 |
| `src/*.jpg` | 样片源文件，不进商店、不进 git |

Xcode 图标已同步到：

`HalfCam/Assets.xcassets/AppIcon.appiconset/AppIcon.png`

## 当前版：真实截图排版

本地原图按语言放在仓库根目录 `商店页/`；该目录与输出均已忽略，不提交 Git。当前版为 **v4，1206 × 2622**，对应目前 Connect 设备栏明确支持的竖版截屏尺寸。五种语言均使用对应语言的真实实机截图，不再共用中文界面。

```text
商店页/
  简体中文/
  繁体中文/
  英语/
  日语/
  韩语/
```

```sh
python3 scripts/store_screenshots.py
```

繁体中文、英语、日语、韩语版本：

```sh
python3 scripts/store_screenshots.py --locale zh-Hant
python3 scripts/store_screenshots.py --locale en-US
python3 scripts/store_screenshots.py --locale ja
python3 scripts/store_screenshots.py --locale ko
```

`--locale all` 重出全部五种语言，并在 `screenshots/` 生成五语合集 `HALF-CAM-5-languages-1206x2622.zip`，按语言分目录，仅含 25 张上传图。每种语言的标题、说明、等待与结尾文案分别排版，使用支持对应语言的衬线字体（繁体为 Songti TC），并自动检查文字宽度。

| 语言 | 本地输出目录 | 上传包 |
|---|---|---|
| 简体中文（默认） | `screenshots/zh-Hans-v4/` | `HALF-CAM-zh-Hans-1206x2622.zip` |
| 繁體中文 | `screenshots/zh-Hant-v4/` | `HALF-CAM-zh-Hant-1206x2622.zip` |
| English | `screenshots/en-US-v4/` | `HALF-CAM-en-US-1206x2622.zip` |
| 日本語 | `screenshots/ja-v4/` | `HALF-CAM-ja-1206x2622.zip` |
| 한국어 | `screenshots/ko-v4/` | `HALF-CAM-ko-1206x2622.zip` |

每个目录含按顺序上传的五张 PNG、`_preview.jpg` 和仅含五张 PNG 的 ZIP。脚本按 `SOURCE_SETS` 显式匹配各语言截图，不通过文件排序猜测内容。相册两组对页的裁切位置按各语言实际滚动位置设置，避免裁断照片和片边。若某种语言缺图，脚本报错，不用简中图补位。

可用 `--source` 指向含语言子目录的原图根目录，或单种语言的截图目录。当前原图和排版坐标为 1320 × 2868，最终通过等比缩放及极小的留边适配导出为 1206 × 2622，不非等比拉伸。替换原图时需同步核对文件名、原图尺寸和裁切位置。

**旧 v2 / v3 为 1320 × 2868，仅保留本地作历史参考，不上传到当前设备栏。本次只上传 v4。** 这里按用户当前 Connect 栏位制作，其他设备栏位需以其实际提示为准，不能用同一个尺寸保证覆盖全部机型。

中文输出到 `docs/store/screenshots/zh-Hans-v4/`：

- `01-diptych.png`：两格照片，装下一段日常。
- `02-camera.png`：从装一卷开始，把今天慢慢拍下来。
- `03-load.png`：选一卷，带着它出门。
- `04-wait.png`：照片先存着，期待慢慢来。
- `05-develop.png`：这一卷，会洗出什么？
- `_preview.jpg`：整套预览，不上传 App Store。
- `HALF-CAM-zh-Hans-1206x2622.zip`：仅含五张上传用 PNG。

所有截屏上传用图均为 1206 × 2622 的 RGB PNG，无透明通道；只裁切、等比缩放与排版，不替换界面或重调前景照片颜色。原始截图不修改。当前原图里的胶片名称按真实界面保留，未做商标授权认定；提交前仍需核对展示素材的权利。

## 标题与搜索结果创意素材

```sh
python3 scripts/store_creative.py --locale all
```

输出到 `docs/store/creative/{语言}/`，支持与截屏相同的五种语言：

| 文件 | 用途 | 尺寸 |
|---|---|---|
| `01-header-3840x1646.png` | Connect「标题」 | 3840 × 1646 |
| `02-search-3840x2560.png` | Connect「搜索结果」 | 3840 × 2560 |
| `_preview.jpg` | 仅供检查，不上传 | 联系表 |
| `HALF-CAM-{语言}-creative.zip` | 对应语言的两张上传 PNG | — |

`creative/HALF-CAM-creative-5-languages.zip` 为五语合集，仅包含 10 张上传图。

脚本检查核心文字和前景图像均位于以下安全区：

- 标题：x1097、y493，1646 × 661。
- 搜索结果：x836、y765，2168 × 1030。

真实前景截图和照片不重绘；背景由同一张照片虚化、压暗，作为氛围延伸。无价格、折扣、兑换码或网址。仍需在 Connect 预览中核对实际设备和方向的裁切。

规范：[Apple 创意素材规范](https://developer.apple.com/help/app-store-connect/reference/app-information/creative-assets-specifications/)。

## App 预览视频与截屏不能混用

当前设备栏支持的视频尺寸为 **886 × 1920** 或 **1920 × 886**；视频需由真实操作录屏剪辑导出。当前只有静态截图，所以未制作预览视频，也不把静态联系表或 PNG 当视频提交。

上传顺序：

1. 五语 v4 的 PNG → 各语言「截屏」。
2. 五语 creative 的 header / search PNG → 对应「标题 / 搜索结果」。
3. App 预览暂留空；准备真实录屏后再制作，不影响先用截屏提交。

## 旧版占位图脚本（不用于本次商店上传）

```sh
python3 scripts/store_art.py
```

旧脚本样片来自 Unsplash，脚本会缓存到 `src/`。无网时走程序化兜底。不要用它重出当前版真实截图。

## 注意

- 旧版占位图的胶卷名为通用名；当前版使用实际截图，不伪造界面
- 不要把 `src/` 里带可识别模特的原图直接上传商店或提交进仓库
- 当前版宣传截图（`screenshots/`）和 App 内样片 JPEG 不进 git，真机样片备齐后再上
- 当前真实截图与营销字层均已有简中、繁中、英文、日文、韩文版本
