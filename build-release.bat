@echo off
setlocal
REM ---------------------------------------------------------------------------
REM Build and sign the pisces312 fork of VLC for Android (Release, arm64-v8a).
REM
REM Requires these environment variables to be set before running:
REM   KEY_STORE           path to the keystore file
REM   KEY_ALIAS           key alias inside the keystore
REM   KEY_STORE_PASSWORD  keystore password
REM   KEY_PASSWORD        key password
REM
REM Passwords are handed to apksigner as env: references, so they are never
REM written to this file or to the command line.
REM ---------------------------------------------------------------------------

set "ROOT=%~dp0"
cd /d "%ROOT%"

if not defined JAVA_HOME set "JAVA_HOME=D:\dev\AndroidStudio\jbr"
if not defined GRADLE set "GRADLE=D:\dev\gradle-9.6.1\bin\gradle.bat"
if not defined ANDROID_SDK_ROOT set "ANDROID_SDK_ROOT=D:\dev\android_sdk"
set "BUILD_TOOLS=%ANDROID_SDK_ROOT%\build-tools\36.0.0"

set "OUT=%ROOT%application\app\build\outputs\apk\release"
set "SIGNED=%OUT%\signed"

if not defined KEY_STORE goto missing_env
if not defined KEY_ALIAS goto missing_env
if not defined KEY_STORE_PASSWORD goto missing_env
if not defined KEY_PASSWORD goto missing_env
if not exist "%BUILD_TOOLS%\apksigner.bat" goto missing_tools

echo [1/4] Building release APK, this takes a few minutes...
call "%GRADLE%" assembleRelease --no-daemon
if errorlevel 1 goto build_failed

echo [2/4] Locating APK...
set "UNSIGNED="
for %%f in ("%OUT%\*.apk") do set "UNSIGNED=%%~ff"
if not defined UNSIGNED goto no_apk
echo       %UNSIGNED%

echo [3/4] Signing...
REM assembleRelease wipes the release output folder, so signed\ is recreated here.
if exist "%SIGNED%" rd /s /q "%SIGNED%"
mkdir "%SIGNED%"
for %%f in ("%UNSIGNED%") do set "APK=%SIGNED%\%%~nxf"
copy /y "%UNSIGNED%" "%APK%" >nul
if errorlevel 1 goto copy_failed

call "%BUILD_TOOLS%\apksigner.bat" sign --ks "%KEY_STORE%" --ks-key-alias "%KEY_ALIAS%" --ks-pass env:KEY_STORE_PASSWORD --key-pass env:KEY_PASSWORD "%APK%"
if errorlevel 1 goto sign_failed

echo [4/4] Verifying signature...
REM Keep apksigner's exit code: piping into findstr would replace it.
call "%BUILD_TOOLS%\apksigner.bat" verify --verbose "%APK%" > "%TEMP%\vlc_verify.txt" 2>&1
if errorlevel 1 goto verify_failed
findstr /b /c:"Verifies" /c:"Verified using" "%TEMP%\vlc_verify.txt"
del "%TEMP%\vlc_verify.txt" >nul 2>&1

echo.
echo Signed APK : %APK%
for %%a in ("%APK%") do echo Size       : %%~za bytes
echo SHA256     :
REM Only the bare hex line has no colon, the localized labels are dropped here.
certutil -hashfile "%APK%" SHA256 | findstr /v ":"
echo.
echo Done.
exit /b 0

:missing_env
echo [ERROR] Missing signing credentials. Set KEY_STORE, KEY_ALIAS,
echo         KEY_STORE_PASSWORD and KEY_PASSWORD, then run again.
exit /b 1

:missing_tools
echo [ERROR] apksigner.bat not found in %BUILD_TOOLS%
exit /b 1

:build_failed
echo [ERROR] Gradle build failed.
exit /b 1

:no_apk
echo [ERROR] No APK produced in %OUT%
exit /b 1

:copy_failed
echo [ERROR] Could not copy the APK into %SIGNED%
exit /b 1

:sign_failed
echo [ERROR] apksigner sign failed.
exit /b 1

:verify_failed
echo [ERROR] apksigner verify failed.
exit /b 1
