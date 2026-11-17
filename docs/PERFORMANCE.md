# 发布前性能专项

## 本轮优化

| 路径 | 调整 |
|---|---|
| 冷启动索引 | 顺序读取并校验 `store.json`，正常时不读取、不解码备份，也不为比较再次读取主文件。损坏/缺失时仍会回退备份。 |
| 启动资源 | 仅打开相机不再无条件创建光谱引擎；装卷时仍预热胶片/相纸，显影需要时初始化。 |
| 相册解码 | ImageIO/负片转换使用最多 **2 个**同步 worker；等候不占用 Swift 协作线程。不限制显影引擎的输出质量。 |
| 同图请求 | 提高请求优先级时继续等待共享任务，不取消并重新解码。不同等待者独立取消，最后一个离开才取消任务。 |
| 负片预览 | 复用共享的 360px 正片预览，不再次独立读取原图；获取预览后才占用转换 worker，避免嵌套队列死锁。 |
| 取消与清理 | 缓存清理先在锁内移除记录，锁外取消任务，避免同步 cancellation handler 再入同一把锁。 |
| 内存警告 | 释放三个可再生图像缓存及 CIContext 缓存，不取消当前可见图像请求；成本按 CGImage 实际 row stride 计算。 |
| 样片 | 接入相同的限流、共享和缓存路径；不尝试向只读 App bundle 写缩略图。 |
| 显影恢复 | 既有文件校验在后台完成，用已验证 UUID 集合避免同一张成片在主线程反复检查。 |
| 相机 | RAW/质量设置未变化时不重复 setter 和 capture prewarm；相同微距/变焦 UI 状态不再每次对焦 KVO 都投递到主线程。 |
| 路径查询 | 缓存成功创建的 Application Support 目录；失败后保留重试能力。 |
| 对页导出 | 通过 ImageIO URL source 读取 EXIF，不为元数据额外创建整张来源 JPEG 的 Data 副本。 |
| 观测 | 加入 `OSSignposter` 区间，覆盖索引、相机启动、解码、负片转换、显影、渲染、落盘和导出合成。只记录固定名称，不记录照片、路径、交易或用户标识。 |

### 保持不变

- 显影最长边 **4032**，浮点输入/光谱过程不降精度，full 输出不替换为缩略图。
- 对页合成基准高 **1600**，JPEG 质量 **0.92**；无片边单格仍直接导出原数据。
- 原图和库索引仍原子写入，不为减少耗时跳过安全落盘。
- 不修改显影等待、付费规则或胶卷数据格式。

## 已测量的数据

测试机器：Apple Silicon / arm64，macOS 27.2，Swift `-O`；
**不是 iPhone 冷启动、FPS、GPU 显影吞吐或实际 App 整体内存数据**。

各变体独立进程，3 次热身，索引 30 次/元数据 60 次；
使用合成数据和温热 OS 文件缓存。峰值为单个微基准进程的 RSS 高水位，
包含运行库等开销；不是一次操作的净内存分配。

| 场景 | 优化前 p50 | 优化后 p50 | 优化前 p95 | 优化后 p95 |
|---|---:|---:|---:|---:|
| 24 卷 / 1,728 格索引 | 12.55 ms | 6.23 ms | 13.74 ms | 6.36 ms |
| 240 卷 / 17,280 格索引 | 126.21 ms | 61.89 ms | 127.29 ms | 69.44 ms |
| 14.9 MB JPEG 元数据 | 0.737 ms | 0.074 ms | 0.831 ms | 0.087 ms |

- 正常索引读取由 **3 次文件读取、2 次解码**减少至 **1 次读取、1 次解码**。
- 240 卷索引微基准峰值 RSS：约 **42.2 → 31.3 MiB**。
- 元数据微基准峰值 RSS：约 **25.3 → 11.0 MiB**。
- 基准从实际 `Models.swift`、`StoreReader.swift`、`FilmRenderer.swift` 编译；
  旧算法在脚本中保留。原始结果、样本量、机器信息和源码哈希见
  [`PERFORMANCE-RESULTS.json`](PERFORMANCE-RESULTS.json)。
- 数值受磁盘缓存、系统负载影响；不能按这些百分比推断整个 App 的提升。

复测：

```sh
python3 scripts/benchmark_performance.py --iterations 30 \
  --output /path/to/performance-results.json
python3 -m unittest discover -s scripts -p 'test_*.py'
python3 scripts/check_copy.py
```

## 验证结果

- 共 **63 项**检查通过。
- 原生测试覆盖：限流上限、取消前/取消中完成、共享任务不重复、
  多线程等待者只结束一次、purge 的同步取消再入、
  正常索引只读一次及损坏回退、重复相机配置、微距状态去重。
- 元数据新旧路径的测试对解码像素和元数据做一致性比较，均通过。
- iOS Simulator / arm64 / Debug 构建、iOS / Release 不签名构建、
  Xcode Analyze 均通过，无源码警告；只有 AppIntents 元数据跳过提示。

## 下一阶段：真机性能验收

在 Xcode 的 **Release/Profile** 配置使用 Instruments：
**Time Profiler + Points of Interest + Allocations/VM Tracker**。
筛选 subsystem `com.xuyue.HalfCam`、category `Performance`。

| 操作 | 应关注的区间/指标 |
|---|---|
| 冷启动、首次权限、退后台再回前台 | `LibraryLoad`、`CameraStart`，首帧时间及主线程停顿 |
| 72 格相册快速滚动、反复打开样片 | `PreviewLoad`、`DisplayLoad`、`ImageDecode`，解码并发、卡顿和缓存回收 |
| 连续显影 2 格、12 格、72 格 | `SpectralDevelop`、`LinearIngest`、`SpectralSolve`、`RenderFull`、`RenderThumbnail`，单帧时间/峰值 footprint |
| 开/关片边整卷导出 | `ComposeExport`，Photos 写入等待、批次内存和整体耗时 |
| 快速切换镜头、A/M、RAW、连续拍照 | `PhotoWrite`，capture-ready 延迟、是否发生无谓重配 |
| 长时间使用 | `LibraryPersist`、磁盘写入、温控、掉帧、内存是否持续上升 |

区间包含排队时间的 `PreviewLoad` 和 `SpectralDevelop` 应结合内部区间看，
不要把等待 worker/引擎锁的时间直接当成解码/GPU 执行时间。

仍需真机数据决定是否进一步改动光谱引擎的缓冲池/磁盘后备、浮点输入复制，
以及大库持久化。此前的 **17.18 GB 写入资源告警**不能仅凭本轮 CPU/I/O
微基准宣称已解决；必须在同类设备及长时间显影场景下重新测量。

本轮未安装替换真机 App、未改构建号、未上传或发布。
