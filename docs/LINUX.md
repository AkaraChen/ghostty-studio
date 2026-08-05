# Linux development and AppImage

Linux support currently targets an x86_64 AppImage built on Ubuntu 22.04. Building on this baseline
keeps the required glibc version low enough for Ubuntu 22.04 and Debian 12. Other package formats and
architectures are not release targets yet.

## Development setup

Install Node 22.11, pnpm 10, the pinned Rust toolchain, and Tauri's Linux dependencies:

```bash
sudo apt-get update
sudo apt-get install -y libwebkit2gtk-4.1-dev libappindicator3-dev librsvg2-dev patchelf
pnpm install --frozen-lockfile
pnpm check
pnpm tauri dev
```

The desktop process searches standard system locations, `PATH`, `~/.local/bin`, Nix profiles, Snap,
and Flatpak exports for Ghostty. When launched from an AppImage it removes AppImage-specific library
and GTK environment variables before invoking the host Ghostty binary.

## Build and automated verification

On x86_64 Linux:

```bash
pnpm package:linux-local
pnpm test:linux-appimage
```

The packaging command builds only the AppImage, checks its architecture and bundled libraries,
rejects build-home path leakage, and prints a SHA-256 digest. The smoke test extracts the artifact
inside a minimal Ubuntu 22.04 container without WebKitGTK development packages, supplies a temporary
Ghostty/config environment, and requires the application window to appear under Xvfb.

CI additionally runs a functional backend round trip that stages a scalar edit, validates it with a
Ghostty-compatible executable, atomically applies it, reads the recovery snapshot, validates the
snapshot, and restores it.

## Release limits

The automated checks do not replace the distribution and desktop matrix. Before a public release,
manually cover Ubuntu 24.04, Debian 12, Fedora, and Arch (T4), plus Wayland, X11, HiDPI, and native
confirmation dialogs (T5). Network filesystems remain outside the supported write-safety matrix.
