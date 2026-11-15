# 胶片样片

每卷放 **2–3 张** 洗出来的效果图。文件夹名就是类型标记，直接把照片丢进去即可。

```sh
python3 scripts/pack_samples.py
```

脚本会按标记匹配到对应胶卷，压成 960 边 JPEG，写进 `HalfCam/Resources/samples/`。

## 按卷放（推荐）

| 文件夹 | 胶卷 |
|---|---|
| `PROVIA 100F` | 通透 · 万能 |
| `EKTACHROME 100` | 鲜明 · 通用 |
| `VELVIA 100` | 浓彩 · 风景 |
| `KODACHROME 64` | 经典 · 暖调 |
| `PORTRA 160` | 柔和 · 人像 |
| `PORTRA 400` | 低反差 · 人像 |
| `PORTRA 800` | 低光 · 人像 |
| `PORTRA 800 +1` | 推一档 |
| `PORTRA 800 +2` | 推两档 |
| `GOLD 200` | 琥珀 · 日常 |
| `EKTAR 100` | 浓彩 · 细腻 |
| `ULTRAMAX 400` | 饱和 · 日常 |
| `SUPERIA 400` | 青绿 · 日常 |
| `C200` | 轻快 · 日常 |
| `PRO 400H` | 青冷 · 人像 |
| `CINESTILL 800T` | 钨灯 · 夜色 |
| `VISION3 50D` | 日光 · 细腻 |
| `VISION3 250D` | 低反差 · 电影 |
| `VISION3 200T` | 钨灯 · 电影 |
| `VISION3 500T` | 钨灯 · 夜戏 |
| `VERITA 200D` | 日光 · 电影 |
| `ACROS 100 II` | 细腻 · 黑白 |
| `T-MAX 100` | 锐利 · 黑白 |
| `TRI-X 400` | 粗粒 · 街拍 |
| `HP5 PLUS 400` | 宽容 · 黑白 |

## 按味道放（某卷还没齐时会借）

这些是共享池。某卷自己的文件夹不足 2 张时，会从对应味道补：

| 文件夹 | 补给 |
|---|---|
| `_人像` | Portra / PRO 400H |
| `_风景` | Velvia / Provia |
| `_日常` | Gold / Superia / C200 / Ultramax |
| `_夜色` | Cinestill / Vision3 500T |
| `_电影` | Vision3 / Verita |
| `_黑白` | Acros / T-Max / Tri-X / HP5 |
| `_幻灯` | 所有反转片 |
| `_彩色` | 所有彩色负片 |

## 也认这些写法

- 文件夹用胶卷 id：`kodak_portra_400`
- 文件名带标记：`PORTRA400_街.jpg`、`800T-1.heic`
- 中文简称：`人像`、`夜色`、`黑白`

jpg / png / heic / webp 都可以。iPhone 原图直接丢进去就行。

从 HalfCam 倒出的照片也可以直接扔在 `SimplePhoto/` 根目录：脚本会读 EXIF 里的胶卷名，自动匹配进对应卷。
