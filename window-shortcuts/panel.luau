local function shortcut(keys, action)
    return ui.row({ align = "center", justify = "space_between", gap = 8, minHeight = 24 }, {
        ui.label({ text = action }),
        ui.label({ text = keys, color = "on_surface_variant" }),
    })
end

function onOpen()
    panel.render(ui.column({ padding = 14, gap = 8 }, {
        ui.label({ text = "Window Shortcuts", fontSize = 19, fontWeight = "semibold" }),
        shortcut("Alt + Tab", "Switch forward"),
        shortcut("Alt + Shift + Tab", "Switch backward"),
        shortcut("Alt + F4", "Close focused window"),
        ui.button({
            text = "Open Window Switcher", glyph = "apps", variant = "ghost",
            onClick = function()
                noctalia.runAsync({ "noctalia", "msg", "window-switcher" })
            end,
        }),
    }))
end
