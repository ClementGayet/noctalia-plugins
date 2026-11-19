local function render(status)
    panel.render(ui.column({ padding = 14, gap = 10 }, {
        ui.label({ text = "Tiling Preview", fontSize = 19, fontWeight = "semibold" }),
        ui.label({
            text = "Super + left drag a tiled window. The highlighted area is where it will land.",
            maxWidth = 328, maxLines = 3,
        }),
        ui.label({
            text = "Vertical Rows stacks windows full-width from top to bottom.",
            maxWidth = 328, maxLines = 3, color = "on_surface_variant",
        }),
        ui.label({ text = status, fontSize = 12, color = "on_surface_variant" }),
    }))
end

function onOpen()
    render("Checking Hyprland…")
    local query = 'function() for _, plugin in ipairs(hl.get_loaded_plugins()) do ' ..
        'if plugin.name == "tiling-preview" then return true end end return false end'
    local started = noctalia.runAsync({ "hyprctl", "repl", "(" .. query .. ")()" }, function(result)
        if result.exitCode ~= 0 then
            render("Could not check Hyprland.")
        elseif result.stdout:match("^%s*true%s*$") then
            render("Hyprland plugin active.")
        else
            render("Hyprland plugin unavailable.")
        end
    end)
    if not started then render("Could not check Hyprland.") end
end
