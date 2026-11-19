return function(portraitOutput)
    local dataHome = os.getenv("XDG_DATA_HOME")
    if not dataHome or dataHome == "" then
        dataHome = os.getenv("HOME") .. "/.local/share"
    end
    local path = dataHome .. "/hyprland/plugins/tiling-preview.so"
    local library = io.open(path, "rb")
    if not library then return end
    library:close()

    hl.plugin.load(path)
    hl.config({ dwindle = { precise_mouse_move = true } })
    if portraitOutput then
        hl.workspace_rule({ workspace = "m[" .. portraitOutput .. "]", layout = "vertical-rows" })
    end
end
