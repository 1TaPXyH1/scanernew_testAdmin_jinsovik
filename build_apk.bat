@echo off
setlocal enabledelayedexpansion

REM Отримати версію з pubspec.yaml
for /f "tokens=2 delims=:" %%A in ('findstr "version:" pubspec.yaml') do set VERSION=%%A
set VERSION=%VERSION: =%

REM Відрізати все після +
for /f "delims=+" %%B in ("!VERSION!") do set VERSION=%%B

REM Створити назву файлу
set OUTPUT=jinsovik-scanner-v%VERSION%.apk

echo Checking APK file...
if exist build\app\outputs\flutter-apk\app-release.apk (
    echo Renaming APK to %OUTPUT%...
    move /Y build\app\outputs\flutter-apk\app-release.apk build\app\outputs\flutter-apk\%OUTPUT%
    
    echo Deleting extra files...
    del /f /q build\app\outputs\flutter-apk\app-release.apk >nul 2>&1
    del /f /q build\app\outputs\flutter-apk\app-release.apk.sha1 >nul 2>&1

    echo Done.
) else (
    echo APK file not found.
)

pause
