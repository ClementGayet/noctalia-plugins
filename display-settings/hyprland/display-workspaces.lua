local preferences = require("display-workspace-preferences")
local primary = preferences.primary
local fixed = {}
local owners = {}
local pending = {}
local M = {}

local function usable(monitor)
    return monitor and monitor.enabled and not monitor.is_mirror
        and monitor.name ~= "FALLBACK" and not monitor.name:match("^HEADLESS%-")
end

local function selector(workspace)
    if not workspace then return nil end
    if workspace.id then return tostring(workspace.id) end
    local address = workspace.addressable_name
    if not address or workspace.special then return address end
    -- Hyprland 0.57 exposes a bare address for named workspaces.
    return "name:" .. address
end

local function monitor_name(workspace)
    local monitor = workspace and workspace.monitor
    return monitor and monitor.name
end

for monitor in pairs(preferences.fixed) do
    local workspace = "name:Display-" .. monitor
    fixed[monitor] = workspace
    owners[workspace] = monitor
    hl.workspace_rule({ workspace = workspace, monitor = monitor, default = true, persistent = true })
end

local function place_fixed(name, keep_windows)
    local monitor = hl.get_monitor(name)
    if not usable(monitor) then return end
    local target = fixed[name]
    local dedicated = hl.get_workspace(target)
    local old = selector(monitor.active_workspace)
    if old == target and monitor_name(dedicated) == name then return monitor end

    local windows = {}
    if keep_windows and old and old == preferences.fixed[name] and not owners[old]
        and (not dedicated or dedicated.is_empty) then
        windows = hl.get_workspace_windows(old)
    end
    -- The monitor method reassigns a workspace even if another output already owns it.
    monitor:set_workspace(target)
    if monitor_name(hl.get_workspace(target)) ~= name then return end
    for _, window in ipairs(windows) do
        hl.dispatch(hl.dsp.window.move({ window = window, workspace = target, follow = false }))
    end
    return monitor
end

local function schedule_repair(name, keep_windows)
    if pending[name] then
        if keep_windows then pending[name].keep_windows = true end
        return
    end
    local request = { keep_windows = keep_windows }
    pending[name] = request
    hl.timer(function()
        pending[name] = nil
        if fixed[name] then
            place_fixed(name, request.keep_windows)
            return
        end
        local monitor = hl.get_monitor(name)
        if not usable(monitor) then return end
        local owner = owners[selector(monitor.active_workspace)]
        if not owner then return end
        if usable(hl.get_monitor(owner)) then
            place_fixed(owner)
            return
        end
        -- Hyprland may temporarily store a disconnected output's workspaces
        -- on another monitor. Keep its dedicated workspace out of view there.
        local previous = hl.get_last_workspace(name)
        if previous and not previous.special and not owners[selector(previous)] and monitor_name(previous) == name then
            monitor:set_workspace(selector(previous))
        else
            monitor:set_workspace("emptym")
        end
    end, { timeout = 20, type = "oneshot" })
end

if next(fixed) then
    local function repair_displays(keep_windows)
        for _, monitor in ipairs(hl.get_monitors()) do
            if usable(monitor) and (fixed[monitor.name] or owners[selector(monitor.active_workspace)]) then
                schedule_repair(monitor.name, keep_windows)
            end
        end
    end

    hl.on("config.reloaded", function()
        repair_displays(true)
    end)
    hl.on("hyprland.start", function() repair_displays() end)
    hl.on("monitor.layout_changed", function() repair_displays() end)
    hl.on("monitor.added", function(monitor)
        if fixed[monitor.name] then schedule_repair(monitor.name) end
    end)

    local function check_workspace(workspace, monitor)
        if not usable(monitor) then return end
        local owner = owners[selector(workspace)]
        if owner and owner ~= monitor.name then
            schedule_repair(owner)
            schedule_repair(monitor.name)
        elseif fixed[monitor.name] and not owner then
            schedule_repair(monitor.name)
        end
    end
    hl.on("workspace.active", function(workspace)
        check_workspace(workspace, workspace and workspace.monitor)
    end)
    hl.on("workspace.move_to_monitor", check_workspace)
end

function M.switch_monitor()
    local current = hl.get_active_monitor()
    if usable(current) and not fixed[current.name] then return current end
    if primary ~= "" and not fixed[primary] then
        local monitor = hl.get_monitor(primary)
        if usable(monitor) then return monitor end
    end
    for _, monitor in ipairs(hl.get_monitors()) do
        if usable(monitor) and not fixed[monitor.name] then return monitor end
    end
end

function M.focus_workspace(target)
    local owner = owners[tostring(target)]
    if owner then
        if place_fixed(owner) then
            hl.dispatch(hl.dsp.focus({ monitor = owner }))
        end
        return
    end

    local monitor = M.switch_monitor()
    if not monitor then return end
    local current = hl.get_active_monitor()
    if not current or current.name ~= monitor.name then
        hl.dispatch(hl.dsp.focus({ monitor = monitor.name }))
    end

    local workspace
    if next(fixed) then
        workspace = hl.get_workspace(target)
        if type(target) == "string" and target:match("^e[+-]1$") then
            local prefix = target:sub(1, 2)
            for offset = 2, #hl.get_workspaces() do
                if not workspace or not owners[selector(workspace)] then break end
                workspace = hl.get_workspace(prefix .. offset)
            end
            if not workspace then return end
        elseif (target == "previous" or target == "previous_per_monitor") and not workspace then
            return
        end
        local address = selector(workspace)
        if owners[address] then return end
        target = address or target
    end
    if fixed[monitor_name(workspace)] then
        hl.dispatch(hl.dsp.workspace.move({ workspace = target, monitor = monitor.name }))
    end

    hl.dispatch(hl.dsp.focus({ workspace = target }))
end

function M.move_window_to_workspace(target, follow)
    if not next(fixed) then
        hl.dispatch(hl.dsp.window.move({ workspace = target, follow = follow }))
        return
    end

    local workspace = hl.get_workspace(target)
    local address = selector(workspace)
    local owner = owners[tostring(target)] or owners[address]
    if owner then
        if not place_fixed(owner) then return end
        hl.dispatch(hl.dsp.window.move({ workspace = fixed[owner], follow = follow }))
        return
    end

    local destination = M.switch_monitor()
    if not destination then return end
    target = address or target
    if fixed[monitor_name(workspace)] then
        hl.dispatch(hl.dsp.workspace.move({ workspace = target, monitor = destination.name }))
    end
    local current = hl.get_active_monitor()
    if not workspace and current and fixed[current.name] then
        hl.dispatch(hl.dsp.window.move({ workspace = target, follow = false }))
        workspace = hl.get_workspace(target)
        if fixed[monitor_name(workspace)] then
            hl.dispatch(hl.dsp.workspace.move({ workspace = target, monitor = destination.name }))
        end
        if workspace and follow then M.focus_workspace(target) end
        return
    end
    hl.dispatch(hl.dsp.window.move({ workspace = target, follow = follow }))
end

return M
