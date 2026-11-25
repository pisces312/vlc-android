# AGENTS.md — vlc-android 项目开发约定

> 本文件供 AI agent / 协作者在开始改动前阅读。内容是本 fork 的**本地定制约定**，与上游 `videolan/vlc-android` 的官方做法有差异，改动前请先确认。

## 1. 项目概览

| 项目 | 值 |
|------|-----|
| 仓库 | `pisces312/vlc-android`（fork，上游 `videolan/vlc-android`） |
| 本地路径 | `D:\3rd-party-projects\vlc-android` |
| 当前版本 | 3.7.2（`build.gradle` 中 `versionName` / `versionCode = 3070200`） |
| applicationId | `org.videolan.vlc` |
| 构建方式 | **JVM Build** —— 不编译原生库，LibVLC / Medialibrary 从 Maven 取预编译包 |
| 目标 ABI | **仅 arm64-v8a**（本地定制，见 §4） |

## 2. 开发环境

| 组件 | 版本 / 路径 |
|------|-------------|
| OS | Windows 11（工作 shell 为 Git Bash） |
| JDK | 21.0.10，`JAVA_HOME=D:\dev\AndroidStudio\jbr` |
| Android SDK | `D:\dev\android_sdk`（platforms android-36、build-tools 36.0.0） |
| **Gradle** | `D:\dev\gradle-9.6.1\bin\gradle` |
| AGP | 9.4.1（最低要求 Gradle ≥ 9.6.0） |
| Kotlin | 2.2.10 |
| compileSdk / targetSdk | 36 |
| NDK | 不需要（JVM Build 不编译原生库） |

## 3. 关键约束（改动前必读）

1. **仓库不含 Gradle Wrapper**（上游已移除）。任何 Gradle 命令都必须显式调用：
   ```bash
   export MSYS_NO_PATHCONV=1
   /d/dev/gradle-9.6.1/bin/gradle <task> --no-daemon
   ```
   Git Bash 下 `export MSYS_NO_PATHCONV=1` 是**必需**的，否则含 `:` 的参数（如 `git show upstream/master:.gitignore`）会被误做路径转换而失败。

2. **首次 clone 后需手工创建两项**（两者都被 `.gitignore` 覆盖，不会入库）：
   - `local.properties`：`sdk.dir=D:\\dev\\android_sdk`
   - `libvlcjni/libvlc/` stub 模块：`build.gradle`（`com.android.library` + `namespace 'org.videolan.libvlc'` + `compileSdk 36`）与 `src/main/AndroidManifest.xml`

3. **`medialibrary/build.gradle` 必须保持 stub 版**。上游完整版依赖未 clone 的 NDK submodule（jni/libs、vlc3/src 等），Windows 下无法构建。同步上游时该文件的冲突一律**保留我们这侧（ours）**。

4. **Windows 不支持 `dev` 构建类型与完整原生编译**，只能做 JVM Build。

## 4. 仅构建 arm64-v8a（本地定制）

`application/app/build.gradle` 的 `splits.abi` 已从上游的四 ABI 收敛为单一 ABI：

```groovy
splits {
    abi {
        // ...
        enable = isReleaseBuild
        reset()
        // Local customization: only build arm64-v8a (upstream ships x86, x86_64, armeabi-v7a too)
        include "arm64-v8a"
    }
}
```

- Release 产出单个 APK：`VLC-Android-<version>-arm64-v8a.apk`
- 不要因为"上游有四个"就改回多 ABI；同步上游时此处的改动需保留（ours）。

## 5. 常用命令

```bash
# 配置自检（快，约 20s，改完构建脚本先跑这个）
/d/dev/gradle-9.6.1/bin/gradle projects --no-daemon

# Debug 构建（全 ABI，用于快速验证 UI 改动；本机实测约 2 分钟）
/d/dev/gradle-9.6.1/bin/gradle assembleDebug --no-daemon
# 产物 application/app/build/outputs/apk/debug/

# Release 构建（产出未签名 APK，仅 arm64-v8a；本机实测约 2-3 分钟）
/d/dev/gradle-9.6.1/bin/gradle assembleRelease --no-daemon
# 产物 application/app/build/outputs/apk/release/
```

## 6. Release 签名

| 项目 | 值 |
|------|-----|
| keystore | `D:\my-projects\my-backup\backup-settings\my-android-release.keystore` |
| alias | `pisces312` |
| 密码来源 | 环境变量（**禁止写入文档、命令行或代码**） |

用到的环境变量（已在系统级配置）：`KEY_STORE` / `KEY_STORE_LOCATION`、`KEY_ALIAS`、`KEY_STORE_PASSWORD`、`KEY_PASSWORD`。

> agent / 沙箱 shell **不会继承**上述用户环境变量：直接读 `$env:KEY_STORE_PASSWORD` 为空，**这不代表未配置**。正确做法是用 PowerShell 从 `HKCU:\Environment` 逐项读取并赋给本次进程，再调用 `apksigner`，且**不要打印任何密码值**：
>
> ```powershell
> $env:KEY_STORE = (Get-ItemProperty 'HKCU:\Environment' -Name KEY_STORE).KEY_STORE
> $env:KEY_ALIAS = (Get-ItemProperty 'HKCU:\Environment' -Name KEY_ALIAS).KEY_ALIAS
> $env:KEY_STORE_PASSWORD = (Get-ItemProperty 'HKCU:\Environment' -Name KEY_STORE_PASSWORD).KEY_STORE_PASSWORD
> $env:KEY_PASSWORD = (Get-ItemProperty 'HKCU:\Environment' -Name KEY_PASSWORD).KEY_PASSWORD
> ```
>
> 之后 `apksigner sign --ks-pass env:KEY_STORE_PASSWORD --key-pass env:KEY_PASSWORD ...` 即可复用 Git Bash 下的签名命令。

```bash
export MSYS_NO_PATHCONV=1
cd application/app/build/outputs/apk/release
mkdir -p signed
for abi in arm64-v8a; do
  "/d/dev/android_sdk/build-tools/36.0.0/apksigner.bat" sign \
    --ks "${KEY_STORE}" --ks-key-alias "${KEY_ALIAS}" \
    --ks-pass env:KEY_STORE_PASSWORD --key-pass env:KEY_PASSWORD \
    --out "signed\\VLC-Android-3.7.2-${abi}.apk" "VLC-Android-3.7.2-${abi}.apk"
done
```

验证（预期 `Verifies` + v1/v2/v3 = true + `CN=pisces312, O=pisces312`）：

```bash
"/d/dev/android_sdk/build-tools/36.0.0/apksigner.bat" verify -v --print-certs signed/*.apk
```

`apksigner verify` 输出的 `META-INF/... not protected by signature` WARNING 属正常现象（AGP 元数据与 netty native-image 配置），官方构建同样存在，可忽略。

> 已弃用：早期使用的 `vlc-android-release.keystore`（alias `vlc-release`），其明文密码已从 `BUILD-GUIDE.md` 中移除。

## 7. 上游同步约定

- remote：`origin` = `pisces312/vlc-android`，`upstream` = `videolan/vlc-android`（**两者都用 SSH**）。
- 同步前先建备份分支（如 `backup-fork-YYYYMMDD`），再 `git fetch upstream master` + `git merge upstream/master`。
- 已知必现冲突及处理原则：
  - `.gitignore` → **取上游**（上游的 `*.keystore` 规则更通用）
  - `medialibrary/build.gradle` → **保留本地 stub（ours）**
  - `application/app/build.gradle` → 保留 `splits.abi.include "arm64-v8a"`
  - `AGENTS.md` / `BUILD-GUIDE.md` → 保留本地文档
  - 下表所列文件 → 保留本地功能定制，逐块人工融合

### 本地功能定制（上游同步时必须保留）

| 功能 | 关键文件 | 约定 |
|------|----------|------|
| 亮度手势起点 | `video/VideoTouchDelegate.kt` 的 `initBrightnessTouch()` | 始终以系统当前 `Settings.System.SCREEN_BRIGHTNESS / 255f` 为起点并 `coerceIn(0.01f, 1f)`；不要恢复上游的硬编码 `0.5f` 或复用窗口旧值逻辑。当前 compileSdk 下 `Settings.System.SCREEN_BRIGHTNESS_FLOAT` 不可解析，勿改用。 |
| 视频旋转按钮 | `gui/view/RotatableVideoLayout.kt`、`res/layout/player.xml`（`video_rotation_layout` 包裹 `video_layout`）、`video/VideoPlayerActivity.kt`（`rotateVideo` / `resetVideoRotation` / `applyVideoRotation` / `switchVideoOutput` / `takeRotatedScreenshot`，以及 `startPlayback()` 里 `attachViews()` 的第 4 个参数）、`video/VideoPlayerOverlayDelegate.kt`、`res/layout/player_hud.xml`、`drawable/ic_player_video_rotation.xml`、`values*/strings.xml` | 实现是 **View 层旋转**，不要再改回 libVLC 选项：libVLC 3 的 video output 以 media player 为父对象，per-media 的 `:video-filter=transform` 永远读不到（libvlc 3 也没有设置该变量的 API）；且默认硬解走 MediaCodec 直接渲染，transform 滤镜处理不了 opaque buffer。点击 90° 步进、长按复位；角度只对当前这次播放有效（Activity 字段 + instance state，切到下一个视频时复位），不写入 SharedPreferences。`SurfaceView` 不响应 View 变换，所以旋转期间 libVLC 输出切到 `TextureView`（`attachViews(..., useTextureView = true)`），复位后切回。已知限制：旋转时字幕随画面一起转、TextureView 路径无 HDR 直通。上游若改动 `startPlayback()` 的 `attachViews(...)` 或 `takeScreenshot()`，需保留 `usingTextureView` 分支。 |

## 8. 用户工作习惯

- GitHub 一律 **SSH**（`git@github.com:...`），不用 HTTPS clone。
- 第三方源码统一放 `D:/3rd-party-projects/<repo>`，便携版/二进制放 `D:/dev/<工具名>`，两者不混放。
- 密钥、密码不落盘、不进命令行历史，统一走环境变量。
- 代码改动后本地 commit；**push 到远端前必须先向用户确认**。
- 构建环境或流程发生变化时，同步更新 `BUILD-GUIDE.md` 与本文件。

## 9. Gradle 分发包下载

`services.gradle.org` 会 302 到 `github.com`，本机 HTTPS 直连 GitHub 不通，**改用镜像 + aria2**：

```bash
/d/dev/aria2c -x 8 -s 8 -k 1M -c -o gradle-9.6.1-bin.zip \
  "https://mirrors.cloud.tencent.com/gradle/gradle-9.6.1-bin.zip"
unzip -q gradle-9.6.1-bin.zip -d /d/dev/   # → /d/dev/gradle-9.6.1
```

| 镜像 | 可用性 |
|------|--------|
| `https://mirrors.cloud.tencent.com/gradle/` | 可用（本机 9.6.0 / 9.6.1 均由此下载） |
| `https://mirrors.aliyun.com/macports/distfiles/gradle/` | 可用（备选） |
| `https://mirrors.aliyun.com/gradle/` | 404，不可用 |
| 清华 `mirrors.tuna.tsinghua.edu.cn/gradle/` | 404，不可用 |

## 10. 隐私基线（改动依赖时需复查）

已审计版本 3.7.2，结论为**低风险**：无广告/追踪/遥测 SDK，无 Google Play Services（唯一的 Google 依赖是 `com.google.android.material`），无崩溃上报，不获取设备标识符。

新增依赖时必须确认不引入追踪类 SDK（gms / firebase / facebook / appsflyer / umeng / adjust / crashlytics / amplitude / flurry 等），并保持以下现状：

- 不引入 `com.google.android.gms` 系列依赖；源码中现有的 gms 字符串仅为 Intent action 与 Android Auto metadata 常量，无 SDK、无网络行为
- `donations` 模块不进 app 依赖（避免引入 `com.android.vending.BILLING`）
- `moviepedia` 的 `MOVIEPEDIA_API_URL` 默认回退为 `https://localhost/`，本地构建不配置 `moviepedia_api_url`，元数据刮削不会外发

## 11. 相关文档

- `BUILD-GUIDE.md` —— 详细的构建步骤、签名命令、构建类型说明与隐私审计结论
- `D:\workspace\vlc-android-privacy-audit_3.7.2_2026-10-19.md` —— 3.7.2 的 Google 服务与隐私风险审计（权限清单、dex 扫描、网络访问点）
