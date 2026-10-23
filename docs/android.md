# Android Studio + Flutter

Physical-device workflow. No emulator, no NDK (deliberate — re-add in `modules/android.nix` if needed).

## What is declarative

- SDK (platforms 35+36, build-tools, platform-tools, cmdline-tools, sources) → `modules/android.nix`
- SDK licenses pre-accepted at build time (`accept_license`) — `flutter doctor --android-licenses` is unnecessary
- `programs.adb.enable` (udev rules) is gone — systemd-uaccess covers USB adb
- `android-studio` → `modules/android.nix` (wrapped, see below), `flutter` → `home/development.nix`
- `xwayland-satellite` → `modules/android.nix`, for the remaining X11-only apps

## The SDK is a symlink overlay, not the store path

`ANDROID_HOME` is **`~/Android/Sdk`**, built by Home Manager activation from the
store SDK: each package directory (`platforms/android-36`, `build-tools/37.0.0`, …)
is symlinked in, and `licenses/` is a real writable copy.

Why: the SDK itself is complete (`sdkmanager --list_installed` lists every
package), but the new-project wizard provisions SDK components while creating a
project and a `/nix/store` path is read-only — `touch` on it is `EROFS`. Studio
reports that failure as "Your Android SDK is missing, out of date or corrupted."
With the overlay it wrote `~/Android/Sdk/.knownPackages` and accepted the SDK.

Anything Studio installs (extra platforms, build-tools, even the emulator if you
ever want it) lands in the overlay as a real directory and costs nothing until
used. `ln -sfn` re-points the store-backed entries on every rebuild, so a new SDK
generation is picked up automatically, and a real directory Studio installed is
never clobbered.

The Studio wrapper pins `ANDROID_HOME`/`ANDROID_SDK_ROOT` itself, so it does not
depend on a session that predates the last switch.

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
2. Studio: do **not** accept the wizard's SDK download offer — the SDK is already there.
3. `flutter config --android-sdk $ANDROID_HOME`
4. `flutter doctor` to verify. Chrome on PATH covers `flutter doctor`'s web check.
5. Plug in the phone (USB debugging on), `adb devices` to confirm.

## Notes

- The AVD Manager warns that `system-images;android-37.2;…` is unavailable — expected
  with no emulator installed. Install one from Studio if you ever want it; it goes
  into the overlay, not the repo.
- Prefer adding platforms/build-tools to `platformVersions`/`buildToolsVersions` in
  `modules/android.nix` over installing them imperatively, so a rebuild reproduces them.
- Studio updates itself imperatively by default; prefer `nix flake update` discipline
  (one input at a time) over its built-in updater so the repo stays the source of truth.
