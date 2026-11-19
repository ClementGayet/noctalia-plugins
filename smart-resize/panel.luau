local function render(status)
    panel.render(ui.column({ padding = 14, gap = 10 }, {
        ui.label({ text = "Smart Resize", fontSize = 20, fontWeight = "semibold" }),
        ui.label({ text = "Super + R  or  Super + right drag", fontWeight = "semibold" }),
        ui.label({
            text = "Start inside the window. The side or corner nearest the cursor follows your drag.",
            maxWidth = 310, maxLines = 3, color = "on_surface_variant",
        }),
        ui.label({
            text = status, maxWidth = 310, maxLines = 2, fontSize = 12, color = "on_surface_variant",
        }),
    }))
end

function onOpen()
    render("Checking Hyprland…")
    local started = noctalia.runAsync({
        "hyprctl", "repl", 'type(hl.plugin.smart_resize) == "table" and type(hl.plugin.smart_resize.drag) == "function"',
    }, function(result)
        if result.exitCode ~= 0 then
            render("Could not check Hyprland.")
        elseif result.stdout:match("^%s*true%s*$") then
            render("Edge and corner resizing is active.")
        else
            render("Hyprland’s standard corner resizing is active.")
        end
    end)
    if not started then render("Could not check Hyprland.") end
end
