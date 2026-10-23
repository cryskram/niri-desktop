# Android Studio + Flutter (physical-device workflow, no emulator/NDK per choice).
{
  pkgs,
  lib,
  config,
  ...
}:
let
  androidSdk = pkgs.androidenv.composeAndroidPackages {
    platformVersions = [
      "35"
      "36"
    ];
    includeSources = true;
  };

  storeSdk = "${androidSdk.androidsdk}/libexec/android-sdk";
  home = config.users.users.vageesh.home;
  # Studio's new-project wizard provisions SDK components as part of creating a
  # project, and a /nix/store path is read-only — that surfaces as "Your Android
  # SDK is missing, out of date or corrupted." even though the SDK is complete
  # (verified: sdkmanager lists every package, but `touch` on the root is
  # EROFS). So the store SDK stays the declarative base and a writable overlay in
  # $HOME gets per-package symlinks into it; anything Studio installs lands in the
  # overlay as a real directory, costing nothing until used.
  sdkOverlay = "${home}/Android/Sdk";

  # AWT defaults to the X11 toolkit and this desktop has no XWayland, so Studio
  # died with "java.awt.HeadlessException: No X11 DISPLAY variable was set".
  # The bundled JBR does ship libawt_wlawt.so, so point it at the Wayland toolkit
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
      wrapProgram $out/bin/android-studio \
        --set STUDIO_VM_OPTIONS ${studioVmOptions} \
        --set ANDROID_HOME ${sdkOverlay} \
        --set ANDROID_SDK_ROOT ${sdkOverlay}
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
  # They point at the overlay, not the store, so both see the same writable SDK.
  environment.sessionVariables = {
    ANDROID_HOME = sdkOverlay;
    ANDROID_SDK_ROOT = sdkOverlay;
  };

  # Build/refresh the overlay. Runs as the user (Home Manager activation), so no
  # chown is needed, and `ln -sfn` re-points symlinks after every rebuild so a new
  # SDK generation is picked up instead of the stale one.
  home-manager.users.vageesh.home.activation.androidSdkOverlay = lib.mkAfter ''
    sdk="${sdkOverlay}"
    base="${storeSdk}"
    mkdir -p "$sdk"

    # Licenses are the one thing Studio and sdkmanager rewrite, so they are a real
    # writable copy rather than a symlink into the store.
    if [ ! -d "$sdk/licenses" ]; then
      cp -r "$base/licenses" "$sdk/licenses"
      chmod -R u+w "$sdk/licenses"
    fi

    for pkg in build-tools cmake cmdline-tools platforms platform-tools sources tools; do
      [ -d "$base/$pkg" ] || continue
      mkdir -p "$sdk/$pkg"
      for pkgdir in "$base/$pkg"/*; do
        [ -e "$pkgdir" ] || continue
        name="$(basename "$pkgdir")"
        # Never clobber a real install Studio made into the overlay.
        if [ -d "$sdk/$pkg/$name" ] && [ ! -L "$sdk/$pkg/$name" ]; then
          continue
        fi
        ln -sfn "$pkgdir" "$sdk/$pkg/$name"
      done
    done
  '';
}
