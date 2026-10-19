# VLC-Android 构建文档

## 项目信息
- **仓库**: videolan/vlc-android (已 fork 到 pisces312/vlc-android)
- **本地路径**: `D:\3rd-party-projects\vlc-android`
- **版本**: 3.7.2
- **许可证**: GNU GPL v2
- **构建方式**: JVM Build (从 Maven 下载预编译 LibVLC，不编译原生库)

## 构建环境

| 组件 | 版本 |
|------|------|
| Gradle | 9.6.1 (本地安装 `D:\dev\gradle-9.6.1\bin\gradle`) |
| AGP | 9.4.1 |
| Kotlin | 2.2.10 |
| compileSdk / targetSdk | 36 |
| JDK | 21 |
| Android SDK | `D:\dev\android_sdk` |

## 构建前准备

### 1. 创建 local.properties (指向 Android SDK)

**路径**: `D:\3rd-party-projects\vlc-android\local.properties`

```properties
sdk.dir=D:\\dev\\android_sdk
```

> 注意: 本仓库**不含 gradle wrapper**（上游已移除），必须显式调用本地 Gradle:
> `D:\dev\gradle-9.6.1\bin\gradle`。AGP 9.4.1 的最低 Gradle 要求为 9.6.0。
>
> **只构建 arm64-v8a**: `application/app/build.gradle` 的 `splits.abi.include` 已由上游的四 ABI 收敛为 `include "arm64-v8a"`，
> Release 只产出单个 APK。同步上游时该处改动需保留（ours）。
> Git Bash 下需 `export MSYS_NO_PATHCONV=1`，避免 `a:b` 形式的参数被误做路径转换。

### 2. 创建 stub 占位模块 (libvlcjni/libvlc 和 medialibrary)

这两个模块在 `settings.gradle` 中被引用，但源码未 clone。Debug/Release 模式从 Maven 下载预编译库，但仍需占位目录。

**libvlcjni/libvlc/build.gradle**:
```gradle
// Stub module for JVM builds - LibVLC is fetched from Maven in debug/release modes
plugins {
    id 'com.android.library'
}
android {
    namespace 'org.videolan.libvlc'
    compileSdk 36
}
```

**libvlcjni/libvlc/src/main/AndroidManifest.xml**:
```xml
<manifest package="org.videolan.libvlc"/>
```

**medialibrary/build.gradle**:
```gradle
// Stub module for JVM builds - Medialibrary is fetched from Maven in debug/release modes
plugins {
    id 'com.android.library'
}
android {
    namespace 'org.videolan.medialibrary'
    compileSdk 36
}
```

**medialibrary/src/main/AndroidManifest.xml**:
```xml
<manifest package="org.videolan.medialibrary"/>
```

## 构建命令

### Debug 构建

```powershell
Set-Location D:\3rd-party-projects\vlc-android
D:\dev\gradle-9.6.1\bin\gradle assembleDebug --no-daemon
```

**构建结果**:
- 状态: BUILD SUCCESSFUL
- 耗时: 5分48秒
- 任务数: 418
- 输出 APK: `D:\nili\3rd_party_projects\vlc-android\application\app\build\outputs\apk\debug\VLC-Android-3.7.1-Beta-2-debug-all.apk`
- 大小: 121.34 MB
- 包含所有 ABI (fat APK)

### Release 构建

```powershell
Set-Location D:\3rd-party-projects\vlc-android
D:\dev\gradle-9.6.1\bin\gradle assembleRelease --no-daemon
```

**构建结果 (2026-10-19)**:
- 状态: BUILD SUCCESSFUL
- Gradle 9.6.1 + AGP 9.4.1，耗时约 5 分 3 秒（498 tasks）
- **输出 APK (仅 arm64-v8a)**:

| APK 文件名 | 大小 |
|-------------|------|
| `VLC-Android-3.7.2-arm64-v8a.apk` | 47.1 MB (49,404,533 B) |

- APK 位置: `D:\3rd-party-projects\vlc-android\application\app\build\outputs\apk\release\`
- **签名状态**: 未签名 → 签名后输出至同目录 `signed\`

## Release APK 签名

Release 构建的 APK 需要签名后才能安装到手机。使用以下步骤：

### keystore 文件位置

```
D:\my-projects\my-backup\backup-settings\my-android-release.keystore
```

**重要**: 这是本机通用的 Android release keystore（alias `pisces312`），用于对 VLC Android Release APK 签名，请妥善保管。
> 历史遗留: 早期曾使用 `vlc-android-release.keystore`(alias `vlc-release`)，已弃用。

### 签名命令 (Git Bash)

密钥密码不落盘、不进入命令行历史，统一从 `KEY_*` 环境变量读取（apksigner 原生支持 `env:` 语法）：

```bash
export MSYS_NO_PATHCONV=1
cd /d/3rd-party-projects/vlc-android/application/app/build/outputs/apk/release
mkdir -p signed
for abi in arm64-v8a; do
  "/d/dev/android_sdk/build-tools/36.0.0/apksigner.bat" sign \\
    --ks "${KEY_STORE}" --ks-key-alias "${KEY_ALIAS}" \\
    --ks-pass env:KEY_STORE_PASSWORD --key-pass env:KEY_PASSWORD \\
    --out "signed\\VLC-Android-3.7.2-${abi}.apk" "VLC-Android-3.7.2-${abi}.apk"
done
```

使用的环境变量（已在系统/用户级配置）：

| 变量名 | 用途 |
|--------|------|
| `KEY_STORE` / `KEY_STORE_LOCATION` | keystore 文件路径 |
| `KEY_ALIAS` | key alias (`pisces312`) |
| `KEY_STORE_PASSWORD` | store 密码 |
| `KEY_PASSWORD` | key 密码 |

### 验证签名

```bash
"/d/dev/android_sdk/build-tools/36.0.0/apksigner.bat" verify -v --print-certs signed/*.apk
```

预期输出: `Verifies`，且 v1/v2/v3 scheme 均为 `true`，证书 DN 为 `CN=pisces312, O=pisces312`。

> 说明: `apksigner verify` 会输出若干 `META-INF/... not protected by signature` WARNING（AGP 写入的构建元数据与 netty native-image 配置）。这是 VLC 官方构建同样存在的正常现象，不影响安装与校验，可忽略。

或简化为**已签名的完整构建命令** (Gradle 自动签名):

1. 在项目根目录的 `gradle.properties` 追加:
```properties
keyStoreFile=D:/my-projects/my-backup/backup-settings/my-android-release.keystore
storealias=pisces312
```

2. 构建签名 APK（密码走 `PASSWORD_KEYSTORE` 环境变量，避免明文入库）:
```powershell
$env:PASSWORD_KEYSTORE = $env:KEY_STORE_PASSWORD
Set-Location D:\3rd-party-projects\vlc-android
D:\dev\gradle-9.6.1\bin\gradle assembleSignedRelease --no-daemon
```

### keystore 详细信息

| 项目 | 值 |
|------|-----|
| keystore 文件 | `my-android-release.keystore` |
| 存储位置 | `D:\my-projects\my-backup\backup-settings\` |
| alias | `pisces312` |
| 密码 | 环境变量 `KEY_STORE_PASSWORD`（不写入文件） |
| 密钥算法 | RSA 2048-bit |
| 有效期 | 10000 天 |
| DN (签发者) | `CN=VLC Android, OU=VideoLAN, O=VideoLAN Association, L=Paris, ST=France, C=FR` |

## 构建类型说明

| 构建类型 | 命令 | 说明 |
|----------|------|------|
| debug | `assembleDebug` | 调试版本，包含所有 ABI，后缀 .debug |
| release | `assembleRelease` | 发布版本，仅 arm64-v8a，未签名 |
| signedRelease | `assembleSignedRelease` | 签名发布版本，需配置 gradle.properties |
| vlcBundle | `assembleVlcBundle` | Bundle 版本，minSdk=30 |
| dev | `assembleDev` | 开发版本，含原生编译 (需 Linux) |

## 注意事项

1. **PowerShell 语法**: 不能用 `&&` 连接命令，改用分号 `;` 或分行
2. **Stub 模块**: Debug/Release 模式从 Maven 下载 `org.videolan.android:libvlc-all` 和 `org.videolan.android:medialibrary-all`，stub 模块仅为满足 Gradle 配置阶段
3. **dev 构建类型**: 需要完整的 libvlcjni 和 medialibrary 源码，不支持 stub
4. **完整构建**: 需要 Linux 环境，Windows 仅支持 JVM Build
5. **Debug vs Release APK 差异**:
   - Debug 生成单个 fat APK (包含所有 ABI)，121.34 MB
   - Release 只生成 arm64-v8a 一个 APK，约 47 MB（上游默认会出 4 个 ABI，本地已收敛）
6. **Release APK 未签名**: 需用 `apksigner` 签名后才能安装（见上方签名命令）

## 隐私安全审计

已完成隐私安全审计，结论: **安全** ✅
- 无广告 SDK、无追踪 SDK、无敏感权限收集
- 详见: `vlc-android-privacy-audit_2026-04-21.md`
