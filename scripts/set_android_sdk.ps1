# Set ANDROID_HOME so Flutter and Gradle can find the Android SDK (and aapt/build-tools).
# AppData was moved to D:\cusr_moved\AppData, so SDK is at D:\cusr_moved\AppData\Local\Android\Sdk

$sdkPath = "D:\cusr_moved\AppData\Local\Android\Sdk"
if (-not (Test-Path $sdkPath)) {
    $sdkPath = "C:\Users\DELL\AppData\Local\Android\Sdk"
}

[Environment]::SetEnvironmentVariable("ANDROID_HOME", $sdkPath, "User")
[Environment]::SetEnvironmentVariable("ANDROID_SDK_ROOT", $sdkPath, "User")

Write-Host "Set ANDROID_HOME = $sdkPath"
Write-Host ""
Write-Host "Close and reopen your terminal, then run: flutter doctor -v"
Write-Host "If you still see 'Could not locate aapt', install Android SDK Build-Tools in Android Studio:"
Write-Host "  Tools > SDK Manager > SDK Tools tab > check 'Android SDK Build-Tools' > Apply"
