# c001apk 本地 APK 一键打包脚本
$ErrorActionPreference = "Stop"

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  c001apk Android APK 本地打包流程检查" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

# 1. 检查 Java
try {
    $javaVersion = java -version 2>&1
    Write-Host "[√] 找到 Java 环境" -ForegroundColor Green
} catch {
    Write-Host "[X] 未找到 Java 环境，请先安装 JDK 17 (推荐 Eclipse Temurin 17)" -ForegroundColor Red
    exit 1
}

# 2. 检查 Flutter
$flutterCmd = Get-Command flutter -ErrorAction SilentlyContinue
if (-not $flutterCmd) {
    Write-Host "[X] 未检测到 Flutter SDK。" -ForegroundColor Yellow
    Write-Host "    本项目要求 Flutter 3.47.7 / Dart 3.13.5。" -ForegroundColor Yellow
    Write-Host "    请前往 https://docs.flutter.dev/get-started/install/windows 下载解压，并将其 bin 目录加入 PATH。" -ForegroundColor Yellow
    Write-Host "    或者推荐使用 GitHub Actions 云端打包（免配置庞大环境）。" -ForegroundColor Cyan
    exit 1
} else {
    Write-Host "[√] 找到 Flutter: $(flutter --version | Select-Object -First 1)" -ForegroundColor Green
}

# 3. 检查 Android SDK
if (-not $env:ANDROID_HOME -and -not $env:ANDROID_SDK_ROOT) {
    Write-Host "[!] 未设置 ANDROID_HOME 或 ANDROID_SDK_ROOT 环境变量。" -ForegroundColor Yellow
}

$flutterDir = Join-Path $PSScriptRoot "..\apps\flutter"
Set-Location $flutterDir

Write-Host "`n>>> 正在同步项目依赖 (flutter pub get)..." -ForegroundColor Cyan
flutter pub get

Write-Host "`n>>> 正在编译 Android APK (Release 模式)..." -ForegroundColor Cyan
flutter build apk --release --split-per-abi

$outputDir = Join-Path $flutterDir "build\app\outputs\flutter-apk"
Write-Host "`n=========================================" -ForegroundColor Green
Write-Host "  打包完成！产物位于以下目录：" -ForegroundColor Green
Write-Host "  $outputDir" -ForegroundColor Green
Get-ChildItem -Path $outputDir -Filter "*.apk" | ForEach-Object {
    Write-Host "  - $($_.Name) ($([math]::Round($_.Length / 1MB, 2)) MB)" -ForegroundColor White
}
Write-Host "=========================================" -ForegroundColor Green
