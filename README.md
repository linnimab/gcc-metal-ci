# ios_handoff — iOS 端抖音相机特效（从源码重建）

Android 端已跑通（`gate-debug.apk`，EffectSDK 20.1.0，初始化 7 步全返回 0）。
这一份是 iOS 的对应实现，走 GitHub Actions 在 `macos-latest` 上编译——本机没有
Xcode / iPhoneOS.sdk / Mac，编译只能发生在 CI 上。

## 现在能做什么

```
.github/workflows/build-ios.yml   推送即编译，产出 .app 与未签名 .ipa
src/effect_sdk.h                  423 个 _bef_effect_* 的 C 声明（按真实符号名对齐）
src/effect_bridge.c/.h            7 步初始化 + 美颜/美型/滤镜/composer 的薄壳
src/resource_finder.h             iOS 侧资源查找器（对应 Android 的 FileResourceFinder）
src/CameraViewController.h/.m     AVCaptureSession 取帧 -> 引擎 -> 显示
src/main.m                        入口
src/Info.plist                    相机/麦克风权限
BIN/EffectSDKFramework            27.8 MB，arm64 dylib，cryptid=0（未加密，可直接链接）
ANALYSIS/                         符号表 3062 条、7 步序列说明、Mach-O 报告
scripts/sign_and_install.ps1      Windows 侧 zsign 签名 + 安装
```

## ⚠️ 硬约束：AwemeCore 是 984 MB 的必需依赖

从 `EffectSDKFramework` 的 LC_LOAD_DYLIB 读出来的依赖：

| 依赖 | 大小 | 状态 |
|---|---|---|
| `@rpath/AwemeCore.framework/AwemeCore` | **983.7 MB** | **不在本仓库** |
| `@rpath/TTFFmpeg.framework/TTFFmpeg` | 3.4 MB | 在 `F:\gcc_ios\ios_unpack\` |
| `@rpath/boringssl.framework/boringssl` | 1.2 MB | 在 `F:\gcc_ios\ios_unpack\` |
| `libc++ / libz / libobjc / libSystem` | — | 系统自带 |

`EffectSDKFramework` 的 install name 是 `@rpath/EffectSDKFramework.framework/EffectSDKFramework`，
自带的 LC_RPATH 是 `@executable_path/Frameworks`，所以三个 framework 都要放进 App 的
`Frameworks/` 目录。

**984 MB 装不进 GitHub 仓库**（单文件 100 MB 限制，且 CI 每次拉取也不现实）。
可选做法：

1. 用 Git LFS（单文件 2 GB 上限，但仓库会变成 GB 级）
2. 放外部存储（网盘 / S3），CI 用 `curl` 拉，workflow 里做完整性校验
3. 只提交 `EffectSDKFramework`，先让 CI 编译通过，AwemeCore 后补

现在 workflow 按 **方案 3** 写：缺依赖时明确报错而不是静默产出坏包。

## 编译

推送到 GitHub 后 Actions 自动跑，产物在 Artifacts 里下载 `GoodColorCam-ios-unsigned`。
或者本地有 Mac 时：

```bash
xcodebuild -project GoodColorCam.xcodeproj \
           -scheme GoodColorCam \
           -sdk iphoneos \
           -configuration Release \
           -derivedDataPath build \
           CODE_SIGNING_ALLOWED=NO \
           build
```

## 签名与安装（Windows 侧）

```powershell
.\scripts\sign_and_install.ps1 -Ipa .\build\GoodColorCam.ipa
```

脚本用 `zsign` 重签，再用 `libimobiledevice` 装到越狱/巨魔设备。

## 与 Android 端共享的东西

| 项目 | 说明 |
|---|---|
| 特效包 `bcce4ab7a2200676ca1295fe821704ed` | 双端同构，`docs/94-特效包契约-双端同构.md` 有完整契约 |
| 初始化顺序 | 7 步，见 `ANALYSIS/EFFECT_INIT_SEQUENCE.md` |
| 返回码语义 | `create_handle` 非 0 成功；`init_resource_finder` 必须给真实宽高和 root，否则后续全 -6 |

## 两条实测结论（照抄 Android 端，别踩）

1. **license 不是硬闸门**：`create_handle(false)` 直接返回有效句柄，不需要任何 license。
2. **特效目录必须是叶目录**：传含 `config.json` 的 `effect/<md5>/`；
   传容器目录 `effect/` 或相对路径都会让 SDK 段错误。

## 还缺什么

- `BIN/EffectSDKFramework` 没有官方 header，`effect_sdk.h` 的参数类型是按 Android 端
  实际调用推断的。首次 CI 编译如果报类型不匹配，以链接错误为准逐个修。
- 资源查找器的接法（SDK 侧的 finder 抽象）没有文档，`effect_bridge.c` 里先按
  `_bef_effect_init_with_resource_finder` 试，不行就退回 `_bef_effect_init`。
- 没有渲染目标输出。Android 端 `[GL6] 输出 FBO=1` 已经能拿到 FBO，
  iOS 侧还需要把处理结果回显到屏幕，这一步要接 GLKView 或 Metal。