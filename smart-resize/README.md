# Smart Resize

Hold **Super** and drag with the **right mouse button** anywhere inside a window. You can also hold **Super + R** while moving the pointer. Start in a corner of the window to resize both dimensions, or in the middle third of a side to resize along that axis. A drag from the center uses the closest edge. The cursor shows which direction was selected.

Floating windows resize directly. Tiled windows follow the available splits in the active Hyprland layout.

## Build for Hyprland

Install a C++23 compiler, `make`, `pkg-config`, and headers matching the running Hyprland. From this directory:

```sh
make install
```

Load `hyprland/bind.lua` with `require("/absolute/path/to/smart-resize/hyprland/bind.lua")` from your Hyprland configuration so Hyprland watches the file for changes. Remove any other binds for these gestures. Edit that file to customize the shortcuts. The module loads the shared library from your XDG data directory and falls back to Hyprland's standard corner resize when the library is unavailable. After a Hyprland upgrade, rebuild with `make -B install`.

The Noctalia panel shows the gesture and whether the Hyprland component is active. Find **Smart Resize** in Noctalia's Panels launcher, or open it with `noctalia msg panel-toggle clementgayet/smart-resize:panel`.
