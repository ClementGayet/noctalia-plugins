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
    if workspace.id and workspace.id > 0 then return tostring(workspace.id) end
    return workspace.addressable_name
end

for monitor in pairs(preferences.fixed) do
    local workspace = "name:Display-" .. monitor
    fixed[monitor] = workspace
    owners[workspace] = monitor
    hl.workspace_rule({ workspace = workspace, monitor = monitor, default = true, persistent = true })
end

local primary_owns_workspace_one = primary ~= "" and not fixed[primary]
if primary_owns_workspace_one then
    hl.workspace_rule({ workspace = "1", monitor = primary, default = true })
end

local function restore_fixed(name, keep_windows)
    if not fixed[name] then return end
    if pending[name] then
        if keep_windows then pending[name].keep_windows = true end
        return
    end
    local monitor = hl.get_monitor(name)
    if not usable(monitor) or selector(monitor.active_workspace) == fixed[name] then return end
    local request = { keep_windows = keep_windows }
    pending[name] = request
    hl.timer(function()
        pending[name] = nil
        local monitor = hl.get_monitor(name)
        if usable(monitor) and selector(monitor.active_workspace) ~= fixed[name] then
            local old = selector(monitor.active_workspace)
            local dedicated = hl.get_workspace(fixed[name])
            local windows = {}
            if request.keep_windows and old == preferences.fixed[name] and (not dedicated or dedicated.is_empty) then
                windows = hl.get_workspace_windows(old)
            end
            monitor:set_workspace(fixed[name])
            for _, window in ipairs(windows) do
                hl.dispatch(hl.dsp.window.move({ window = window, workspace = fixed[name], follow = false }))
            end
        end
    end, { timeout = 20, type = "oneshot" })
end

local function place_workspace_one()
    if not primary_owns_workspace_one then return end
    local monitor = hl.get_monitor(primary)
    local workspace = hl.get_workspace(1)
    if usable(monitor) and workspace and workspace.monitor and workspace.monitor.name ~= primary then
        hl.dispatch(hl.dsp.workspace.move({ workspace = 1, monitor = primary }))
    end
end

if next(fixed) then
    hl.on("config.reloaded", function()
        for name in pairs(fixed) do restore_fixed(name, true) end
    end)
    hl.on("workspace.active", function(workspace)
        local monitor = workspace.monitor
        if monitor and fixed[monitor.name] and fixed[monitor.name] ~= selector(workspace) then
            restore_fixed(monitor.name)
        end
    end)
    hl.on("workspace.move_to_monitor", function(workspace, monitor)
        local owner = owners[selector(workspace)]
        if owner and owner ~= monitor.name then restore_fixed(owner) end
    end)
end

hl.on("monitor.added", function(monitor)
    restore_fixed(monitor.name)
    if primary_owns_workspace_one and monitor.name == primary then
        hl.timer(place_workspace_one, { timeout = 20, type = "oneshot" })
    end
end)

hl.on("hyprland.start", function()
    for name in pairs(fixed) do restore_fixed(name) end
    if primary == "" then return end
    hl.timer(function()
        local monitor = hl.get_monitor(primary)
        if not usable(monitor) then return end
        if primary_owns_workspace_one and selector(monitor.active_workspace) ~= "1" then
            monitor:set_workspace(1)
        end
        hl.dispatch(hl.dsp.focus({ monitor = primary }))
    end, { timeout = 100, type = "oneshot" })
end)

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

function M.is_fixed_workspace(target)
    local owner = owners[tostring(target)]
    return owner and usable(hl.get_monitor(owner))
end

function M.focus_workspace(target)
    if M.is_fixed_workspace(target) then
        hl.dispatch(hl.dsp.focus({ workspace = target }))
        return
    end

    local monitor = M.switch_monitor()
    if not monitor then return end
    local current = hl.get_active_monitor()
    if not current or current.name ~= monitor.name then
        hl.dispatch(hl.dsp.focus({ monitor = monitor.name }))
    end

    local workspace = next(fixed) and hl.get_workspace(target)
    if workspace and type(target) == "string" and target:match("^e[+-]1$") then
        local prefix = target:sub(1, 2)
        for offset = 2, #hl.get_workspaces() do
            if not workspace or not M.is_fixed_workspace(selector(workspace)) then break end
            target = prefix .. offset
            workspace = hl.get_workspace(target)
        end
    end
    if workspace and M.is_fixed_workspace(selector(workspace)) then return end
    if workspace and workspace.monitor and fixed[workspace.monitor.name] then
        local address = selector(workspace)
        hl.dispatch(hl.dsp.workspace.move({ workspace = address, monitor = monitor.name }))
        target = address
    end

    hl.dispatch(hl.dsp.focus({ workspace = target }))
end

function M.move_window_to_workspace(target, follow)
    local destination = next(fixed) and M.switch_monitor()
    if destination then
        local workspace = hl.get_workspace(target)
        if workspace and workspace.monitor and fixed[workspace.monitor.name] then
            hl.dispatch(hl.dsp.workspace.move({ workspace = target, monitor = destination.name }))
        end
        local current = hl.get_active_monitor()
        if not workspace and current and fixed[current.name] then
            hl.dispatch(hl.dsp.window.move({ workspace = target, follow = false }))
            workspace = hl.get_workspace(target)
            if workspace and workspace.monitor and fixed[workspace.monitor.name] then
                hl.dispatch(hl.dsp.workspace.move({ workspace = target, monitor = destination.name }))
            end
            if workspace and follow then M.focus_workspace(target) end
            return
        end
    end
    hl.dispatch(hl.dsp.window.move({ workspace = target, follow = follow }))
end

return M
