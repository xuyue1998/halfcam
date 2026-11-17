# 崩溃风险加固

接续 [Build 12 启动崩溃修复](CRASH-BUILD12.md)，处理自查发现的五项风险。

## 修复范围

1. **设备配置锁失败**：初始化及退出手动对焦时，不再忽略
   `lockForConfiguration` 的失败。只有成功加锁后才设置参数，并用 `defer` 解锁；
   失败时保留设备默认值，不继续执行需要持锁的 setter。
2. **对页导出内存**：拼图和片边渲染固定 `scale = 1`、不透明、标准动态范围，
   不随屏幕倍率放大像素；一次合成使用独立 autorelease pool。
   原图单格直接导出路径保持不变。普通双格画布的 RGBA8 理论大小从
   3× 屏幕下约 132 MiB 降至约 15 MiB，不代表整个导出流程的实测峰值。
3. **相机控制状态线程归属**：曝光、对焦、闪光灯及待应用参数统一在
   `halfcam.session` 队列更新；外部不能再直接写入硬件控制字段。
   测光快照通过锁读取，UI 使用一次快照保存拍摄元数据。
   微距 UI 更新按主队列 FIFO 发布，不再跨线程读取 generation。
4. **动态光圈调用**：不用 `performSelector` 传递未知 ABI 的数值。
   Objective-C 桥检查参数数量、返回类型及 float/double/object 参数编码，
   使用 `NSInvocation` 按正确类型传值，拒绝未知签名、非有限值及越界值，
   并在 Objective-C 边界处理 getter/setter 异常。
   仅调用成功才更新 UI；这不等于保证所有设备支持动态光圈。
5. **旧交易迁移**：重复交易 ID 合并成一条固定额度记录，不使用遇重复键即崩的
   `Dictionary(uniqueKeysWithValues:)`，也不累加重复记录的券数。

后续 [发布前检查](PRE-RELEASE-CHECK.md) 将动态光圈实验限制为 Debug；
Release 不编译相关非公开 selector，保留公开的硬件光圈读数。

## 自动验证

```sh
python3 -m unittest discover -s scripts -p 'test_*.py' -v
```

- 共 26 项检查：包含源码所有权/锁使用/渲染倍率守卫及既有文案检查。
- 原生 macOS 测试编译并运行生产 `HCSafeInvocation.m`：
  验证 Float、Double、NSNumber、未知签名、异常 setter/getter、
  不支持的设备及 NaN/Infinity/越界值。
- Swift 测试执行生产旧数据迁移表达式，覆盖空数组、唯一 ID 和重复 ID。
- iOS Simulator / arm64 / Debug 和 iOS 真机目标 / Release 均编译通过。
  构建检查不安装应用，不签名、不上传，不代表真机回归已经完成。

## 发布前真机复测

- 冷启动、首次授权、从设置恢复相机权限、前后台切换。
- 连续切换 A/M、镜头、对焦、曝光和闪光灯并拍摄，检查元数据及预览。
- 连续导出 72 格胶卷，分别开启/关闭片边，记录内存峰值。
- 有动态光圈支持的硬件验证参数生效；无支持设备不应显示虚假成功。
- 旧数据迁移后检查加急券余额及恢复购买，不重复发券。
