local M = {}

local function today()
    return os.date("%Y-%m-%d")
end

function M.defaults()
    return {
        phase = "focus",
        running = false,
        remaining = 25 * 60,
        endsAt = 0,
        sessionsToday = 0,
        focusSecondsToday = 0,
        day = today(),
        nextTaskId = 1,
        tasks = {},
    }
end

function M.load()
    local data = noctalia.state.get("data")
    if type(data) ~= "table" then
        local dir = noctalia.pluginDataDir()
        if dir then
            local raw = noctalia.readFile(dir .. "/focus-flow.json")
            if raw then
                local ok, decoded = pcall(noctalia.json.decode, raw)
                if ok and type(decoded) == "table" then data = decoded end
            end
        end
    end
    if type(data) ~= "table" then data = M.defaults() end
    if type(data.tasks) ~= "table" then data.tasks = {} end
    if type(data.sessionsToday) ~= "number" then data.sessionsToday = 0 end
    if type(data.focusSecondsToday) ~= "number" then data.focusSecondsToday = 0 end
    if type(data.nextTaskId) ~= "number" then data.nextTaskId = 1 end
    if type(data.phase) ~= "string" then data.phase = "focus" end
    if type(data.running) ~= "boolean" then data.running = false end
    if type(data.remaining) ~= "number" then data.remaining = 25 * 60 end
    if type(data.endsAt) ~= "number" then data.endsAt = 0 end
    if data.day ~= today() then
        data.day = today()
        data.sessionsToday = 0
        data.focusSecondsToday = 0
        for _, task in ipairs(data.tasks) do task.doneToday = false end
    end
    return data
end

function M.save(data)
    noctalia.state.set("data", data)
    local dir = noctalia.pluginDataDir()
    if not dir then return end
    local encoded = noctalia.json.encode(data, true)
    if encoded then noctalia.writeFile(dir .. "/focus-flow.json", encoded) end
end

function M.duration(data, focusMinutes, shortMinutes, longMinutes, every)
    if data.phase == "short_break" then return shortMinutes * 60 end
    if data.phase == "long_break" then return longMinutes * 60 end
    return focusMinutes * 60
end

function M.nextBreak(data, longMinutes, shortMinutes, every)
    if data.sessionsToday > 0 and data.sessionsToday % every == 0 then
        data.phase = "long_break"
        data.remaining = longMinutes * 60
    else
        data.phase = "short_break"
        data.remaining = shortMinutes * 60
    end
end

function M.format(seconds)
    seconds = math.max(0, math.floor(seconds or 0))
    return string.format("%02d:%02d", math.floor(seconds / 60), seconds % 60)
end

function M.remaining(data)
    if data.running then return math.max(0, data.endsAt - math.floor(noctalia.nowMs() / 1000)) end
    return math.max(0, data.remaining)
end

return M
