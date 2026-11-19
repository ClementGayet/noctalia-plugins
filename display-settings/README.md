# Display Settings

Open **Displays** from the bar or from the Control Center Home shortcut. In **Arrangement**, pick a reference monitor and drag another display onto one of its four sides. Clicking a side moves the selected display. The panel saves and verifies the layout using the Hyprland backend in `bin/desktop-displays`.

The backend expects a Hyprland Lua configuration that loads `display-layout.lua` and `display-workspaces.lua`. The latter is in `hyprland/` and reads the generated `display-workspace-preferences.lua`. Keep those two generated files in the Hyprland configuration directory. They hold this machine’s monitor layout and preferences.

The backend uses Python 3 and `hyprctl`. Noctalia's built-in Monitor tab handles brightness.
