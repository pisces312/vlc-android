# VLC-Android 构建文档

## 项目信息
- **仓库**: videolan/vlc-android (已 fork 到 pisces312/vlc-android)
- **本地路径**: `D:\nili\3rd_party_projects\vlc-android`
- **版本**: 3.7.1 Beta 2
- **许可证**: GNU GPL v2
- **构建方式**: JVM Build (从 Maven 下载预编译 LibVLC，不编译原生库)

## 构建环境

| 组件 | 版本 |
|------|------|
| Gradle | 9.4.1 (本地安装) |
| AGP | 8.13.2 |
| Kotlin | 2.1.20 |
| compileSdk / targetSdk | 36 |
| JDK | 21 |
| Android SDK | `D:\nili\dev\android_sdk` |

## 构建前准备

### 1. 创建 local.properties (指向 Android SDK)

**路径**: `D:\nili\3rd_party_projects\vlc-android\local.properties`

```properties
sdk.dir=D:\\nili\\dev\\android_sdk
```

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
Set-Location D:\nili\3rd_party_projects\vlc-android
gradle assembleDebug --no-daemon
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
Set-Location D:\nili\3rd_party_projects\vlc-android
gradle assembleRelease --no-daemon
```

**构建结果**:
- 状态: BUILD SUCCESSFUL
- 耗时: 8分3秒
- 任务数: 519 (507 executed, 12 up-to-date)
- **输出 APK (按 ABI 分拆)**:

| APK 文件名 | 大小 |
|-------------|------|
| `VLC-Android-3.7.1-Beta-2-arm64-v8a.apk` | 45.58 MB |
| `VLC-Android-3.7.1-Beta-2-armeabi-v7a.apk` | 44.70 MB |
| `VLC-Android-3.7.1-Beta-2-x86.apk` | 45.74 MB |
| `VLC-Android-3.7.1-Beta-2-x86_64.apk` | 46.97 MB |

- APK 位置: `D:\nili\3rd_party_projects\vlc-android\application\app\build\outputs\apk\release\`
- **签名状态**: 未签名

## Release APK 签名

Release 构建的 APK 需要签名后才能安装到手机。使用以下步骤：

### keystore 文件位置

```
C:\nili\my-git-projects\my-backup\backup-settings\vlc-android-release.keystore
```

**重要**: 此 keystore 非常重要！用于对 VLC Android Release APK 签名，请妥善保管。

### 签名命令 (PowerShell)

```powershell
# 签名 Release APK (使用 Python 调用 apksigner，避免 PowerShell 语法问题)
python -c "
import subprocess
subprocess.run([
    'D:\\nili\\dev\\android_sdk\\build-tools\\37.0.0\\apksigner.bat',
    'sign',
    '--ks', 'C:\\nili\\my-git-projects\\my-backup\\backup-settings\\vlc-android-release.keystore',
    '--ks-pass', 'pass:vlc2026release',
    '--key-pass', 'pass:vlc2026release',
    '--out', 'D:\\nili\\3rd_party_projects\\vlc-android\\application\\app\\build\\outputs\\apk\\release\\VLC-Android-3.7.1-Beta-2-arm64-v8a-signed.apk',
    'D:\\nili\\3rd_party_projects\\vlc-android\\application\\app\\build\\outputs\\apk\\release\\VLC-Android-3.7.1-Beta-2-arm64-v8a.apk'
])
"
```

或简化为**已签名的完整构建命令** (Gradle 自动签名):

1. 在项目根目录创建或编辑 `gradle.properties`:
```properties
keyStoreFile=C:/nili/my-git-projects/my-backup/backup-settings/vlc-android-release.keystore
storealias=vlc-release
storepwd=vlc2026release
```

2. 构建签名 APK:
```powershell
Set-Location D:\nili\3rd_party_projects\vlc-android
gradle assembleSignedRelease --no-daemon
```

### keystore 详细信息

| 项目 | 值 |
|------|-----|
| keystore 文件 | `vlc-android-release.keystore` |
| 存储位置 | `C:\nili\my-git-projects\my-backup\backup-settings\` |
| alias | `vlc-release` |
| 密码 | `vlc2026release` |
| 密钥算法 | RSA 2048-bit |
| 有效期 | 10000 天 |
| DN (签发者) | `CN=VLC Android, OU=VideoLAN, O=VideoLAN Association, L=Paris, ST=France, C=FR` |

## 构建类型说明

| 构建类型 | 命令 | 说明 |
|----------|------|------|
| debug | `assembleDebug` | 调试版本，包含所有 ABI，后缀 .debug |
| release | `assembleRelease` | 发布版本，按 ABI 分拆，未签名 |
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
   - Release 按 ABI 分拆生成 4 个 APK，每个约 45-47 MB
6. **Release APK 未签名**: 需用 `apksigner` 签名后才能安装（见上方签名命令）

## 隐私安全审计

已完成隐私安全审计，结论: **安全** ✅
- 无广告 SDK、无追踪 SDK、无敏感权限收集
- 详见: `vlc-android-privacy-audit_2026-04-21.md`
