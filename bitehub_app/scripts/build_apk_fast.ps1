param(
    [ValidateSet("debug", "profile", "release")]
    [string]$Mode = "debug",

    [ValidateSet("android-arm", "android-arm64", "android-x64")]
    [string]$TargetPlatform = "android-arm64",

    [string]$ApiBaseUrl = "https://fooood.pythonanywhere.com",

    [switch]$PubGet,
    [switch]$SplitPerAbi
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$AppRoot = Resolve-Path (Join-Path $ScriptDir "..")
Push-Location $AppRoot

try {
    $previousDebug = $env:DEBUG
    $env:DEBUG = ""
    $env:FLUTTER_SUPPRESS_ANALYTICS = "true"

    if ($PubGet -or -not (Test-Path ".dart_tool/package_config.json")) {
        flutter pub get
    }

    $args = @(
        "build", "apk",
        "--$Mode",
        "--target-platform", $TargetPlatform,
        "--dart-define=BITE_HUB_API_BASE_URL=$ApiBaseUrl"
    )

    if ($SplitPerAbi) {
        $args += "--split-per-abi"
    }

    $started = Get-Date
    flutter @args
    $elapsed = New-TimeSpan -Start $started -End (Get-Date)

    $apkDir = Join-Path $AppRoot "build/app/outputs/flutter-apk"
    Write-Host ""
    Write-Host "APK build finished in $($elapsed.ToString())."
    Get-ChildItem -Path $apkDir -Filter "*.apk" |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 5 FullName, Length, LastWriteTime |
        Format-Table -AutoSize
}
finally {
    $env:DEBUG = $previousDebug
    Pop-Location
}
