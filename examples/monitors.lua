-- Example Multi-Monitor Setup with TV Overscan Compensation
-- Hardware: Laptop internal display + AKAI LED22D20 Dx 22" 1080p TV
-- Tested on: Hyprland v0.56.2 with hyprland-overscan patch

-- Global environment scales (optional, adjust for your toolkit)
local omarchy_gdk_scale = 1
local omarchy_monitor_scale = 1.25

hl.env("GDK_SCALE", tostring(omarchy_gdk_scale))

-- Default fallback rule for any newly plugged monitor
hl.monitor({
    output = "",
    mode = "preferred",
    position = "auto",
    scale = omarchy_monitor_scale,
})

--------------------------------------------------------------------------------
-- 1. Laptop Internal Display (eDP-1)
-- 1080p IPS panel with 1.25x scaling for comfortable UI sizing
--------------------------------------------------------------------------------
hl.monitor({
    output = "eDP-1",
    mode = "1920x1080@60.00Hz",
    position = "1920x0",
    scale = 1.25,
    transform = 0,
})

--------------------------------------------------------------------------------
-- 2. Television with Hardware Overscan (HDMI-A-1)
-- Device: AKAI LED22D20 Dx (56cm / 22" Full HD LED TV)
-- EDID identifier: GDH CHHWJT 0x01000000
--
-- Why overscan margins are needed:
-- This TV lacks a "Just Scan" / 1:1 pixel mapping mode in its firmware menus.
-- Without margins, ~50px on the sides and ~30px on top/bottom are cropped out,
-- cutting off the top bar (waybar) and terminal edges.
--
-- Supported modes reported by EDID:
--   1920x1080 @ 59.94Hz (preferred TV broadcast timing)
--   1920x1080 @ 50.00Hz, 29.97Hz, 25.00Hz, 23.98Hz
--   1280x720  @ 60.00Hz, 59.94Hz, 50.00Hz
--   1024x768  @ 60.00Hz
--------------------------------------------------------------------------------
hl.monitor({
    output = "HDMI-A-1",
    mode = "1920x1080@59.93900",
    position = "3456x0",
    scale = 1,
    transform = 0,

    -- Overscan margins in physical pixels:
    -- Inset ~2.6% horizontally and ~2.8% vertically
    overscan_l = 50,
    overscan_r = 50,
    overscan_t = 30,
    overscan_b = 30,
})
