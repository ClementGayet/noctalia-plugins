# Tiling Preview

Hold **Super** and drag a tiled window with the left mouse button. A translucent highlight marks its destination in Dwindle and Vertical Rows. Floating windows move freely. The highlight follows pointer-driven Dwindle splits and turns off when you release the window.

**Vertical Rows** gives every tiled window a full-width row of equal height. Drag above or below another row to reorder, or use **Super + Shift + Up/Down**. Three windows produce three visible rows in one column.

## Hyprland setup

Build against headers matching the running Hyprland with `make install`. After a Hyprland upgrade, rebuild with `make -B install`.

Call the setup module from `hyprland.lua` with the portrait display's connector:

```lua
dofile("/absolute/path/to/tiling-preview/hyprland/setup.lua")("DP-2")
```

The setup uses pointer-driven drop directions in Dwindle. Omit the connector to enable the preview without assigning Vertical Rows to an output. Noctalia's **Tiling Preview** panel reports whether the Hyprland component is active.
