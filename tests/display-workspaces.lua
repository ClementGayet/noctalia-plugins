-- Run with lua tests/display-workspaces.lua from the plugin repository root.
local primary = { name = "HDMI-A-1", enabled = true }
local portrait = { name = "DP-2", enabled = true }
local initial = { id = 1, monitor = primary }
local next_workspace = { id = 3, monitor = primary }
local dedicated = { addressable_name = "Display-DP-2", monitor = primary, special = false }
local dedicated_selector = "name:Display-DP-2"
local handlers, timers, focused = {}, {}, nil

package.preload["display-workspace-preferences"] = function()
    return { primary = primary.name, fixed = { [portrait.name] = "2" } }
end

function portrait:set_workspace(target)
    assert(target == dedicated_selector, "the monitor setter needs the command selector")
    dedicated.monitor = self
    self.active_workspace = dedicated
    primary.active_workspace = initial
end

hl = {
    on = function(event, handler) handlers[event] = handler end,
    timer = function(callback) table.insert(timers, callback) end,
    workspace_rule = function(rule) assert(rule.workspace == dedicated_selector) end,
    get_monitor = function(name) return name == portrait.name and portrait or primary end,
    get_active_monitor = function() return primary end,
    get_workspaces = function() return { initial, next_workspace, dedicated } end,
    get_workspace = function(target)
        if target == dedicated_selector or target == "e+1" or target == "previous" then return dedicated end
        if target == "e+2" then return next_workspace end
    end,
    dsp = { focus = function(args) return args.workspace end },
    dispatch = function(target) focused = target end,
}

local router = dofile(arg[1] or "display-settings/hyprland/display-workspaces.lua")

-- Hyprland reports a bare address and a nil id for named workspaces.
router.focus_workspace("e+1")
assert(focused == "3", "cycling selected the dedicated workspace")
router.focus_workspace("previous")
assert(focused == "3", "workspace history selected the dedicated workspace")

primary.active_workspace = dedicated
handlers["workspace.move_to_monitor"](dedicated, primary)
while #timers > 0 do
    table.remove(timers, 1)()
end
assert(dedicated.monitor == portrait and portrait.active_workspace == dedicated, "workspace did not return to its owner")
assert(primary.active_workspace == initial, "workspace is still active on the primary monitor")

print("Dedicated workspace routing passed.")
