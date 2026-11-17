# Build 12 相机启动崩溃

## 已同步的日志

- 来源：Xcode Organizer，TestFlight，1.0 (12)；已在本机符号化。
- Incident：`9C343863-4A24-435B-9E99-EA2D6A2D36E9`
- 时间：2026-11-16 01:38:24 +0800，启动后约 3 秒。
- 设备：iPhone 17 Pro（`iPhone18,1`），iOS 26.7。
- 异常：`EXC_CRASH (SIGABRT)`，线程 2。

关键堆栈（行号对应 Build 12，非修复后的源码）：

```text
Thread 2 / Last Exception Backtrace:
objc_exception_throw
-[AVCaptureSession startRunning]
closure #1 in CameraSession.requestAndRun()  CameraSession.swift:85

Thread 0:
-[AVCaptureSession commitConfiguration]
-[AVCaptureSession _addVideoPreviewLayer:exceptionReason:]
-[AVCaptureVideoPreviewLayer setSession:]
PreviewLayerView.makeUIView(context:)        ViewfinderView.swift:151
```

原始日志位于本机：

```text
~/Library/Developer/Xcode/Products/com.xuyue.HalfCam/Crashes/Points/
_pnh7n9ATmFn4dKYSxvcm.xccrashpoint/
```

## 原因与修复

后台 `halfcam.session` 队列启动 session 时，SwiftUI 主线程正在给预览层设置
`session`；这个 setter 会隐式修改 session 配置。两条线程的堆栈显示二者发生重叠。
这与 Build 6 的手动对焦 API 异常不是同一个问题。

- 将 capture session 设为私有，不再向视图暴露原始对象。
- 预览层绑定、解绑、连接方向配置，与启动、停止和镜头切换使用同一串行队列。
- 拍摄请求与 session 配置串行执行。
- UIView 的布局、显示属性仍在主线程更新。
- 视图拆卸时排队解绑；相机 owner 改变时使用新的视图 identity，
  避免同一预览层交给两条不同的 session 队列。
- 配置完成或切换镜头后恢复竖屏预览连接。

不通过捕获 `startRunning` 的 Objective-C 异常掩盖并发配置问题。

## 回归验证

源码所有权守卫（不等于真机竞态测试）：

```sh
python3 -m unittest discover -s scripts -p test_camera_session.py
```

已完成：

- 6 项相机源码所有权检查通过；连同已有检查，共 19 项 Python 测试通过。
- iOS Simulator / arm64 / Debug 编译通过。
- iOS 真机目标 / Release / 不签名编译通过（未安装、未上传）。
- 真机运行回归尚未完成。编译通过不能证明竞态已在受影响设备上消失。

真机发布前仍需验证：

1. 已授权相机时多次冷启动，尤其检查最初几秒的预览加载。
2. 首次授权、拒绝授权后从设置中重新授权。
3. 多次前后台切换，观察预览正常恢复、不闪退、不黑屏。
4. 切换镜头、A/M 模式和手动对焦后，预览方向及拍摄仍正常。
5. 在 iOS 26.x 真机（优先 iPhone 17 Pro）复测。
