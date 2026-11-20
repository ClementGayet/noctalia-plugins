local state = require("./lib/state.luau")
local data = state.load()

local labels = {
    focus = "Focus",
    short_break = "Short break",
    long_break = "Long break",
}

local function render()
    local seconds = state.remaining(data)
    local remaining = 0
    for _, task in ipairs(data.tasks or {}) do
        if not task.doneToday then
            remaining += 1
        end
    end
    local tasks = remaining == 1 and "1 task left" or tostring(remaining) .. " tasks left"
    barWidget.setTooltip((labels[data.phase] or "Focus") .. " · " .. state.format(seconds)
        .. (data.running and " remaining" or " · paused") .. " · " .. tasks)
end

barWidget.setGlyph("stopwatch")
barWidget.setText("")
noctalia.setUpdateInterval(1000)
noctalia.state.watch("data", function(value)
    if type(value) == "table" then data = value; render() end
end)

function update()
    data = state.load()
    render()
end

function onClick()
    noctalia.togglePanel("clementgayet/focus-flow:panel")
end

function onRightClick()
    noctalia.togglePanel("clementgayet/focus-flow:panel")
end

render()
