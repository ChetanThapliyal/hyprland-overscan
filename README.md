# Hyprland Overscan / Underscan Patch

Per-monitor overscan compensation for Hyprland on displays (especially TVs) that crop image edges.

This repository provides a patch and build instructions for Hyprland **v0.56.2** (commit `efb50993`). It builds upon the upstream overscan implementation started by [@vaxerski](https://github.com/vaxerski) in [hyprwm/Hyprland#11464](https://github.com/hyprwm/Hyprland/pull/11464) and resolves the damage tracking issues that prevented the original PR from merging.

---

## The problem

Many TVs and older monitors have hardware overscan enabled by default and lack a menu toggle to disable it (often labeled "Just Scan", "1:1", "Screen Fit", or "PC Mode"). When connected over HDMI, these displays crop 2% to 10% around the perimeter:
- Taskbars, waybars, and top bars are cut off or hidden.
- Window borders and title bars disappear off the edge.
- Notification popups and terminal edges cannot be read.

Because Wayland compositors own the display output pipeline directly, overscan must be corrected at the compositor level by shrinking the rendered framebuffer and padding the outer margins with black.

---

## What this patch does

This patch introduces four per-monitor options (`overscan_t`, `overscan_b`, `overscan_l`, `overscan_r`) that inset the composited output by an exact pixel count on each side:

```
+---------------------------------------------------+
|               overscan_t (black margin)           |
|   +-------------------------------------------+   |
|   |                                           |   |
| l |             Rendered Desktop              | r |
|   |                                           |   |
|   +-------------------------------------------+   |
|               overscan_b (black margin)           |
+---------------------------------------------------+
```

### Supported configuration syntax

The patch supports both Hyprland configuration styles:

#### 1. Lua configuration (`~/.config/hypr/hyprland.lua` or `monitors.lua`)

```lua
hl.monitor({
    name = "HDMI-A-1",
    mode = "1920x1080@60",
    position = "1920x0",
    scale = 1,
    transform = 0,
    overscan_t = 16,
    overscan_b = 16,
    overscan_l = 24,
    overscan_r = 24,
})
```

#### 2. Legacy configuration (`~/.config/hypr/hyprland.conf`)

```ini
monitorv2 = HDMI-A-1, 1920x1080@60, 1920x0, 1, {
    overscan_t = 16,
    overscan_b = 16,
    overscan_l = 24,
    overscan_r = 24,
}
```

Values are integers representing pixels inset from each edge (range: `0` to `9999`). Changes reload dynamically when monitor rules re-evaluate.

---

## The upstream bug and how this patch fixes it

Upstream PR [#11464](https://github.com/hyprwm/Hyprland/pull/11464) (authored by `@vaxerski` against issue [#11462](https://github.com/hyprwm/Hyprland/issues/11462)) introduced the initial `squish` approach but was held up due to rendering artifacts:
> *"Issues: [ ] some damage issues (open 1 window and close it, trails behind)"*

### Root cause
The original code in `OpenGL.cpp` scaled and translated `m_renderData.damage` and `m_renderData.finalDamage` to map partial screen damage onto the inset box. In Hyprland, damage serves two coupled purposes:
1. The OpenGL scissor box for the final composite blit.
2. The Wayland/DRM swapchain present region (`state->addDamage`).

Applying fractional coordinate transforms to discrete damage boxes caused rounding errors and misaligned scissors. This manifested as ghost rectangular boxes trailing the mouse cursor, horizontal seam lines, and black flicker when windows opened or closed.

### The fix
1. **Full-frame damage for overscan monitors (`src/render/Renderer.cpp`)**: When `pMonitor->m_activeMonitorRule.hasOverscan()` is true, `renderMonitor()` forces a full-frame damage region. This guarantees a complete frame composite every tick, avoiding fractional scissor boundaries.
2. **Scissored border clear (`src/render/OpenGL.cpp`)**: Rather than transforming damage boxes, `OpenGL.cpp` preserves the original monitor geometry, squishes `monbox` inward, and clears only the border strip using region subtraction:
   ```cpp
   m_renderData.damage = CRegion{OLD_MONBOX}.subtract(CRegion{monbox});
   renderRect(OLD_MONBOX, Colors::BLACK, {});
   ```
   It then marks the full panel presented so no stale buffer contents leak through.
3. **Software cursor fallback (`src/output/Monitor.cpp`)**: `CMonitor::shouldUseSoftwareCursors()` returns `true` on monitors with overscan. Hardware KMS cursor planes cannot be clipped or offset into the squished box without display-controller plane scaling hacks. Software cursors ensure the cursor stays within the scaled boundary and renders accurately.
4. **Full config integration**: Adds Lua config bindings (`LuaBindingsConfigRules.cpp`), legacy parser support (`ConfigManager.cpp`), and soft-comparison rules (`MonitorRule.cpp`) so live changes immediately take effect.

---

## Trade-offs and performance impact

Before applying this patch, consider the following technical trade-offs:

1. **Per-frame redraw on the affected monitor**:
   Because sparse damage tracking is bypassed on the overscan display, that monitor redraws its full frame whenever a visual update occurs. For 60 Hz TVs this overhead is negligible, but it prevents partial damage power optimizations on that output.
2. **Software cursor overhead**:
   The cursor on the overscan monitor is drawn using the software renderer instead of a dedicated hardware plane.
3. **No degradation on standard monitors**:
   Displays without overscan are completely unaffected. Hardware cursors and sparse damage tracking operate normally on your primary monitors, laptops, and gaming displays.

---

## How to install

These steps are tested on Arch Linux, CachyOS, and EndeavourOS.

### 1. Install build dependencies

```bash
sudo pacman -S --needed base-devel cmake meson ninja git \
  hyprutils hyprlang hyprcursor hyprgraphics hyprwayland-scanner aquamarine hyprwire \
  wayland wayland-protocols libdrm mesa pixman libdisplay-info \
  cairo pango libxkbcommon tomlplusplus re2
```

> **Note**: `hyprutils` and companion libraries must match the requirements for Hyprland v0.56.2. If CMake reports version mismatches, ensure your system packages are up to date via `sudo pacman -Syu`.

### 2. Clone Hyprland v0.56.2 and apply the patch

```bash
# Clone Hyprland with all required submodules
git clone --recurse-submodules --branch v0.56.2 https://github.com/hyprwm/Hyprland.git /tmp/hyprland-build
cd /tmp/hyprland-build

# Apply the overscan patch
git apply /path/to/hyprland-overscan/overscan-backport.patch
```

### 3. Build and install to `/usr/local`

Installing to `/usr/local` avoids conflicts with files tracked by `pacman`:

```bash
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local
cmake --build build --config Release --target all -j$(nproc)
sudo cmake --install build
```

This places the patched binaries at `/usr/local/bin/Hyprland` and `/usr/local/bin/hyprctl`.

### 4. Verify the active binary

Because `/usr/local/bin` precedes `/usr/bin` in default Linux `$PATH` settings, logging out and back in will automatically run the patched build.

To verify:
```bash
which Hyprland
# Expected output: /usr/local/bin/Hyprland

hyprctl version
```

---

## Updating Hyprland after applying this patch

Understanding how your local install interacts with system updates:

### Routine system updates (`pacman -Syu`)
When your package manager updates the distro `hyprland` package, it writes files to `/usr/bin/Hyprland`. Because your patched build lives in `/usr/local/bin/`, **pacman will not overwrite your patched binary**. You will continue running the overscan-enabled version across system updates.

### Upgrading to a newer Hyprland release
When a new upstream version of Hyprland is released and you want to upgrade:

1. Check if upstream has merged overscan support natively (see [PR #11464](https://github.com/hyprwm/Hyprland/pull/11464)). If it has, remove the local build (see below) and use the official package.
2. If overscan is still unmerged:
   ```bash
   cd /tmp/hyprland-build
   git fetch --tags
   git checkout <new-version-tag>
   git submodule update --init --recursive
   git apply /path/to/hyprland-overscan/overscan-backport.patch
   ```
   If any hunks reject due to upstream line changes, adjust the patch against the new tag, re-run `cmake --build`, and `sudo cmake --install`.

### Reverting to stock Hyprland
To remove the patched build and return to the official package:

```bash
sudo rm -f /usr/local/bin/Hyprland /usr/local/bin/hyprctl /usr/local/bin/hyprpm
sudo rm -rf /usr/local/include/hyprland /usr/local/share/hyprland /usr/local/lib/pkgconfig/hyprland.pc
```

Then restart your Hyprland session.

---

## AI usage disclosure

In compliance with the [Hyprland AI Usage Policy](https://github.com/hyprwm/.github/blob/main/policies/AI_USAGE.md):

- **Tools used**: Google DeepMind Antigravity AI coding assistant.
- **Scope of AI involvement**:
  - Investigated the root cause of the damage-tracking artifacts present in upstream PR #11464.
  - Implemented the backport modifications in `src/render/OpenGL.cpp` and `src/render/Renderer.cpp`.
  - Added Lua configuration bindings in `src/config/lua/bindings/LuaBindingsConfigRules.cpp`.
  - Structured documentation and instructions.
- **Human verification**:
  - All source changes were reviewed and verified by a human maintainer.
  - The patch was built from source and tested on physical hardware with an external television display over HDMI to confirm the eradication of cursor ghosting, seam lines, and black flicker.

---

## Upstream status

- **Upstream PR**: [hyprwm/Hyprland#11464](https://github.com/hyprwm/Hyprland/pull/11464) by [@vaxerski](https://github.com/vaxerski)
- **Tracking Issue**: [hyprwm/Hyprland#11462](https://github.com/hyprwm/Hyprland/issues/11462)
- **Discussion**: [hyprwm/Hyprland#10092](https://github.com/hyprwm/Hyprland/discussions/10092)
*Note on upstream contributions*: Hyprland requires contributors to be vouched in [hyprwm/.github discussions](https://github.com/hyprwm/.github/discussions) before opening pull requests, or automated bots close them. Alternatively, collaboration can happen directly on the existing open PR [#11464](https://github.com/hyprwm/Hyprland/pull/11464).

---

## License

This project and patch are released under the [BSD 3-Clause License](LICENSE), matching Hyprland's license. Original overscan logic authored by Vaxry and Hyprland contributors.