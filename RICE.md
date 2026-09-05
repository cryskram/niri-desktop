# Niri Desktop Rice Specification

## 0. Project Identity

This repository defines a complete, reproducible NixOS desktop environment built around the Niri Wayland compositor.

The project is simultaneously:

1. a NixOS configuration,
2. a Home Manager configuration,
3. a complete desktop environment,
4. a visual design system,
5. a development workstation foundation,
6. and a public example of a maintainable Nix desktop configuration.

The repository is the single source of truth.

The system should eventually be reproducible on compatible hardware from this repository.

---

# 1. Current Platform

Primary system:

* NixOS 26.05
* x86_64-linux
* Intel graphics
* 1920×1080
* 60 Hz
* 100% display scaling
* currently one monitor
* future support for multiple monitors

The configuration already uses:

* Nix flakes
* Home Manager
* nixpkgs stable
* nixpkgs unstable
* pi.nix
* declarative Pi
* OpenCode

Existing working architecture must be preserved unless there is a concrete reason to change it.

---

# 2. Project Philosophy

The desktop should not be a collection of unrelated configurations.

It should behave like one coherent operating environment.

Priorities:

1. reliability
2. usability
3. reproducibility
4. maintainability
5. visual quality
6. performance
7. decoration

A beautiful desktop that breaks when a network adapter disappears is not a finished desktop.

---

# 3. Visual Direction

The visual identity combines:

* Tokyo Night Storm
* futuristic operating-system UI
* mission-control workstation
* hacker/developer workstation
* restrained cyberdeck aesthetics

The desired emotional impression:

> sophisticated technical workstation rather than stereotypical cyberpunk interface.

Avoid:

* excessive neon
* fake hacker text
* Matrix rain
* random hexadecimal decoration
* gratuitous scanlines
* unnecessary glowing borders
* "1337" aesthetics
* visual clutter

The design should feel engineered.

---

# 4. Design System

All major components share centralized design tokens.

Required conceptual tokens:

```text
background
background-deep

surface
surface-elevated
surface-hover
surface-active

foreground
foreground-muted
foreground-dim

accent-primary
accent-secondary

border
border-subtle

success
warning
error
info

shadow
glow
```

Do not duplicate color values throughout the repository.

Changing the theme should eventually require changing a small number of centralized values.

---

# 5. Typography

Use a coherent combination of:

* readable UI font
* technical/programming font

Potential candidates:

* Inter
* Geist
* Noto Sans
* JetBrains Mono
* Iosevka
* IBM Plex Mono

Do not install every candidate permanently.

Evaluate and select.

Typography must define:

* font family
* size scale
* weights
* letter spacing
* line height

---

# 6. Desktop Architecture

Niri is responsible for:

* windows
* focus
* workspaces
* layouts
* window rules
* monitor configuration

Quickshell is responsible for:

* desktop UI
* panels
* bar
* system widgets
* interactions

Other tools should provide focused functionality.

Conceptual stack:

```text
NixOS
└── Wayland
    └── Niri
        ├── Quickshell
        ├── launcher
        ├── notifications
        ├── lock screen
        ├── wallpaper
        └── desktop utilities
```

---

# 7. Desktop Shell

Preferred technology:

Quickshell.

The shell must be modular.

Conceptual components:

```text
Bar
WorkspaceIndicator
WindowIndicator
Clock
CPU
RAM
GPU
Temperature
Network
Audio
Battery
Bluetooth
Media
Notifications
Calendar
Launcher
Power
SystemPanel
```

Do not create one monolithic QML implementation.

---

# 8. Top Bar

The bar is a high-priority component.

It should contain useful information without becoming cluttered.

Potential default information:

* workspaces
* active window/application
* CPU
* RAM
* GPU
* temperature
* network
* audio
* battery
* notifications
* clock

The default bar should prioritize information hierarchy.

Secondary information belongs in expandable panels.

---

# 9. Bar Reliability Requirements

The bar must survive:

* long window titles
* many workspaces
* disconnected network
* Bluetooth unavailable
* audio device changes
* muted audio
* battery changes
* charging
* low battery
* high CPU
* high RAM
* fullscreen applications
* monitor changes
* multiple monitors

The bar must never:

* clip text
* overflow
* overlap controls
* extend outside the screen
* become unusable because of dynamic data

Avoid fixed widths wherever possible.

Use flexible layouts and truncation.

---

# 10. System Panels

Create reusable floating panels for:

* network
* audio
* Bluetooth
* battery
* system telemetry
* media
* calendar
* notifications
* power

Panels share:

* palette
* typography
* spacing
* border treatment
* transparency
* blur
* animation

---

# 11. Transparency

Target:

* subtle transparency
* moderate blur
* strong readability

Do not make the entire desktop transparent.

Transparency should communicate layering.

Fallback:

```text
blur unavailable
→ transparency
→ solid surface
```

Functionality must never depend on blur.

---

# 12. Animations

Animations should be:

* smooth
* noticeable
* fast enough for daily use
* consistent

Animation candidates:

* workspace transitions
* launcher
* panels
* notifications
* window appearance
* lock screen
* login screen

Use shared timing constants.

Do not create random animation timings for every component.

---

# 13. Workspaces

Use dynamic workspaces.

Initial keyboard conventions should be familiar.

Suggested foundation:

```text
Super + 1..9
```

for workspace navigation.

Custom shortcuts may be added for:

* moving windows
* focus movement
* monitor movement
* scratchpads
* special workspaces

Do not make the shortcut system unnecessarily complicated.

---

# 14. Launcher

Requirements:

* fast
* keyboard-first
* searchable
* visually integrated
* minimal closed state
* polished open state

Potential features:

* application search
* calculator
* command execution
* web search
* power controls

Select the launcher based on practical behavior rather than popularity.

---

# 15. Notifications

Notifications should be:

* readable
* compact
* integrated with the theme
* urgency-aware
* dismissible
* searchable/history-enabled where practical

A notification failure must not crash the desktop shell.

---

# 16. Login

The login experience is a major design component.

Desired characteristics:

* highly technical
* futuristic
* GUI-based
* information-rich
* polished
* secure

It should communicate system identity.

Possible information:

* NixOS
* hostname
* kernel
* graphics
* session
* network
* time
* date

Potential technologies include graphical greetd-compatible solutions or another secure Wayland-compatible greeter.

Security and reliability take precedence over visual customization.

---

# 17. Lock Screen

The lock screen should be visually elaborate.

Potential information:

* large clock
* date
* user
* authentication field
* battery
* network
* system state
* media

It must share the login screen's visual identity.

Authentication security takes precedence over appearance.

---

# 18. Wallpaper

Wallpaper strategy:

```text
dynamic wallpapers
        ↓
static fallback
```

Potential dynamic modes:

* time-based
* manual
* contextual

Wallpapers should preserve readability.

Avoid overly busy images.

---

# 19. Terminal

Initial candidates:

* Ghostty
* Alacritty

Evaluate both.

The primary terminal should eventually use:

* Tokyo Night Storm
* selected font
* sensible padding
* Wayland-native behavior
* developer-friendly defaults

---

# 20. Shell

Preferred shell:

Zsh.

Supporting tools:

* Starship
* fzf
* zoxide
* eza
* bat
* fd
* ripgrep
* jq
* yq
* lazygit

Shell startup should remain fast.

---

# 21. File Management

Yazi:

* terminal file management
* previews
* developer workflow

Nautilus:

* graphical file management
* desktop integration
* removable devices

Both should visually integrate with the system where practical.

---

# 22. Browser

Install/evaluate:

* Google Chrome
* Zen Browser

Select the primary browser based on actual usage.

---

# 23. Audio

Use PipeWire/WirePlumber.

Provide convenient controls for:

* volume
* mute
* output
* input
* device switching

---

# 24. Network

Provide GUI controls for:

* connection state
* Wi-Fi
* active network
* useful connection details
* VPN state where available

Network failure must not break the shell.

---

# 25. Bluetooth

Provide:

* state
* connected devices
* enable/disable
* useful pairing controls

Bluetooth absence must be treated as a valid system state.

---

# 26. Clipboard

Provide a Wayland-compatible clipboard manager with searchable history.

---

# 27. Screenshots and Recording

Provide shortcuts for:

* full screen
* region
* active window
* screen recording

Output locations should be predictable.

---

# 28. Multi-monitor

Current target:

```text
1 × 1920×1080 @ 60 Hz
```

Architecture must support:

```text
1 monitor
→
2 monitors
```

without requiring a redesign.

Requirements:

* independent bars
* correct wallpapers
* sensible workspaces
* monitor-aware configuration
* no duplicated global controls
* correct scaling

---

# 29. Nix Architecture

The repository is the source of truth.

Use:

* NixOS modules for system-level configuration
* Home Manager for user-level configuration
* flakes for reproducibility

Do not maintain separate unmanaged copies of the active configuration.

Target structure:

```text
project/
├── flake.nix
├── flake.lock
├── hosts/
├── modules/
├── home/
├── programs/
├── scripts/
├── assets/
├── docs/
├── RICE.md
├── AGENTS.md
├── ARCHITECTURE.md
├── CHANGELOG.md
├── TODO.md
└── README.md
```

The structure may evolve.

---

# 30. Pi and OpenCode

Pi is a first-class development tool.

Current architecture already uses:

* declarative Pi
* nixpkgs unstable Pi package
* pi.nix
* OpenCode from nixpkgs unstable
* Home Manager OpenCode configuration

Do not replace this architecture casually.

Authentication secrets remain outside Git.

Future improvements may make Pi extensions, skills and themes declarative where practical.

---

# 31. Git

The repository is public.

Never commit:

* passwords
* API keys
* tokens
* private keys
* Wi-Fi credentials
* authentication files
* personal secrets

Use proper secret management if needed.

Potential future solution:

```text
sops-nix
```

---

# 32. Git Milestones

Suggested milestones:

```text
v0.1-foundation
v0.2-architecture
v0.3-niri
v0.4-theme
v0.5-shell
v0.6-login
v0.7-lock
v0.8-ux
v0.9-polish
v0.10-qa
v1.0
```

Every major milestone should be recoverable.

---

# 33. Development Phases

## Phase 0: Foundation

Current NixOS configuration.

Stabilize:

* flakes
* Home Manager
* Pi
* OpenCode
* Git
* system configuration

---

## Phase 1: Architecture

Refactor the current flake into clean modules.

Do not change behavior unnecessarily.

---

## Phase 2: Niri

Install and validate Niri.

No serious visual customization.

Goal:

> reliable Niri desktop.

---

## Phase 3: Desktop Skeleton

Introduce:

* launcher
* notifications
* wallpaper
* lock
* power
* Quickshell

---

## Phase 4: Theme

Establish:

* Tokyo Night Storm
* fonts
* icons
* GTK
* Qt
* terminal
* launcher
* notifications

---

## Phase 5: Custom Shell

Implement:

* bar
* workspace UI
* telemetry
* network
* audio
* battery
* Bluetooth
* media
* calendar

---

## Phase 6: Login and Lock

Build the technical GUI login and elaborate lock screen.

---

## Phase 7: UX

Implement:

* shortcuts
* clipboard
* screenshots
* recording
* system controls
* power
* monitor controls

---

## Phase 8: Polish

Focus on:

* spacing
* typography
* blur
* transparency
* animation
* hierarchy
* micro-interactions

---

## Phase 9: Multi-monitor

Validate two-monitor behavior.

---

## Phase 10: QA

Deliberately stress the desktop.

Test:

* long titles
* many workspaces
* no network
* no Bluetooth
* muted audio
* low battery
* charging
* high CPU
* high RAM
* fullscreen
* multiple monitors

---

## Phase 11: Freeze

Create v1.0.

Document:

* architecture
* installation
* configuration
* known limitations
* rollback

---

# 34. Visual QA

A UI change is not complete merely because Nix evaluates.

Validate:

```text
Nix correctness
+
application correctness
+
visual correctness
```

Check:

* clipping
* overflow
* alignment
* spacing
* readability
* contrast
* icon consistency
* blur
* transparency
* animations

---

# 35. Performance

Target:

* fast startup
* low idle CPU
* reasonable memory
* smooth animation
* minimal unnecessary background services

Do not add components solely because they are popular in rice communities.

---

# 36. Definition of Done

The desktop is v1.0 when:

* NixOS configuration is reproducible
* Home Manager is reproducible
* Git repository contains the complete configuration
* Niri is stable
* Quickshell is stable
* bar never overflows
* login works
* lock works
* notifications work
* launcher works
* network controls work
* audio controls work
* Bluetooth controls work
* battery controls work
* screenshots work
* recording works
* clipboard works
* Yazi works
* Nautilus works
* terminal is polished
* shell is polished
* Tokyo Night Storm is coherent
* one-monitor experience is excellent
* two-monitor operation works
* validation passes
* no secrets are committed
* rollback works
* documentation is sufficient for another developer to understand the system

The target is a complete operating environment, not a screenshot.

