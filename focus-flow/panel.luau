local state = require("./lib/state.luau")
local data = state.load()
local draft = ""

local function setting(key, fallback)
    local value = tonumber(noctalia.getConfig(key))
    return value and math.floor(value) or fallback
end

local function durationFor(phase)
    if phase == "short_break" then return setting("short_break_minutes", 5) * 60 end
    if phase == "long_break" then return setting("long_break_minutes", 15) * 60 end
    return setting("focus_minutes", 25) * 60
end

local function save()
    state.save(data)
end

local function phaseName()
    if data.phase == "short_break" then return "Short break" end
    if data.phase == "long_break" then return "Long break" end
    return "Focus session"
end

local function render()
    local remaining = state.remaining(data)
    local progress = 1 - remaining / math.max(1, durationFor(data.phase))
    local tasks = {}
    local visible = 0
    for _, task in ipairs(data.tasks) do
        if not task.doneToday then
            visible += 1
            table.insert(tasks, ui.row({ key = "task-" .. task.id, gap = 8, align = "center" }, {
                ui.button({
                    glyph = "check", variant = "ghost", tooltip = "Complete task",
                    onClick = function()
                        task.doneToday = true
                        task.doneCount = (task.doneCount or 0) + 1
                        save()
                        render()
                    end,
                }),
                ui.label({ text = task.title, maxLines = 1, flexGrow = 1 }),
                ui.button({
                    glyph = "x", variant = "ghost", tooltip = "Remove task",
                    onClick = function()
                        for index, item in ipairs(data.tasks) do
                            if item.id == task.id then table.remove(data.tasks, index); break end
                        end
                        save()
                        render()
                    end,
                }),
            }))
        end
    end
    if visible == 0 then
        table.insert(tasks, ui.label({ text = "Your task list is clear.", color = "on_surface_variant" }))
    end

    panel.render(ui.column({ gap = 12, padding = 4 }, {
        ui.row({ align = "center", justify = "space_between" }, {
            ui.column({ gap = 2 }, {
                ui.label({ text = "Focus Flow", fontSize = 17, fontWeight = "bold" }),
                ui.label({ text = phaseName(), color = "on_surface_variant" }),
            }),
            ui.label({ text = tostring(data.sessionsToday) .. " sessions today", color = "on_surface_variant" }),
        }),
        ui.column({ gap = 8, padding = 14, fill = "surface_container_high/0.72", radius = 12 }, {
            ui.label({ text = state.format(remaining), fontSize = 34, fontWeight = "bold", textAlign = "center" }),
            ui.progress({ progress = progress, height = 5, fill = "primary", track = "surface_variant" }),
            ui.row({ gap = 8, justify = "center" }, {
                ui.button({
                    text = data.running and "Pause" or "Start",
                    glyph = data.running and "player-pause" or "player-play",
                    variant = "primary",
                    onClick = function()
                        local now = math.floor(noctalia.nowMs() / 1000)
                        if data.running then
                            data.remaining = math.max(0, data.endsAt - now)
                            data.running = false
                            data.endsAt = 0
                        else
                            if data.remaining <= 0 then data.remaining = durationFor(data.phase) end
                            data.running = true
                            data.endsAt = now + data.remaining
                        end
                        save()
                        render()
                    end,
                }),
                ui.button({
                    glyph = "rotate", variant = "outline", tooltip = "Reset timer",
                    onClick = function()
                        data.running = false
                        data.endsAt = 0
                        data.remaining = durationFor(data.phase)
                        save()
                        render()
                    end,
                }),
                ui.button({
                    glyph = "player-skip-forward", variant = "outline", tooltip = "Skip phase",
                    onClick = function()
                        if data.phase == "focus" then
                            state.nextBreak(data, setting("long_break_minutes", 15),
                                setting("short_break_minutes", 5), setting("sessions_until_long_break", 4))
                        else
                            data.phase = "focus"
                            data.remaining = setting("focus_minutes", 25) * 60
                        end
                        data.running = false
                        data.endsAt = 0
                        save()
                        render()
                    end,
                }),
            }),
        }),
        ui.row({ align = "center", justify = "space_between" }, {
            ui.label({ text = "Today", fontWeight = "semibold" }),
            ui.label({ text = string.format("%dh %02dm focused", math.floor(data.focusSecondsToday / 3600),
                math.floor(data.focusSecondsToday % 3600 / 60)), color = "on_surface_variant" }),
        }),
        ui.row({ align = "center", justify = "space_between" }, {
            ui.label({ text = "Tasks", fontWeight = "semibold" }),
            ui.label({ text = tostring(visible) .. " remaining · " .. tostring(#data.tasks - visible) .. " done",
                color = "on_surface_variant" }),
        }),
        ui.column({ gap = 2 }, tasks),
        ui.row({ gap = 6, align = "center" }, {
            ui.input({
                key = "new-task", value = draft, placeholder = "Add a task for today", flexGrow = 1,
                onChange = function(value) draft = value end,
                onSubmit = "addTask",
            }),
            ui.button({ glyph = "plus", variant = "primary", tooltip = "Add task", onClick = "addTask" }),
        }),
    }))
end

function addTask()
    local title = noctalia.string.trim(draft)
    if title == "" then return end
    table.insert(data.tasks, { id = data.nextTaskId, title = title, doneToday = false, doneCount = 0 })
    data.nextTaskId += 1
    draft = ""
    save()
    render()
end

noctalia.setUpdateInterval(1000)
noctalia.state.watch("data", function(value)
    if type(value) == "table" then data = value; render() end
end)

function onOpen()
    data = state.load()
    render()
end

function update()
    render()
end
