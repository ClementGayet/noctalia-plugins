hl.bind("ALT + TAB", hl.dsp.exec_cmd("noctalia msg window-switcher hold"),
    { description = "Switch forward through windows" })
hl.bind("ALT + SHIFT + TAB", hl.dsp.exec_cmd("noctalia msg window-switcher hold reverse"),
    { description = "Switch backward through windows" })
hl.bind("ALT + F4", hl.dsp.window.close(),
    { description = "Close the focused window" })
