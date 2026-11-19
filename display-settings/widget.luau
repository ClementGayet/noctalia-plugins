barWidget.setGlyph("device-desktop")
barWidget.setTooltip("Display Settings")

function onClick()
    noctalia.togglePanel("local/display-settings:panel")
end

function onRightClick()
    noctalia.runAsync({ "noctalia", "msg", "panel-open", "control-center", "monitor" })
end
