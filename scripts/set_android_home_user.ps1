# Set ANDROID_USER_HOME and ANDROID_AVD_HOME for current user (persistent)
# so Android Studio finds emulators after AppData move. Run once as the user.

$userHome = $env:USERPROFILE
$androidUserHome = "$userHome\.android"
$androidAvdHome = "$userHome\.android\avd"

[Environment]::SetEnvironmentVariable("ANDROID_USER_HOME", $androidUserHome, "User")
[Environment]::SetEnvironmentVariable("ANDROID_AVD_HOME", $androidAvdHome, "User")

Write-Host "Set ANDROID_USER_HOME = $androidUserHome"
Write-Host "Set ANDROID_AVD_HOME  = $androidAvdHome"
Write-Host ""
Write-Host "Restart Android Studio for it to pick up the new variables."
Write-Host "If emulators still don't show: In Android Studio go to File > Invalidate Caches > Invalidate and Restart."
