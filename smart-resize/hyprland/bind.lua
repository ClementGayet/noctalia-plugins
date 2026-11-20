local data_home = os.getenv("XDG_DATA_HOME")
if not data_home or data_home == "" then
    data_home = os.getenv("HOME") .. "/.local/share"
end
local path = data_home .. "/hyprland/plugins/smart-resize.so"
local library = io.open(path, "rb")
if library then
    library:close()
    hl.plugin.load(path)
end

local native_resize = hl.dsp.window.resize()
local function resize()
    local plugin = hl.plugin.smart_resize
    if plugin and plugin.drag then return plugin.drag() end
    return native_resize()
end

hl.bind("SUPER + mouse:273", resize, { mouse = true, description = "Resize the window under the pointer" })
hl.bind("SUPER + R", resize, { description = "Resize the window under the pointer with the keyboard" })
