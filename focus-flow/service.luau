local state = require("./lib/state.luau")
local data = state.load()

local function setting(key, fallback)
    local value = tonumber(noctalia.getConfig(key))
    return value and math.floor(value) or fallback
end

local function durations()
    return setting("focus_minutes", 25), setting("short_break_minutes", 5),
        setting("long_break_minutes", 15), setting("sessions_until_long_break", 4)
end

local function publish()
    state.save(data)
end

noctalia.state.watch("data", function(value)
    if type(value) == "table" then data = value end
end)

noctalia.setUpdateInterval(1000)
publish()

function update()
    local today = os.date("%Y-%m-%d")
    if data.day ~= today then
        data.day = today
        data.sessionsToday = 0
        data.focusSecondsToday = 0
        for _, task in ipairs(data.tasks) do task.doneToday = false end
        publish()
    end

    if not data.running or data.endsAt > math.floor(noctalia.nowMs() / 1000) then return end

    local _, shortMinutes, longMinutes, every = durations()
    data.running = false
    data.endsAt = 0
    if data.phase == "focus" then
        data.sessionsToday += 1
        data.focusSecondsToday += setting("focus_minutes", 25) * 60
        state.nextBreak(data, longMinutes, shortMinutes, every)
        noctalia.notify("Focus session complete", "Time for a " .. (data.phase == "long_break" and "long" or "short") .. " break.")
    else
        data.phase = "focus"
        data.remaining = setting("focus_minutes", 25) * 60
        noctalia.notify("Break complete", "Ready for another focus session?")
    end
    publish()
end
