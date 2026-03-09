@echo off
REM Set Android home paths so Android Studio finds your emulators after AppData move
REM Run this, then start Android Studio from this same command window, or set these as System env vars.

set ANDROID_USER_HOME=%USERPROFILE%\.android
set ANDROID_AVD_HOME=%USERPROFILE%\.android\avd
REM If your SDK is on C: (default):
set ANDROID_HOME=%LOCALAPPDATA%\Android\Sdk
REM If you moved AppData to D: and use a junction, %LOCALAPPDATA% should still resolve correctly.

echo ANDROID_USER_HOME=%ANDROID_USER_HOME%
echo ANDROID_AVD_HOME=%ANDROID_AVD_HOME%
echo ANDROID_HOME=%ANDROID_HOME%
echo.
echo Starting Android Studio with these paths...
echo (Close this window after Android Studio opens, or leave it open.)
echo.

start "" "C:\Program Files\Android\Android Studio\bin\studio64.exe"
REM If Android Studio is installed elsewhere, edit the path above.

pause
