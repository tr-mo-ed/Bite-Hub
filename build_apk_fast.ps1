param(
    [ValidateSet("debug", "profile", "release")]
    [string]$Mode = "debug",

    [ValidateSet("android-arm", "android-arm64", "android-x64")]
    [string]$TargetPlatform = "android-arm64",

    [string]$ApiBaseUrl = "https://fooood.pythonanywhere.com",

    [switch]$PubGet,
    [switch]$SplitPerAbi
)

$Script = Join-Path $PSScriptRoot "bitehub_app/scripts/build_apk_fast.ps1"
& $Script `
    -Mode $Mode `
    -TargetPlatform $TargetPlatform `
    -ApiBaseUrl $ApiBaseUrl `
    -PubGet:$PubGet `
    -SplitPerAbi:$SplitPerAbi
