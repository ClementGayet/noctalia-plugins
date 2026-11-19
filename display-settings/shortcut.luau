shortcut.setLabel("Displays")
shortcut.setIcon("device-desktop")

function onClick()
    noctalia.togglePanel("local/display-settings:panel")
end

function onRightClick()
    noctalia.runAsync({ "/usr/bin/noctalia", "msg", "panel-open", "control-center", "monitor" })
end
