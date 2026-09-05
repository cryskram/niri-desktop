# AGENTS.md

# Pi Agent Operating Instructions

You are the implementation agent for this repository.

The repository contains the complete NixOS desktop configuration.

Primary specification:

```text
RICE.md
```

Architectural documentation:

```text
ARCHITECTURE.md
```

The repository is public.

The goal is a reproducible NixOS desktop built around Niri.

---

# 1. Highest Priority

Optimize for:

```text
reliability
reproducibility
maintainability
usability
visual coherence
performance
```

Do not optimize for number of packages, complexity, or visual novelty.

---

# 2. Source of Truth

The Git repository is the source of truth.

Do not maintain separate manually edited copies of configuration.

System configuration should eventually be represented through:

* NixOS
* Home Manager
* flake inputs

---

# 3. Existing Architecture

The repository already contains a working declarative foundation involving:

* NixOS 26.05
* nixpkgs stable
* nixpkgs unstable
* Home Manager
* pi.nix
* declarative Pi
* OpenCode

Preserve this architecture unless there is a concrete technical reason to change it.

Do not replace working Pi/OpenCode integration casually.

---

# 4. Inspect Before Editing

Before changing anything:

1. inspect the repository
2. inspect the relevant module
3. inspect imports
4. inspect related configuration
5. understand dependencies
6. identify whether the problem is local or architectural

Never immediately rewrite the configuration.

---

# 5. Small Changes

Prefer:

```text
inspect
→
small change
→
validate
→
visual test
→
Git diff
→
commit
```

Avoid:

```text
rewrite everything
→
hope
```

---

# 6. Nix

After Nix changes, run appropriate validation.

At minimum where applicable:

```bash
nix flake check
```

and:

```bash
nixos-rebuild dry-build --flake .#nixos
```

Do not claim a configuration works unless it has been validated.

---

# 7. Formatting

Use the repository's configured formatter.

If none exists, establish one deliberately.

Do not introduce multiple formatters for the same language without reason.

---

# 8. Flake Inputs

Do not update all flake inputs as part of an unrelated task.

For example, a UI change should not casually perform:

```bash
nix flake update
```

unless dependency updates are actually required.

If an input must be updated:

1. explain why
2. update deliberately
3. validate
4. inspect the lockfile diff

---

# 9. Pi

Pi is a development agent.

Pi itself is currently provided declaratively through the Nix architecture.

Do not create an independent imperative Pi installation unless explicitly requested.

Pi configuration should eventually be declarative where practical.

Secrets remain outside Git.

---

# 10. OpenCode

OpenCode is also part of the declarative system.

Do not introduce a second unmanaged OpenCode installation.

Do not modify authentication material unless explicitly requested.

---

# 11. Secrets

NEVER commit:

* passwords
* API keys
* tokens
* private keys
* SSH credentials
* Wi-Fi credentials
* authentication files
* personal secrets

Before committing:

```bash
git diff
```

must be inspected.

If secrets are required, recommend proper secret management.

---

# 12. Git

Always check:

```bash
git status
```

before significant changes.

After changes:

```bash
git diff
```

Commits should be focused.

Good:

```text
feat: add system telemetry panel
fix: prevent bar overflow with long titles
feat: add Tokyo Night Storm launcher
fix: handle unavailable bluetooth state
```

Bad:

```text
changes
stuff
final
final2
```

Never use destructive Git commands without explicit authorization.

Avoid:

```bash
git reset --hard
git clean -fd
git push --force
```

---

# 13. Architecture

Prefer:

```text
NixOS
→ system configuration

Home Manager
→ user configuration

Niri
→ compositor/window management

Quickshell
→ desktop UI

launcher
→ application launching

notification daemon
→ notifications

greeter
→ login

lock screen
→ authentication lock

PipeWire
→ audio

NetworkManager
→ network
```

Avoid duplicate functionality.

---

# 14. Niri

Niri owns:

* window management
* focus
* workspaces
* layouts
* window rules
* monitor behavior

Do not implement window-management logic in Quickshell.

---

# 15. Quickshell

Quickshell owns desktop presentation.

Keep components modular.

Prefer:

```text
Bar
Workspace
Window
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
Calendar
Notifications
Power
SystemPanel
```

Do not build a giant QML file.

---

# 16. Bar

The bar is a high-risk component.

Never rely on fixed-width assumptions.

Test:

* long titles
* many workspaces
* missing network
* missing Bluetooth
* muted audio
* battery states
* fullscreen
* monitor changes

The bar must never:

* overflow
* clip essential information
* overlap controls
* extend outside the display

If dynamic information does not fit, redesign the layout.

Do not solve every layout problem with arbitrary widths.

---

# 17. Responsive UI

The current display is:

```text
1920×1080 @ 60 Hz
100% scaling
```

Do not hard-code the UI to that exact display.

The architecture must support additional monitors.

---

# 18. Tokyo Night Storm

Tokyo Night Storm is the global visual system.

Do not introduce arbitrary colors.

Do not repeatedly hard-code palette values.

Use centralized design tokens.

Visual consistency matters more than individual component novelty.

---

# 19. Design Hierarchy

Prioritize:

```text
layout
→ spacing
→ typography
→ hierarchy
→ readability
→ interaction
→ animation
→ decoration
```

Do not use visual effects to hide poor layout.

---

# 20. Blur

Blur is decorative.

If unavailable:

```text
blur
→ transparency
→ solid surface
```

Never make functionality depend on blur.

---

# 21. Animation

Animations should communicate state.

Prefer:

* smooth
* noticeable
* consistent
* fast

Avoid animations that slow down repeated actions.

Use shared timing values where possible.

---

# 22. Failure Handling

Optional components must fail independently.

Examples:

```text
Bluetooth missing
→ unavailable state

Network disconnected
→ disconnected state

Media unavailable
→ hide media controls

Battery unavailable
→ hide battery controls
```

One failed data source must not crash the entire shell.

---

# 23. Visual Validation

Nix evaluation is not visual validation.

For UI changes, inspect the running result whenever possible.

Check:

```text
overflow
clipping
alignment
spacing
contrast
icon sizing
blur
transparency
animation
```

Do not declare a UI complete based only on syntactic correctness.

---

# 24. Testing States

Deliberately test:

```text
normal
fullscreen
long title
many workspaces
no network
no Bluetooth
muted
charging
low battery
high CPU
high RAM
second monitor
```

---

# 25. Login and Lock

Security and reliability take priority.

Do not compromise authentication behavior for visual effects.

The login and lock screens should share the same design system as the desktop.

---

# 26. Dependency Policy

Before adding a dependency:

1. identify the problem
2. inspect existing capabilities
3. determine whether NixOS/Home Manager already provides it
4. consider maintenance cost
5. consider Wayland/Niri compatibility

Do not install software simply because it is common in rice configurations.

---

# 27. Public Repository

Remember that this repository is public.

Keep it suitable for another developer to clone and understand.

Do not include:

* secrets
* machine-specific credentials
* generated junk
* unexplained binaries
* unnecessary personal information

---

# 28. Hardware Configuration

Treat:

```text
hardware-configuration.nix
```

as infrastructure.

Do not modify or regenerate it unnecessarily.

Do not make speculative hardware changes.

---

# 29. Current Hardware Assumptions

Primary machine:

```text
Intel graphics
1920×1080
60 Hz
100% scaling
1 monitor
```

Future:

```text
2+ monitors
```

Avoid hard-coding unnecessary machine-specific behavior.

---

# 30. Change Workflow

For ordinary tasks:

```text
1. Read relevant documentation.
2. Inspect current implementation.
3. Identify affected files.
4. Plan the smallest change.
5. Implement.
6. Format.
7. Validate.
8. Test.
9. Inspect Git diff.
10. Report the result.
```

For larger tasks:

```text
1. Explain architecture.
2. Break work into milestones.
3. Implement one milestone.
4. Validate.
5. Commit.
6. Continue.
```

---

# 31. When Something Breaks

Do not immediately replace the component.

First determine:

```text
what changed?
what owns the behavior?
what dependency changed?
what does the log say?
what was the last known-good state?
```

Use Git history.

Fix root causes.

---

# 32. Rollbacks

Maintain known-good states.

Important milestones should have Git commits/tags.

Never destroy the last known-good configuration while experimenting.

---

# 33. Architecture Decisions

For major decisions, document:

* alternatives considered
* chosen solution
* reason
* tradeoffs

Examples:

* Quickshell choice
* launcher choice
* terminal choice
* greeter choice
* lock-screen choice
* theme architecture
* multi-monitor architecture

Use:

```text
docs/decisions/
```

where appropriate.

---

# 34. Avoid Premature Abstraction

Do not build elaborate frameworks for trivial repetition.

Prefer:

```text
simple
clear
maintainable
```

over clever abstractions.

---

# 35. Do Not Over-Rice

More UI does not automatically mean better UI.

Every component should answer:

> What problem does this solve?

Every animation should answer:

> What state change does this communicate?

Every dependency should answer:

> Why does this need to exist?

---

# 36. Phase Discipline

Follow the project phases defined in RICE.md.

Do not jump ahead unnecessarily.

For example:

Do not build elaborate Quickshell telemetry before Niri itself is stable.

Do not build the final login screen before the underlying authentication architecture is selected.

Do not begin the development environment before the desktop reaches v1.0.

---

# 37. Definition of Good Work

Good work is:

```text
small
understandable
tested
reproducible
reversible
visually coherent
```

Bad work is:

```text
large
fragile
clever
untested
hard-coded
unexplained
```

---

# 38. Final Rule

The objective is not to produce the most complicated Nix configuration.

The objective is to produce a desktop that is:

```text
beautiful
fast
stable
reproducible
maintainable
```

and remains pleasant to use months after the initial build.

