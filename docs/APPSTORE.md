# HALF CAM App Store 商店页计划

对内执行文档。填 App Store Connect、出截图、拍 Preview 都按这一份。  
产品本体见 `PLAN.md`。法律页见 `docs/legal.html` / `docs/privacy.html`。

---

## 0. 先锁死的决策

| # | 决策 | 锁定 |
|---|---|---|
| 1 | 商店页气质 | 一卷胶片的开箱仪式，不是功能说明书 |
| 2 | 截图叙事 | 「一卷的故事」，禁止功能宫格 |
| 3 | 第一张截图 | 洗好的半格对页（先给结果） |
| 4 | 显示名 | `HALF CAM`（已在 Xcode `CFBundleDisplayName`） |
| 5 | 商店 Name | 带「半格」，吃搜索 |
| 6 | 首发副标题 | 功能向，吃搜索；品牌定了再换成铭牌句 |
| 7 | 商标 | 商店物料不出现富士 / 柯达 / CineStill / Olympus / 竞品名 |
| 8 | 禁用词 | 滤镜、美颜、一键、AI、100+ |
| 9 | 必现词 | 半格、装卷、显影 |
| 10 | 首发最小集 | 截图 5 张 + 20s Preview + 简中/英文描述 |

一句话：

> 商店页不是「好看的相机 App」。  
> 用户划到第三张时应当明白：先装卷、显影前不预览、拍满后送入暗房、相邻两格组成对页。

---

## 1. 定位

**品类**：装在 iPhone 里的半格胶片机。不是滤镜包，不是美颜相机。

**用户买的四件事**

1. 装卷、过片，再按快门，有清楚的拍摄节奏
2. 拍完看不见，会惦记
3. 拍满一卷，再见照片
4. 打开时有开盲盒的仪式

**对谁说**

- 核心：拍过胶片、用过半格、嫌滤镜相机假的人
- 扩圈：被「拍完不能看」钩住的年轻用户
- 不说：要美颜、要立刻出片、要 100 个滤镜的人

**语气**

短、克制、有实体感。像机身说明，但不让用户猜操作。
不训诫用户，不夸大真实硬件或即时显影。界面术语与说明规范见 `docs/COPY.md`。

**三个必须反复出现**

半格 · 装卷 · 显影

**三个禁止出现**

滤镜 · 美颜 · 一键

---

## 2. 视觉系统

商店页必须和 App 同一套物质感。下载后对得上，才不会被差评打「和宣传不一样」。

### 2.1 色彩

| 角色 | 色值 | 用法 |
|---|---|---|
| 机身黑 | `#0E0D0C` | 截图底、视频底 |
| 暗房红 | `#B42318` | 快门点、高潮强调 |
| 黄铜 | `#C4A574` | 小标、计数、英文副句 |
| 相纸米 | `#F3EDE4` | 主句 |
| 雾灰 | `#8A8178` | 辅助说明，绝不做主文案 |

每张截图换一种光源，底色不变：

1. 冷白取景  
2. 皮革暖  
3. 全黑未显影  
4. 胶卷盒色块（自有包装）  
5. 安全灯红  
6. 相纸亮起  

### 2.2 字体

| 用途 | 中文 | 西文 |
|---|---|---|
| 主句 | 思源宋体 SemiBold / 霞鹜文楷 | New York / Iowan Old Style |
| 小标、计数 | 同款等宽或 SF Mono | SF Mono |
| 禁止 | 圆体、海报粗黑、渐变字、霓虹描边 | — |

字距略松。主句不超过两行，每行不超过 12 个汉字。

### 2.3 物质语言

截图里要看见这些，不要「画」成扁平图标：

- 胶片齿孔、暗盒、显影罐、药液弯月面、皮革机身、计数窗
- 照片只以 **3:4 半格** 或 **3:2 对页** 出现，禁止 1:1
- 手机 UI 是暗房桌上的一件物体，不是纯色营销底上的悬浮样机
- 样片必须是 App 里真实显影出来的，禁止套网图 LUT 冒充

### 2.4 Icon

现有图标方向正确：黑底、半格中缝、一颗红快门。商店页不另做花哨图标。

精修只做一次：

- 中缝再细 1px，在 60pt 仍能认
- 快门红略降饱和，浅色/深色主屏都站得住
- 1024 不要圆角（App Store 会自己裁）
- 搜索结果里的记忆点：「那个有红点和中缝的黑方块」

---

## 3. 截图

### 3.1 规格

| 设备 | 尺寸 | 是否首发必出 |
|---|---|---|
| iPhone 6.7" | `1320×2868` 或 `1290×2796` | 必出 |
| iPhone 6.5" | `1284×2778` | 有余力再出，可用 6.7" 缩放 |
| iPad 13" | `2064×2752` | 仅当 iPad 体验可展示时 |

- 最多 10 张，转化看前 3 张（搜索结果只露出这些）
- 竖图、全出血
- 状态栏保持隐藏（和 App 一致）
- 真实 UI 截屏，营销层只加纸边、齿孔、一句字
- 不要 iOS 设备外框套娃（App 已经是机身）

### 3.2 统一版式

```
┌─────────────────────────┐
│  距顶 72pt               │
│  小标  MONO  黄铜  13pt  │
│  主句  宋体  相纸米 28pt │  ← 最多两行
│  距主句 40pt 进入画面    │
│                         │
│        [画面]            │
│                         │
│  底边齿孔 / 纸边 24pt    │
└─────────────────────────┘
```

安全区：左右各 80pt。主句不要压进取景窗或人脸。  
文案层是独立 PSD/Figma 组，出多语言只替换这一层。

### 3.3 分镜（标准 6 张）

首发可砍到 5 张：01、02、03、05、06。04 装卷有商标风险，需要「商店安全版」包装后再上。

---

#### 01 钩子 · 对页揭晓

搜索第一张。决定点不点。先给结果。

| | 内容 |
|---|---|
| 画面 | 一张洗好的半格对页，中缝 2mm 黑。人像或街景，一眼是胶片。对页周围留相纸边。不要整页 UI。 |
| 光源 | 相纸亮起，底仍是机身黑 |
| 小标 | `HALF CAM` |
| 主句 简中 | `拍满一卷，再见照片。` |
| 主句 繁中 | `拍滿一捲，再見照片。` |
| 主句 EN | `Finish the roll. Then see what you caught.` |
| 主句 日 | `写真は、現像してから。` |
| 主句 韩 | `한 롤을 다 찍고, 사진을 만나요.` |
| 目的 | 证明「洗出来好看」，再讲规矩 |
| 样片 | 白天人像，Portra 气质，但画面上不写胶片名 |

---

#### 02 机身 · 这不是滤镜相机

| | 内容 |
|---|---|
| 画面 | 皮革机身 + 3:4 取景窗 + 滚轮 + 大红快门，计数窗 `17`。取景器是光学预览，**不加胶片色**。 |
| 光源 | 皮革暖 |
| 小标 | `VIEWFINDER  3:4` |
| 主句 简中 | `一部装在手机里的半格机。` |
| 主句 繁中 | `一部裝在手機裡的半格機。` |
| 主句 EN | `A half-frame camera. Not a filter pack.` |
| 主句 日 | `スマホの中の、ハーフカメラ。` |
| 主句 韩 | `폰 안의 하프프레임 카메라.` |
| 禁止 | 预览上叠滤镜、超广 0.5x、系统相机 UI |

---

#### 03 等待 · 核心上瘾点

品类差异化。VSCO / 普通胶片相机做不到，必须占住。

| | 内容 |
|---|---|
| 画面 | 暗盒里一排实心黑格，或未显影胶片条。旁白计数：`还剩 12 格`。 |
| 光源 | 全黑，只留齿孔和红点 |
| 小标 | `UNDEVELOPED` |
| 主句 简中 | `看不见，才会惦记。` |
| 主句 繁中 | `看不見，才會惦記。` |
| 主句 EN | `The wait is the point.` |
| 主句 日 | `見えないから、気になる。` |
| 主句 韩 | `안 보이니까 더 생각난다.` |

---

#### 04 装卷 · 选择即命运（有安全包装再上）

| | 内容 |
|---|---|
| 画面 | 自有色块胶卷盒陈列（彩色 / 反转 / 电影 / 黑白），手正在推进一支。 |
| 光源 | 胶卷盒色块 |
| 小标 | `LOAD  ·  LOCKED` |
| 主句 简中 | `选一卷，带着它出门。` |
| 主句 繁中 | `選一捲，帶著它出門。` |
| 主句 EN | `Pick a roll. Take it with you.` |
| 主句 日 | `フィルムを選んで、出かけよう。` |
| 主句 韩 | `롤을 고르고, 함께 나가요.` |
| 商标 | **禁止**柯达黄字标、富士绿标、CineStill 红条可识别 Logo。用自有包装 + 通用名：Color 400 / Slide 100 / Vision 250 / Acros。App 内配方名可保留，商店物料单独出「安全包装」版。 |

---

#### 05 暗房 · 仪式

| | 内容 |
|---|---|
| 画面 | 安全灯下的显影罐 / 药液 / 负片抽出。可露 Dynamic Island「显影中」。 |
| 光源 | 安全灯红 |
| 小标 | `DARKROOM  38°C` |
| 主句 简中 | `拍满一卷，送入暗房。` |
| 主句 繁中 | `拍滿一捲，送入暗房。` |
| 主句 EN | `Finish the roll. Into the darkroom.` |
| 主句 日 | `撮り切ってから、現像。` |
| 主句 韩 | `다 찍어야 현상한다.` |

---

#### 06 相册 · 对页生活

| | 内容 |
|---|---|
| 画面 | 胶片条横滑，两格一组对页；导出预览 3:2。至少 3 组真实场景：白天人像、夜色钨灯、黑白街道。 |
| 光源 | 相纸亮起 |
| 小标 | `CONTACT SHEET` |
| 主句 简中 | `相邻两格，一张对页。` |
| 主句 繁中 | `相鄰兩格，一張對頁。` |
| 主句 EN | `Two frames. One spread.` |
| 主句 日 | `隣り合うコマが、一枚の対頁。` |
| 主句 韩 | `맞붙은 두 컷, 한 장의 스프레드.` |

---

#### 07 可选 · 手感

给极客和胶片用户。大众看到 06 就会下。

- 画面：滚轮特写 + 快门键行程
- 小标：`WINDER`
- 主句：`转动过片轮，再按快门。`
- EN：`Advance. Then press the shutter.`

#### 08 可选 · 会员（弱化）

不要价格表。不要污染前 3 张。

- 主句：`免费开始。更多卷，更长的日常。`
- EN：`Start free. More rolls, more everyday stories.`

### 3.4 不要做的截图

- 四宫格功能图标（颗粒 / 漏光 / 50+ 胶片 / 无广告）
- 「AI 胶片」「一键出片」「100+ 滤镜」
- 竞品名、富士 / 柯达 / Olympus 官方商标或机身照片
- 美人头 + 星星评分
- 浅色渐变底 + 悬浮 iPhone 样机
- 预览画面已加胶片色（和产品逻辑相反）

---

## 4. App Preview 视频

### 4.1 规格

- 15–25 秒，首发做 **20 秒**
- 和 6.7" 截图同尺寸，竖屏
- 无旁白，只有机械声（后盖、棘轮、快门、水声）
- 字幕用截图同款宋体、相纸米
- 前 8 秒决定播不播完
- 结尾定格 Icon + 名字，对得上搜索结果
- 禁止 BGM 大合唱、禁止人声「你还在用普通相机吗」

### 4.2 分镜（20 秒）

| 秒 | 画面 | 声音 | 字幕 |
|---|---|---|---|
| 0–2 | 黑场，红快门点亮，切 Icon 中缝 | 后盖卡扣 | `HALF CAM` |
| 2–6 | 手指拨滚轮，计数 00→01，快门帘黑一帧 | 棘轮 + 快门 | `过片，再按快门。` |
| 6–10 | 生活碎片入镜，立刻切回黑格 | 快门，无预览 | `拍完，不能看。` |
| 10–16 | 暗房压缩：进罐、药液、负片、揭一对 | 水声 → 长 haptic 可省略画面化 | `拍满一卷，送入暗房。` |
| 16–19 | 对页亮起，相册齿孔滑过 | 取出胶片 | `相邻两格，一张对页。` |
| 19–20 | 回到机身黑，Icon | 静 | `HALF CAM` |

### 4.3 多语言字幕

| 秒 | 简中 | 繁中 | EN | 日 | 韩 |
|---|---|---|---|---|---|
| 0–2 | HALF CAM | HALF CAM | HALF CAM | HALF CAM | HALF CAM |
| 2–6 | 过片，再按快门。 | 過片，再按快門。 | Advance. Then shoot. | 巻き上げてから、撮る。 | 감고 나서, 촬영. |
| 6–10 | 拍完，不能看。 | 拍完，不能看。 | No preview. | 撮っても、見えない。 | 찍어도 안 보인다. |
| 10–16 | 拍满一卷，送入暗房。 | 拍滿一捲，送入暗房。 | Finish the roll. Into the darkroom. | 撮り切ってから、暗室へ。 | 한 롤을 다 찍고, 암실로. |
| 16–19 | 相邻两格，一张对页。 | 相鄰兩格，一張對頁。 | Two frames. One spread. | 隣り合うコマが、対頁。 | 두 컷, 한 스프레드. |

出三条视频：简中、英文、日文。韩文可先烧英文字幕。画面轨道共用。

---

## 5. 文案（可直接贴进 Connect）

字符限制：Name / Subtitle 各 30；Promotional Text 170；Description / What's New 4000；Keywords 100。  
下列中文按字计数（含标点）。

### 5.1 Name

| 语言 | 文案 | 字数 | 备注 |
|---|---|---|---|
| 简中 | `HALF CAM 半格胶片` | 13 | 锁定 |
| 繁中 | `HALF CAM 半格膠片` | 13 | 锁定 |
| English | `HALF CAM` | 8 | 英文不硬塞 half-frame，放副标题 |
| 日本語 | `HALF CAM 半格カメラ` | 14 | 「半格」日文胶片圈也认 |
| 한국어 | `HALF CAM 하프프레임` | 14 | |

不要写成竞品名、「半格胶片相机专业版」「HALF CAM - Film」。

### 5.2 Subtitle

**首发（功能向，吃搜索）**

| 语言 | 文案 | 字数 |
|---|---|---|
| 简中 | `拍满再显影的半格胶片机` | 11 |
| 繁中 | `拍滿再顯影的半格膠片機` | 11 |
| English | `A half-frame film camera` | 24 |
| 日本語 | `ハーフフレームのフィルムカメラ` | 15 |
| 한국어 | `하프프레임 필름 카메라` | 12 |

**品牌定型后（铭牌向，随可编辑版本提交审核）**

| 语言 | 文案 | 字数 |
|---|---|---|
| 简中 | `装卷。快门。等待。揭晓。` | 12 |
| 繁中 | `裝捲。快門。等待。揭曉。` | 12 |
| English | `Shoot. Wind. Wait. Develop.` | 27 |
| 日本語 | `巻いて、撮って、待つ。` | 11 |
| 한국어 | `감고, 찍고, 기다린다.` | 13 |

### 5.3 Promotional Text（不审可改，打季节用）

**常驻 · 简中**

```
装一卷，慢慢拍。把日常留在两格之间。
拍满一卷，再见照片。
```

**常驻 · 繁中**

```
裝一捲，慢慢拍。把日常留在兩格之間。
拍滿一捲，再見照片。
```

**常驻 · English**

```
Load a roll. Take your time.
Two frames, one little story. Leave the reveal to the darkroom.
```

**常驻 · 日本語**

```
フィルムを入れて、ゆっくり撮る。
隣り合う2コマに日々を残して、仕上がりは暗室で。
```

**常驻 · 한국어**

```
롤을 넣고 천천히 찍어보세요.
나란한 두 컷에 일상을 담고, 암실에서 사진을 만나보세요.
```

**活动版示例（简中）**

```
周末卷：免费用户本周可多装一卷。拍满再洗，对页才好看。
```

### 5.4 Description

前 3 行出现在「展开」之前，必须独立能转化。  
订阅声明按 Apple 要求留在末段。价格以 Connect 实际显示为准，描述里写「年卡 / 买断」，不写死金额。

#### 简体中文

```
拍满一卷，再见照片。

HALF CAM 是装在 iPhone 里的半格胶片机。
装卷、过片、拍摄，把揭晓留给暗房。

—— 规矩 ——
• 装入胶卷，转动过片轮，再按下快门
• 拍下的照片在显影前不提供预览
• 装卷时选定胶片，显影后不再更换
• 相邻两格，合为一张对页

—— 机身 ——
3:4 半格取景。皮革质感机身、过片滚轮与计数窗。
取景预览默认不叠加胶片色彩，专心看眼前。

—— 暗房 ——
拍满、倒片、送入暗房。从负片到成片，留一点等待，也留一点期待。
加急券可跳过一卷的等待，图像处理仍需片刻。
关闭 App 后，胶卷仍保存在本机。

—— 胶片 ——
彩色、反转片、电影、黑白。
人像柔、日常暖、夜色钨灯、细腻黑白。
装卷时选择胶片、颗粒和日期印，让这一卷有自己的样子。

—— 导出 ——
单格为 3:4，对页约 3:2，中间留黑缝。可选择保留片边。
主动导出或开启自动导出后，照片才会保存到系统相册。
删除 App 会删除其中的全部胶片，请先导出想保留的照片。

免费：每月 3 卷，每卷最多 12 格，每月赠 1 张加急券。
年卡：每月 9 卷，每卷最多 36 格，每月赠 3 张加急券。
买断：不限装卷，每卷最多 72 格，每月赠 6 张加急券。
所有档位均有等待时间。每月赠券于次月初失效；购买的加急券不过期，开启 iCloud 后可同步未用余量。
年卡按年自动续订，费用从 Apple 账户扣除。如不续订，请至少在当前周期结束前 24 小时于系统设置中取消。买断为一次性购买，无后续订阅扣费。

隐私政策与法律信息：
https://xuyue1998.github.io/halfcam/legal.html

HALF CAM 是独立 App，与任何胶片或相机品牌无关。
```

#### 繁體中文

```
拍滿一捲，再見照片。

HALF CAM 是裝在 iPhone 裡的半格膠片機。
裝捲、過片、拍攝，把揭曉留給暗房。

—— 規矩 ——
• 裝入膠捲，轉動過片輪，再按下快門
• 拍下的照片在顯影前不提供預覽
• 裝捲時選定膠片，顯影後不再更換
• 相鄰兩格，合為一張對頁

—— 機身 ——
3:4 半格取景。皮革質感機身、過片滾輪與計數窗。
取景預覽預設不疊加膠片色彩，專心看眼前。

—— 暗房 ——
拍滿、倒片、送入暗房。從負片到成片，留一點等待，也留一點期待。
加急券可跳過一捲的等待，影像處理仍需片刻。
關閉 App 後，膠捲仍儲存在本機。

—— 膠片 ——
彩色、反轉片、電影、黑白。
人像柔、日常暖、夜色鎢燈、細膩黑白。
裝捲時選擇膠片、顆粒和日期印，讓這一捲有自己的樣子。

—— 匯出 ——
單格為 3:4，對頁約 3:2，中間留黑縫。可選擇保留片邊。
主動匯出或開啟自動匯出後，照片才會儲存至系統相簿。
刪除 App 會刪除其中的全部膠片，請先匯出想保留的照片。

免費：每月 3 捲，每捲最多 12 格，每月贈 1 張加急券。
年卡：每月 9 捲，每捲最多 36 格，每月贈 3 張加急券。
買斷：不限裝捲，每捲最多 72 格，每月贈 6 張加急券。
所有方案均有等待時間。每月贈券於次月初失效；購買的加急券不過期，開啟 iCloud 後可同步未用餘量。
年卡按年自動續訂，費用從 Apple 帳號扣除。如不續訂，請至少在目前週期結束前 24 小時於系統設定中取消。買斷為一次性購買，無後續訂閱扣費。

隱私權政策與法律資訊：
https://xuyue1998.github.io/halfcam/legal.html

HALF CAM 是獨立 App，與任何膠片或相機品牌無關。
```

#### English

```
Finish the roll. Then see what you caught.

HALF CAM is a half-frame film camera in your iPhone.
Load, advance, and shoot. Leave the reveal to the darkroom.

THE RULES
• Load film, advance, then press the shutter
• No photo preview until developing
• Choose your film at loading; the look stays after developing
• Two adjacent frames become one spread

THE BODY
A 3:4 half-frame finder. A leather-textured body, a winder, and a frame counter.
The preview stays free of film color by default, so you can focus on the scene.

THE DARKROOM
Finish the roll, rewind, and send it to the darkroom. Negatives, prints, then the reveal.
One rush ticket skips the wait for one roll; processing still takes a moment.
Close the app and the roll stays on your device.

FILM
Color, slide, cine, black-and-white.
Soft portraits, warm dailies, tungsten nights, fine-grain mono.
Choose your film, grain, and date stamp at loading. Give each roll its own character.

EXPORT
Single frames are 3:4; spreads are approximately 3:2 with a black gutter. Film borders are optional.
Photos are saved to the Photos app only when you export or enable auto-export.
Deleting HALF CAM removes all film stored in the app. Export photos you want to keep first.

Free: 3 rolls per month, up to 12 frames each, and 1 monthly rush ticket.
Yearly: 9 rolls per month, up to 36 frames each, and 3 monthly rush tickets.
Lifetime: unlimited rolls, up to 72 frames each, and 6 monthly rush tickets.
All plans include a wait. Monthly tickets expire at the start of the next month. Purchased tickets do not expire; enable iCloud to sync their unused balance.
The yearly plan renews automatically and is billed to your Apple Account. Cancel in Settings at least 24 hours before the current period ends to avoid renewal. Lifetime is a one-time purchase with no recurring charge.

Privacy and legal:
https://xuyue1998.github.io/halfcam/legal.html

HALF CAM is independent. Not affiliated with any film or camera brand.
```

#### 日本語

```
写真は、現像してから。

HALF CAMは、iPhoneの中のハーフフレーム・フィルムカメラ。
フィルムを入れて、巻き上げて、撮る。仕上がりは暗室で。

ルール
• フィルムを装填し、巻き上げてからシャッターを押す
• 撮った写真は、現像するまでプレビューなし
• フィルムは装填時に選び、現像後は変更しない
• 隣り合う2コマを、1枚の写真に

ボディ
3:4のファインダー。レザー調のボディ、巻き上げダイヤル、カウンター。
プレビューには標準でフィルムの色を重ねず、目の前の風景に集中できます。

暗室
撮り切って、巻き戻して、暗室へ。ネガから写真になるまで、少しだけ待つ楽しみを。
お急ぎ券1枚でフィルム1本の待ち時間をスキップできます。写真の処理には別途少し時間がかかります。
アプリを閉じても、フィルムはこの端末に残ります。

フィルム
カラー、リバーサル、シネ、モノクロ。
ポートレート、日常、タングステンの夜、細かい粒子の白黒。
フィルム、粒子、日付写し込みを装填時に選んで、その1本らしい仕上がりに。

書き出し
1コマは3:4、2コマ組は約3:2。間には細い黒の境界。フィルム枠も付けられます。
書き出し時、または自動書き出しが有効な場合にのみ「写真」に保存します。
アプリを削除すると、アプリ内のフィルムもすべて失われます。残したい写真は先に書き出してください。

無料：毎月3本、1本最大12コマ。毎月お急ぎ券1枚。
年額：毎月9本、1本最大36コマ。毎月お急ぎ券3枚。
買い切り：本数無制限、1本最大72コマ。毎月お急ぎ券6枚。
すべてのプランに待ち時間があります。毎月の付与分は翌月初めに失効します。購入分に有効期限はなく、iCloudを有効にすると未使用の残数を同期できます。
年額プランは自動更新され、Apple Accountに請求されます。更新を停止するには、期間終了の24時間前までに設定から解約してください。買い切りは一度の支払いで、継続課金はありません。

プライバシーと法的情報：
https://xuyue1998.github.io/halfcam/legal.html

HALF CAM は独立したアプリです。特定のフィルム／カメラブランドとは無関係です。
```

#### 한국어

```
한 롤을 다 찍고, 사진을 만나요.

HALF CAM은 iPhone 속 하프프레임 필름 카메라입니다.
롤을 넣고, 감고, 찍어보세요. 사진은 암실에서 만나보세요.

규칙
• 필름을 넣고 감은 뒤 셔터를 누릅니다
• 촬영한 사진은 현상 전까지 미리 볼 수 없습니다
• 장전할 때 고른 필름은 현상 후 바꾸지 않습니다
• 나란한 두 컷이 한 장의 사진이 됩니다

바디
3:4 하프프레임 파인더. 가죽 질감의 바디, 와인더, 프레임 카운터.
기본 미리보기에는 필름 색을 입히지 않아 눈앞의 풍경에 집중할 수 있습니다.

암실
다 찍고 되감아 암실로 보냅니다. 네거티브에서 사진이 되기까지, 기다리는 즐거움도 남겨보세요.
빠른 현상권 1장으로 한 롤의 대기 시간을 건너뜁니다. 사진 처리에는 별도의 시간이 조금 필요합니다.
앱을 닫아도 필름은 이 기기에 남습니다.

필름
컬러, 슬라이드, 시네, 흑백.
부드러운 인물, 따뜻한 일상, 텅스텐 밤, 고운 입자 흑백.
장전할 때 필름, 입자, 날짜 인쇄를 골라 한 롤만의 느낌을 만들어보세요.

내보내기
단독 컷은 3:4, 두 컷 사진은 약 3:2이며 가운데 얇은 검은 틈이 있습니다. 필름 테두리도 선택할 수 있습니다.
직접 내보내거나 자동 내보내기를 켠 경우에만 사진 앱에 저장합니다.
앱을 삭제하면 앱에 보관된 모든 필름도 삭제됩니다. 간직할 사진은 먼저 내보내 주세요.

무료: 매월 3롤, 롤당 최대 12컷. 매월 빠른 현상권 1장.
연간: 매월 9롤, 롤당 최대 36컷. 매월 빠른 현상권 3장.
평생권: 롤 수 무제한, 롤당 최대 72컷. 매월 빠른 현상권 6장.
모든 요금제에 대기 시간이 있습니다. 월별 증정권은 다음 달 초에 만료됩니다. 구매한 티켓은 만료되지 않으며, iCloud를 켜면 미사용 잔여 수량을 동기화할 수 있습니다.
연간 요금제는 자동 갱신되며 Apple 계정으로 청구됩니다. 갱신을 막으려면 현재 이용 기간이 끝나기 최소 24시간 전에 설정에서 취소해 주세요. 평생권은 한 번만 결제하며 정기 요금이 없습니다.

개인정보 및 법적 정보:
https://xuyue1998.github.io/halfcam/legal.html

HALF CAM은 독립 앱이며 특정 필름 또는 카메라 브랜드와 무관합니다.
```

### 5.5 Keywords（100 字符，逗号分隔，Name 里已有的词不要重复）

Apple 会索引 Name 和 Subtitle，关键词里再写是浪费。不要空格（省字符）。不要竞品名、不要富士/柯达。

**简中**（约 48）

```
胶片,胶卷,暗房,复古,相机,拍照,对页,人像,街拍,黑白,胶片相机,film,风景,夜景
```

**繁中**

```
膠片,膠卷,暗房,復古,相機,拍照,對頁,人像,街拍,黑白,膠片相機,film,風景,夜景
```

**English**

```
film,half-frame,camera,analog,darkroom,grain,roll,vintage,35mm,diptych,bw,street
```

**日本語**

```
フィルム,カメラ,半格,ハーフ,現像,暗室,アナログ,35mm,モノクロ,写真
```

**한국어**

```
필름,카메라,하프,현상,암실,아날로그,35mm,흑백,사진,빈티지
```

### 5.6 What's New

**首发 · 简中**

```
第一卷。

半格取景，转动过片轮，再按快门。
拍满送入暗房，相邻两格组成对页。
装一卷，慢慢拍。
```

**首发 · 繁中**

```
第一捲。

半格取景，轉動過片輪，再按快門。
拍滿送入暗房，相鄰兩格組成對頁。
裝一捲，慢慢拍。
```

**首发 · English**

```
The first roll.

Half-frame finder. Advance, then press the shutter.
Finish the roll, head to the darkroom, and discover two-frame spreads.
Load a roll. Take your time.
```

**首发 · 日本語**

```
最初の 1 本。

ハーフのファインダー。巻き上げてから、シャッターを。
撮り切ったら暗室へ。隣り合う2コマを1枚に。
フィルムを入れて、ゆっくり撮ろう。
```

**首发 · 한국어**

```
첫 번째 롤.

하프프레임 파인더. 감고 나서 셔터를 눌러보세요.
한 롤을 다 찍고 암실로. 나란한 두 컷이 한 장의 사진이 됩니다.
롤을 넣고 천천히 찍어보세요.
```

后续更新保持口吻，例如：

```
新卷：钨灯夜色。
颗粒更像银盐，不像噪点。
```

---

## 6. Connect 元数据

| 字段 | 值 |
|---|---|
| 主类别 | Photo & Video |
| 次类别 | Lifestyle |
| 年龄 | 按当前年龄分级问卷结果确认，不预填 |
| 价格 | 免费 + IAP |
| IAP | `halfcam.yearly` 年卡 · `halfcam.unlock` 买断 · `halfcam.skip.3` 加急包 |
| 版权 | `© YYYY xuyue`（按实际上架年） |
| 隐私政策 | `https://xuyue1998.github.io/halfcam/privacy.html` |
| 支持 URL | 同上或 GitHub Pages 首页 |
| 营销 URL | 可空 |
| 设备 | 当前仅支持 iPhone；截图尺寸以提交时 Connect 要求为准 |
| 最低系统 | iOS 17 |
| 隐私营养标签 | 按当前实现核对“不收集数据”；权限访问不等于数据收集。仅本机处理照片，加急券通过 Apple iCloud 同步，不供开发者访问；不追踪。提交前核对后台实际选项 |
| 内容版权 | 截图样片为自摄或已授权；不使用品牌官方胶卷包装图 |

### 6.1 审核备注（Review Notes）

```
HALF CAM is a simulated half-frame film camera. Several behaviors are intentional, not bugs:

1. The shutter does not expose until the user winds the film advance wheel.
2. Captured frames have no preview until the roll is rewound and developed. Strict mode requires finishing the roll; turning it off permits early unloading and discards unused frames.
3. Development includes a wait; a rush ticket skips the wait, not actual image processing.
4. Camera permission is required to complete the demo.

No app account or developer-provided login is required. In-app purchases use Apple's review environment. The bundled StoreKit configuration is for local Xcode testing only.

First-launch demo: Open app → allow camera → load the two-frame trial roll → advance → shoot → advance → shoot → rewind → send for developing → wait for the countdown → collect from the darkbox → reveal → keep in the app album → export optional. Real processing time depends on the device.

Please do not expect an instant preview after each shot. That is the product.
```

### 6.2 订阅披露（描述里已含，Paywall 内也必须有）

Apple 对自动续订要求：标题、时长、价格、自动续费、取消方式、隐私/条款链接。  
价格不要写死在描述里，让系统 IAP 显示。描述用「年卡 / 买断」即可。

---

## 7. 商标与合规

商店物料（截图、视频、Name、描述、关键词）比 App 内 UI 更暴露，按最严标准：

| 可以 | 不可以 |
|---|---|
| 彩色、反转、电影、黑白 | 富士 / Fujifilm / 柯达 / Kodak Logo |
| Color 400、Slide 100、Vision 250、Acros 作通用气质 | Portra / Velvia / Superia / CineStill 写在截图大字上 |
| 「独立 App，与任何胶片或相机品牌无关」 | 「官方配方」「真实胶片扫描」 |
| 自有色块包装 | 可识别的第三方胶卷盒设计 |
| — | 竞品名、Olympus、PEN、相机品牌官方名 |

App 内 `FilmCatalog` 的配方名可以继续用，商店单独出一版「安全包装」资产。  
04 号截图没有安全包装就不上，宁可 5 张。

---

## 8. 本地化矩阵

| 字段 | 简中 | 繁中 | EN | 日 | 韩 | 首发 |
|---|---|---|---|---|---|---|
| Name / Subtitle | ● | ● | ● | ● | ● | 全做 |
| Promo / Description | ● | ● | ● | ● | ● | 简中+EN 也可先过审 |
| Keywords | ● | ● | ● | ● | ● | 全做（纯文本） |
| 截图字层 | ● | ● | ● | ● | 可先用 EN | 简中+EN 必出 |
| Preview 字幕 | ● | 可共用简中画面+繁中字 | ● | ● | 可烧 EN | 简中+EN 必出 |

日文市场胶片用户密度高，有余力把截图字层和 Preview 做成第三条。  
韩文可只做 Name/Subtitle/Description/Keywords，截图暂用英文。

---

## 9. 自定义产品页（上架后，不挡首发）

Connect 支持额外产品页，给搜索广告分意图：

| 页 | 截图组合 | 广告关键词 |
|---|---|---|
| 默认 | 01 02 03 05 06 | 半格、胶片相机、half frame |
| 人像 | 01（人像对页）04 06 | 人像、胶片人像 |
| 夜色 | 05 + 钨灯对页 + Island | 夜景、胶片 |
| 黑白 | 03 齿孔 + 黑白街道对页 | 黑白、film |

搜索广告不投「美颜」「滤镜相机」。

---

## 10. 制作清单

### 10.1 画面

- [ ] Icon 1024 精修一版（中缝、快门红）
- [ ] 对页样片 ≥ 8 组：人像、日常、夜、黑白，全部走 App 显影管线
- [ ] 机身 UI 真机截屏：取景、滚轮、计数窗、暗盒黑格、暗房、相册条
- [ ] 商店安全版胶卷包装（无第三方 Logo）
- [ ] 6.7" 截图：01 02 03 05 06（04 有包装再加）
- [ ] 简中 / 英文字层；日文有余力再做
- [ ] 20s Preview，简中 + 英文字幕
- [ ] iPad 13" 仅在可展示时补

### 10.2 Connect 文字

- [ ] Name / Subtitle / Promo / Description / Keywords / What's New
- [ ] 简中、繁中、English、日本語、한국어
- [ ] 订阅自动续费声明
- [ ] 独立 App 免责声明
- [ ] 隐私政策 URL
- [ ] 审核备注 + 无需 App 账号说明 + 两格体验卷演示路径

### 10.3 审核防雷

- [ ] 截图无竞品、无富士/柯达/Olympus 商标
- [ ] 不承诺「真实胶片扫描」「官方配方」
- [ ] 演示能走完：装卷 → 拍满短卷 → 显影 → 导出
- [ ] 说明：空快门、黑格、等待是设计不是崩溃
- [ ] 隐私营养标签、清单和政策与实际数据流一致；不把相机／照片权限误填为数据收集

---

## 11. 首发最小集 vs 完整集

**最小集（先过审、先上）**

1. 截图 01、02、03、05、06（简中 + 英文）
2. Name / Subtitle 五语言
3. Description 简中 + 英文（繁中/日/韩可随后补）
4. Keywords 五语言
5. 20s Preview，简中字幕（英文可烧同一条或后补）
6. 审核备注

**完整集（上架后两周内）**

- 04 装卷（安全包装）
- 07 手感
- 日文截图字层 + 日文 Preview
- 副标题从功能向换成铭牌向
- 自定义产品页 × 3
- 搜索广告只投「半格 / 胶片相机 / film camera / half frame」

---

## 12. 执行顺序

```
样片拍摄（真机走显影管线）
  → Icon 精修
  → 安全包装（决定 04 上不上）
  → 截图真 UI 录屏/截屏
  → Figma 字层（简中为母版，复制出 EN / 日 / 繁 / 韩）
  → Preview 剪 20s
  → 填 Connect 元数据 + 五语言文案
  → 审核备注 + 沙盒
  → 提交
  → 过审后：自定义产品页、搜索广告、副标题换铭牌
```

样片和 UI 截屏不要平行到最后才对上——商店页里的对页必须能在 App 里复现，否则用户会认为是假 LUT。

---

## 13. 与产品文档的关系

| 文档 | 管什么 |
|---|---|
| `PLAN.md` | 产品循环、胶片、商业化、工程 |
| `docs/APPSTORE.md`（本文件） | 商店页图文、ASO、审核物料 |
| `docs/legal.html` | 隐私 / 条款，Connect 必填链接 |
| App 内 `PaywallView` | 年卡/买断文案，须与描述披露一致 |

PLAN.md §10 P2 已写：截图按「一卷的故事」做，不要功能宫格。本文件是那一行的展开。
