# Linux development and AppImage

Linux support currently targets an x86_64 AppImage built on Ubuntu 22.04. Building on this baseline
keeps the required glibc version low enough for Ubuntu 22.04 and Debian 12. Other package formats and
architectures are not release targets yet.

## Development setup

Install Node 22.11, pnpm 10, the pinned Rust toolchain, and Tauri's Linux dependencies:

```bash
sudo apt-get update
sudo apt-get install -y binutils libwebkit2gtk-4.1-dev libappindicator3-dev librsvg2-dev patchelf
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

The packaging command builds only the AppImage, checks its architecture and ELF dependency table,
rejects build-home path leakage, and prints a SHA-256 digest. T2 extracts the artifact inside an
Ubuntu 22.04 container with the baseline GTK runtime but no WebKitGTK packages. It resolves the
runtime dependency closure from the extracted AppDir, starts the application without renderer
workarounds, captures the WebView window, and rejects blank or near-uniform rendering.

T3 runs the AppImage in a separate Ubuntu 22.04 WebDriver container with the real Ghostty 1.3.1
community AppImage pinned by SHA-256 and an isolated HOME. It drives the renderer through
`tauri-driver`, verifies a configured foreign-platform key is visible but read-only, changes a
scalar setting, validates and applies it through real Ghostty, then restores the generated snapshot.
The test requires the original configuration bytes—including the filtered platform key—to be
restored exactly.

## Release limits

The automated checks do not replace the distribution and desktop matrix. Before a public release,
manually cover Ubuntu 24.04, Debian 12, Fedora, and Arch (T4). T5 requires a real Linux desktop and
must pass on both Wayland and X11, including HiDPI and the application confirmation dialogs, before any public
Linux release. CI/Xvfb evidence does not waive this release gate. Network filesystems remain outside
the supported write-safety matrix.
