local backend = { noctalia.pluginDir() .. "/bin/desktop-displays", "--noctalia-plugin" }
local displays = {}
local selected = nil
local reference = nil
local page = "Display"
local busy = false
local isOpen = false
local message = ""
local render

local function refresh(args)
    if busy then return end
    busy = true
    message = ""
    render()
    local command = { backend[1], backend[2] }
    for _, arg in ipairs(args) do
        table.insert(command, arg)
    end
    local started = noctalia.runAsync(command, function(result)
        busy = false
        if result.exitCode == 0 then
            local ok, state = pcall(noctalia.json.decode, result.stdout)
            if ok and type(state) == "table" and type(state.displays) == "table" then
                displays = state.displays
            else
                message = "Display Settings returned an unreadable display list."
            end
        else
            message = (result.stderr or ""):match("^%s*(.-)%s*$")
            if message == "" then message = "Could not read or update the displays." end
        end
        if isOpen then render() end
    end)
    if not started then
        busy = false
        message = "Could not start Display Settings."
        render()
    end
end

local function set(screen, property, value)
    refresh({ "set", screen.name, property, value })
end

local function selectControl(key, values, current, onChange, width)
    local labels = {}
    local active = -1
    for index, item in ipairs(values) do
        table.insert(labels, item[2])
        if item[1] == current then active = index - 1 end
    end
    return ui.select({
        key = key, options = labels, selectedIndex = active, width = width,
        controlSize = "sm", enabled = not busy,
        onChange = function(index)
            local offset = tonumber(index)
            local item = offset and values[offset + 1]
            if item and item[1] ~= current then onChange(item[1]) end
        end,
    })
end

local function field(label, control)
    return ui.row({ gap = 8, align = "center", justify = "space_between", minHeight = 32 }, {
        ui.label({ text = label, color = "on_surface_variant" }), control,
    })
end

local function switch(screen, label, property, checked, enabled)
    return field(label, ui.toggle({
        key = screen.name .. "-" .. property, checked = checked, enabled = not busy and enabled,
        onChange = function(value)
            local turnedOn = tostring(value) == "true"
            if turnedOn ~= checked then set(screen, property, turnedOn and "on" or "off") end
        end,
    }))
end

local function card(rows)
    return ui.column({ padding = 10, gap = 6, radius = 10, fill = "surface_container_high/0.65" }, rows)
end

local function note(text, color)
    return ui.label({ text = text, fontSize = 12, maxLines = 4, color = color or "on_surface_variant" })
end

local function displayControls(screen, enabledCount)
    local prefix = screen.name .. "-"
    local extended = screen.enabled and screen.mirror == ""
    local rows = {
        switch(screen, "Enabled", "enabled", screen.enabled, not screen.enabled or enabledCount > 1),
        switch(screen, "Primary display", "primary", screen.primary, screen.primary or extended),
        switch(screen, "Dedicated workspace", "dedicated", screen.dedicated, screen.dedicated or extended),
    }
    if screen.enabled and enabledCount == 1 then
        table.insert(rows, note("At least one display must stay enabled."))
    end
    if screen.primary and screen.dedicated then
        table.insert(rows, note("Numbered workspaces switch on another display."))
    end
    local cards = { card(rows) }
    if screen.enabled then
        local modes = {}
        for _, mode in ipairs(screen.modes) do
            local label = mode:gsub("x", " × "):gsub("@", " · ") .. " Hz"
            table.insert(modes, { mode, label })
        end
        local picture = {}
        if #modes > 0 then
            table.insert(picture, field("Resolution", selectControl(prefix .. "mode", modes, screen.mode,
                function(value) set(screen, "mode", value) end, 198)))
        end
        if #screen.scale_options > 0 then
            local scales = {}
            for _, scale in ipairs(screen.scale_options) do
                table.insert(scales, { scale, string.format("%.4g×", scale) })
            end
            table.insert(picture, field("Scale", selectControl(prefix .. "scale", scales, screen.scale,
                function(value) set(screen, "scale", string.format("%.17g", value)) end, 198)))
            table.insert(picture, field("Rotation", selectControl(prefix .. "rotation", {
                { 0, "Normal" }, { 1, "90°" }, { 2, "180°" }, { 3, "270°" },
            }, screen.transform, function(value) set(screen, "rotation", tostring(value)) end, 198)))
        end
        if #picture > 0 then table.insert(cards, card(picture)) end
    end
    return cards
end

function onDisplayDrop(name, destination)
    local direction, anchor = destination:match("^([a-z]+)|([%w._-]+)$")
    if busy or not direction or name == anchor then return end
    selected = name
    reference = anchor
    refresh({ "set", name, direction, anchor })
end

local function arrangementMap(screen, anchor)
    local tiles = {}
    local currentRow = {}
    for _, display in ipairs(displays) do
        if display.name ~= anchor and type(display.rect) == "table" then
            table.insert(currentRow, ui.dragSource({
                key = "display-tile-" .. display.name, dragType = "display", payload = display.name,
                tooltip = "Drag " .. display.name, enabled = not busy, flexGrow = 1, height = 36,
                fill = display.name == screen.name and "primary_container" or "surface_container_high",
                radius = 7, align = "center", justify = "center",
                onClick = function()
                    selected = display.name
                    render()
                end,
            }, { ui.label({ text = display.name, fontWeight = "semibold" }) }))
            if #currentRow == 3 then
                table.insert(tiles, ui.row({ gap = 6 }, currentRow))
                currentRow = {}
            end
        end
    end
    if #currentRow > 0 then table.insert(tiles, ui.row({ gap = 6 }, currentRow)) end

    local function dropZone(direction, label, glyph)
        return ui.dropZone({
            key = "display-target-" .. direction, value = direction .. "|" .. anchor,
            accepts = { "display" }, onDrop = "onDisplayDrop", enabled = not busy,
            width = 106, height = 34, fill = "surface_container_high", radius = 7,
        }, { ui.button({
            text = label, glyph = glyph, variant = "ghost", enabled = not busy,
            controlSize = "sm", flexGrow = 1,
            onClick = function() onDisplayDrop(screen.name, direction .. "|" .. anchor) end,
        }) })
    end
    local row = { gap = 6, align = "center", justify = "center" }
    local anchorTile = ui.column({
        width = 106, height = 34, radius = 7, fill = "surface_container",
        align = "center", justify = "center",
    }, { ui.label({ text = anchor, fontWeight = "semibold" }) })
    table.insert(tiles, ui.row(row, { dropZone("above", "Above", "arrow-up") }))
    table.insert(tiles, ui.row(row, {
        dropZone("left", "Left", "arrow-left"), anchorTile, dropZone("right", "Right", "arrow-right"),
    }))
    table.insert(tiles, ui.row(row, { dropZone("below", "Below", "arrow-down") }))
    return ui.column({ gap = 6 }, tiles)
end

local function arrangementControls(screen)
    if not screen.enabled then return note("Enable this display to arrange it.") end
    local prefix = screen.name .. "-"
    local rows = {}
    local sources = { { "", "Extend" } }
    local neighbors = {}
    local referenceExists = false
    for _, other in ipairs(displays) do
        if other.name ~= screen.name and other.enabled and other.mirror == "" then
            table.insert(sources, { other.name, "Mirror " .. other.name })
            if type(other.rect) == "table" then
                table.insert(neighbors, { other.name, other.name })
                referenceExists = referenceExists or reference == other.name
            end
        end
    end
    if #sources > 1 or screen.mirror ~= "" then
        table.insert(rows, field("Layout", selectControl(prefix .. "mirror", sources, screen.mirror,
            function(value) set(screen, "mirror", value) end, 198)))
    end

    if type(screen.rect) == "table" and #neighbors > 0 then
        if not referenceExists then reference = neighbors[1][1] end
        table.insert(rows, field("Relative to", selectControl(prefix .. "reference", neighbors, reference,
            function(value)
                reference = value
                render()
            end, 198)))
        table.insert(rows, note("Drag a display to a side of " .. reference .. "."))
        table.insert(rows, arrangementMap(screen, reference))
    end
    if #rows == 0 then return note("Connect another display to arrange your desktop.") end
    return card(rows)
end

render = function()
    local screen = nil
    local enabledCount = 0
    for _, item in ipairs(displays) do
        if item.name == selected then screen = item end
        if item.enabled then enabledCount = enabledCount + 1 end
    end
    if not screen then
        for _, item in ipairs(displays) do
            if item.focused then screen = item break end
        end
        screen = screen or displays[1]
    end
    selected = screen and screen.name

    local content = {
        ui.row({ gap = 8, align = "center", justify = "space_between" }, {
            ui.label({ text = "Displays", fontSize = 19, fontWeight = "semibold" }),
            ui.button({ glyph = "refresh", tooltip = "Refresh displays", variant = "ghost",
                enabled = not busy, onClick = function() refresh({ "inspect" }) end }),
        }),
    }
    if screen then
        local options = {}
        for _, item in ipairs(displays) do
            local suffix = item.enabled and "" or " · Disabled"
            local label = item.label == item.name and item.name or item.label .. " · " .. item.name
            table.insert(options, { item.name, label .. suffix })
        end
        table.insert(content, selectControl("display", options, selected, function(value)
            selected = value
            reference = nil
            render()
        end))
        local tabs = {}
        for _, label in ipairs({ "Display", "Arrangement" }) do
            table.insert(tabs, ui.button({
                text = label, flexGrow = 1, controlSize = "sm", variant = "ghost",
                selected = page == label, enabled = not busy,
                onClick = function()
                    page = label
                    render()
                end,
            }))
        end
        table.insert(content, ui.row({ gap = 4, padding = 3, radius = 8, fill = "surface_container" }, tabs))
        if page == "Display" then
            for _, group in ipairs(displayControls(screen, enabledCount)) do
                table.insert(content, group)
            end
        else
            table.insert(content, arrangementControls(screen))
        end
    elseif not busy and message == "" then
        table.insert(content, note("No displays detected."))
    end

    if busy or message ~= "" then
        table.insert(content, note(busy and "Checking displays…" or message, busy and "on_surface_variant" or "error"))
    end
    table.insert(content, ui.row({ justify = "space_between" }, {
        ui.button({
            text = "Brightness", glyph = "sun", variant = "ghost", controlSize = "sm", enabled = not busy,
            onClick = function()
                noctalia.runAsync({ "noctalia", "msg", "panel-open", "control-center", "monitor" })
            end,
        }),
    }))
    panel.render(ui.scroll({ padding = 10, gap = 8, flexGrow = 1 }, content))
end

function onOpen()
    isOpen = true
    page = "Display"
    if busy then render() else refresh({ "inspect" }) end
end

function onClose()
    isOpen = false
end
