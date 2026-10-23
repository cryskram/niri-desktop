# Android Studio + Flutter (physical-device workflow, no emulator/NDK per choice).
{ pkgs, ... }:
let
  androidSdk = pkgs.androidenv.composeAndroidPackages {
    platformVersions = [
      "35"
      "36"
    ];
    includeSources = true;
  };
in
{
  # Pre-accept SDK component licenses at build time (store SDK is read-only, so
  # `flutter doctor --android-licenses` cannot write them later — and need not).
  nixpkgs.config.android_sdk.accept_license = true;

  # adb over USB: systemd handles uaccess rules automatically (programs.adb was
  # removed for this reason), so plain android-tools on PATH is the whole setup.
  environment.systemPackages = [
    androidSdk.androidsdk
    pkgs.android-tools
  ];

  # Studio (launched from the app grid) and flutter (shell) both read these.
  environment.sessionVariables = {
    ANDROID_HOME = "${androidSdk.androidsdk}/libexec/android-sdk";
    ANDROID_SDK_ROOT = "${androidSdk.androidsdk}/libexec/android-sdk";
  };
}
