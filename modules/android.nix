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

  # AWT defaults to the X11 toolkit and this desktop has no XWayland, so Studio
  # died with "java.awt.HeadlessException: No X11 DISPLAY variable was set".
  # The bundled JBR does ship libawt_wlawt.so, so Point it at the Wayland toolkit
  # instead of pulling in an X server. Verified with DISPLAY unset: the wizard
  # opens as app_id "jetbrains-studio". symlinkJoin keeps the shipped .desktop
  # and icons, which a bare script wrapper would drop from the app grid.
  studioVmOptions = pkgs.writeText "studio64.vmoptions" ''
    -Dawt.toolkit.name=WLToolkit
  '';

  androidStudio = pkgs.symlinkJoin {
    name = "android-studio-wayland";
    paths = [ pkgs.android-studio ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/android-studio --set STUDIO_VM_OPTIONS ${studioVmOptions}
    '';
  };
in
{
  # Pre-accept SDK component licenses at build time (store SDK is read-only, so
  # `flutter doctor --android-licenses` cannot write them later — and need not).
  nixpkgs.config.android_sdk.accept_license = true;

  environment.systemPackages = [
    androidSdk.androidsdk
    # adb over USB: systemd handles uaccess rules automatically (programs.adb was
    # removed for this reason), so plain android-tools on PATH is the whole setup.
    pkgs.android-tools
    androidStudio
    # X11 apps still exist (Discord, Figma). niri 26.04 spawns it from PATH on
    # startup and exports DISPLAY to everything it launches afterwards.
    pkgs.xwayland-satellite
  ];

  # Studio (launched from the app grid) and flutter (shell) both read these.
  environment.sessionVariables = {
    ANDROID_HOME = "${androidSdk.androidsdk}/libexec/android-sdk";
    ANDROID_SDK_ROOT = "${androidSdk.androidsdk}/libexec/android-sdk";
  };
}
