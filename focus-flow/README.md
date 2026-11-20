# Focus Flow

Pomodoro timer and lightweight daily task tracker for Noctalia.

## Features

- Focus, short break, and long break phases with configurable durations
- One stopwatch icon that opens the Focus Flow panel. Its tooltip shows the timer and remaining tasks.
- Pause, resume, reset, and skip controls
- Daily task list with completion counts
- Daily completed-session and focus-time totals
- Timer and task data persisted across Noctalia restarts
- Desktop notifications when focus and break timers finish

## Add to the bar

Enable `clementgayet/focus-flow` in **Noctalia Settings → Plugins**, then add the Focus Flow widget after the clock in your bar's center section:

```toml
[bar.default]
center = ["clock", "clementgayet/focus-flow:timer"]
```

Configure focus and break durations in **Settings → Plugins → Focus Flow**.
