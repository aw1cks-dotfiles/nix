# Noctalia Launcher and Omnissa Horizon

## Summary

Omnissa Horizon is installed correctly on the desktop host and ships a valid desktop entry, but it does not launch from the Noctalia application launcher.

The same application does launch successfully in both of these cases:

```bash
horizon-client
```

```bash
nix shell nixpkgs#gtk3.out -c gtk-launch horizon-client
```

This isolates the failure to Noctalia's launcher path rather than the Nix package, desktop entry, or Horizon binary itself.

## Evidence

The desktop entry is present in the Home Manager application directory:

```text
/etc/profiles/per-user/alex/share/applications/horizon-client.desktop
```

Its contents are valid and minimal:

```ini
[Desktop Entry]
Exec=/nix/store/.../bin/horizon-client %u
Icon=/nix/store/.../share/icons/horizon-client.png
MimeType=x-scheme-handler/horizon-client;x-scheme-handler/vmware-view
Name=Omnissa Horizon Client
Type=Application
Version=1.5
```

That entry is not hidden and does not depend on shell `PATH` resolution.

## Likely Root Cause

Noctalia appears to prefer launching desktop applications by extracting the desktop entry command and passing it through its compositor spawn path.

That differs from `gtk-launch`, which uses the desktop entry's native GLib and GIO launch path. The native path provides behavior that raw command spawning does not, including:

- XDG activation
- startup notification
- D-Bus desktop-entry activation
- correct desktop-entry execution semantics

This matters for Omnissa Horizon because the app launches successfully when invoked through `gtk-launch horizon-client`, but not when launched through Noctalia.

The investigation also found a likely Noctalia bug in its launcher heuristics:

- Noctalia references `app.exec`
- Quickshell exposes `execString`, not `exec`

That mismatch likely prevents Noctalia from selecting the desktop entry's native execution path when it should.

## Expected Upstream Fix

The Noctalia launcher should prefer the desktop entry's native execution method first and only fall back to raw command spawning if needed.

Desired launch order:

1. `app.execute()`
2. raw command spawn fallback

Noctalia should also use `execString` instead of `exec` when inspecting desktop entry metadata.

## Current Workaround

Use one of these working launch methods:

```bash
horizon-client
```

```bash
gtk-launch horizon-client
```

If Noctalia gains support for app-specific custom launch commands, `gtk-launch horizon-client` is the safest launcher-side workaround.

## Scope

This is not currently a repo packaging problem.

- `omnissa-horizon-client` is installed by `modules/home/packages/gui-apps.nix`
- the desktop entry is present
- the desktop entry launches correctly through standard XDG tooling

The remaining issue is launcher-side behavior in Noctalia.
