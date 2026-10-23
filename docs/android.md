# Android Studio + Flutter

Physical-device workflow. No emulator, no NDK (deliberate — re-add in `modules/android.nix` if needed).

## What is declarative

- SDK (platforms 35+36, build-tools, platform-tools, cmdline-tools, sources) + `ANDROID_HOME`/`ANDROID_SDK_ROOT` → `modules/android.nix`
- SDK licenses pre-accepted at build time (`accept_license`) — `flutter doctor --android-licenses` is unnecessary and cannot write to the read-only store SDK
- `programs.adb.enable` (udev rules) is gone — systemd-uaccess covers USB adb
- `android-studio` → `modules/android.nix` (wrapped, see below), `flutter` → `home/development.nix`
- `xwayland-satellite` → `modules/android.nix`, for the remaining X11-only apps

## Studio runs on Wayland, not XWayland

This desktop has **no XWayland**, so Studio's AWT X11 backend died with
`java.awt.HeadlessException: No X11 DISPLAY variable was set`. The bundled JBR
ships `libawt_wlawt.so`, so `modules/android.nix` wraps the package with
`STUDIO_VM_OPTIONS` pointing at a vmoptions file containing
`-Dawt.toolkit.name=WLToolkit`. Verified with `DISPLAY` unset: the wizard opens
as `app_id: jetbrains-studio`.

`xwayland-satellite` is installed because Discord/Figma are still X11-only. niri
(26.04+) spawns it from `PATH` **at startup** and exports `DISPLAY` to everything
it launches later — so it needs one re-login, and shells opened before that point
keep the old (DISPLAY-less) environment. Studio does not depend on it.

## After switching (one-time, imperative)

1. No re-login needed for Studio itself (Wayland toolkit, no new groups).
   Re-login only if you want Discord/Figma to see `DISPLAY`.
2. Studio first run: setup wizard offers to download an SDK — cancel that, point it at the existing SDK instead (`$ANDROID_HOME`, i.e. `/run/current-system/sw/libexec/android-sdk`).
3. `flutter config --android-sdk $ANDROID_HOME`
4. `flutter doctor` to verify. Chrome on PATH covers `flutter doctor`'s web check.
5. Plug in the phone (USB debugging on), `adb devices` to confirm.

## Notes

- Gradle cannot download missing SDK packages into the store SDK. If a build demands another platform/build-tools version, add it to `platformVersions`/`buildToolsVersions` in `modules/android.nix` and rebuild.
- Studio updates itself imperatively by default; prefer `nix flake update` discipline (one input at a time) over its built-in updater so the repo stays the source of truth.
