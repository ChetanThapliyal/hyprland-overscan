# Building on another Arch-based setup (CachyOS / Arch / EndeavourOS)

Hyprland here is built from the **v0.56.2** tag with our overscan patch applied,
then installed to `/usr/local` so it shadows the distro/AUR package.

## Prereqs

The patch is written against tag `v0.56.2`, so the build must target that exact
tag regardless of which Hyprland version your distro ships (the installed
version doesn't matter — `/usr/local/bin` wins over `/usr/bin`).

## 1. Build dependencies

```bash
sudo pacman -S --needed base-devel cmake meson ninja git \
  hyprutils hyprlang hyprcursor hyprgraphics hyprwayland-scanner aquamarine hyprwire \
  wayland wayland-protocols libdrm mesa pixman libdisplay-info \
  cairo pango libxkbcommon tomlplusplus re2
```

This list matches this machine's verified working environment. If `cmake`
later fails with a version check like `hyprutils>=0.10.3`, upgrade the
offending packages from `extra`/CachyOS repos first.

## 2. Clone + apply the patch

```bash
git clone --recurse-submodules --branch v0.56.2 \
  https://github.com/hyprwm/Hyprland.git hyprland-overscan
cd hyprland-overscan
git apply /path/to/hyprland-overscan/overscan-backport.patch
```

`--recurse-submodules` pulls the vendored `hyprland-protocols`, `tracy`, and
`udis86` submodules. (Note: `hyprutils` is NOT a submodule — it's the system
package.)

## 3. Configure + build

```bash
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=/usr/local
cmake --build build --config Release --target all -j$(nproc)
```

Binary lands at `build/Hyprland`.

## 4. Install

```bash
sudo cmake --install build
```

This places the binary at `/usr/local/bin/Hyprland` (plus `/usr/local/bin/hyprctl`,
`hyprpm`, etc., all from the same build).

## 5. Activate

Log out and back in (or start Hyprland from a TTY). Verify you're running the
patched build:

```bash
pidof Hyprland
```

→ the path should read `/usr/local/bin/Hyprland`.

## Updating / upgrading Hyprland

- `pacman -Syu` updates the distro package in `/usr/bin`, which your patched
  build shadows — **it will not overwrite `/usr/local`**. Safe to run normally.
- To get real upstream updates: re-clone the newer tag, re-apply the patch
  (fix up any hunks that drifted), rebuild, reinstall.
- If a future Hyprland ships overscan natively, drop the patch and use stock.

## Troubleshooting

- `CMake Error: Not a file: .../cmake_install.cmake` — the build dir was
  cleaned; rerun step 3 from scratch.
- `unknown field 'overscan_l/t/r/b'` in `hyprctl configerrors` — you're
  running a *stale* installed binary (installed before the Lua bindings edit
  was rebuilt). Rebuild **then** reinstall, then relog.
- Damage/ghosting artifacts (boxes trailing the cursor, seam line, black
  flicker) — these are exactly the bugs the patch fixes; ensure both the
  `Renderer.cpp` and `OpenGL.cpp` hunks applied (they're required together).