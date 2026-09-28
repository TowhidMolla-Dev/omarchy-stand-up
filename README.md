# Stand Up

An Omarchy shell plugin that interrupts long sitting sessions with a guided,
fullscreen stretch — and then asks whether you actually did it.

- A countdown in the bar, a three-move routine in a fullscreen overlay
- Eight routines (neck, chest, spine, hips, wrists, eyes, full body, breathing) that rotate, so you never get the same three moves twice in a row
- Honest self-reporting: the stats only count a break if you tell it you moved
- Interval, move length, sound and quiet hours are all editable in a panel

This is a wellness habit, not medical advice. Every move is deliberately slow
and pain-free, and the overlay reminds you to skip anything that hurts.

## Install

```sh
omarchy plugin add https://github.com/yourname/omarchy-stand-up.git --enable
```

## Usage

The bar label shows the time until the next stretch.

| Action | Result |
|---|---|
| Left-click the bar label | Open the settings panel |
| Right-click | Pause / resume the countdown |
| Middle-click | Preview a routine now (does not count) |
| Esc, click outside, or Skip | End the break early — logged as skipped |

When a break starts, the overlay walks the routine's three moves with a
countdown each. At the end it asks **"Did you actually move?"** — answering
"I did the moves" or "I skipped" is what feeds today's adherence numbers.
That is the whole point: a timer you can dismiss teaches you nothing, so the
plugin would rather show you an honest zero than a fake streak.

"Later" snoozes the reminder for a few minutes and comes back with the same
routine, without touching the stats.

## Configure

Everything lives in the panel behind the bar label:

- **Stand up every** — 5 to 180 minutes (default 45)
- **Seconds per move** — 10 to 180, rescales every move in the library
- **Snooze after** — minutes before a deferred break reappears
- **Sound** — play a chime when a break starts
- **Quiet hours** — suppress reminders between two hours (default 22:00–08:00)

Settings, today's stats and the live countdown persist to
`$XDG_STATE_HOME/omarchy/towhid.stand-up/settings.json`.

## Configure

### Bar display: full, ring, or hover

Two health timers on one bar is a lot of pixels, so the bar widget has three
display modes, chosen in the settings panel and saved across restarts.

| Mode | Shows | Width |
|---|---|---|
| `Full` | Icon and countdown | ~67px |
| `Ring` (default) | Icon inside a ring that fills as the countdown runs | ~27px |
| `Hover` | Icon until you hover it, then the countdown slides in | 27px → 67px |

`Ring` is the default because a countdown's value is that you can read it
*without* pointing at it. Hiding the number behind a hover would mean you have
to hover every single time you want to know, which is strictly worse than a
number that is always there — and with two such widgets, every sweep of the
pointer across the bar would reflow the layout twice. The ring answers "how
long until my next stretch?" in a glance instead, and its colour turns urgent
when the timer is paused or a break is running. During a snooze it fills
against the short snooze interval, not the full one.

The full status is always on the tooltip, so `Ring` costs you nothing but
width. `Hover` is there for people who prefer the bar to stay visually quiet
until they ask for it.

You can also set the mode over IPC:

```bash
omarchy-shell stand-up mode ring     # full | compact | hover
```

### Timer survives a shell restart

The work countdown is stored as an absolute wall-clock deadline rather than a
remaining-seconds counter, so `omarchy restart shell` (or a shell crash) resumes
where it left off instead of starting the interval again. A paused timer comes
back still paused, at the same remaining time. A deadline that elapsed while the
shell was down — hours later, after a reboot — starts a fresh work phase rather
than firing a stale stretch at login, and a break interrupted by the restart is
not counted either way.

Only the deadline is written, and only when the work phase is armed or paused: a
few writes per work cycle, not one per second.

## IPC

```sh
omarchy-shell stand-up status
omarchy-shell stand-up start      # resume
omarchy-shell stand-up stop       # pause
omarchy-shell stand-up toggle
omarchy-shell stand-up preview    # try a routine now
omarchy-shell stand-up skip
omarchy-shell stand-up done
omarchy-shell stand-up snooze
omarchy-shell stand-up reset      # clear today's stats
```

## Add your own routine

Append an entry to `Library.js`. Three moves, each with a `name`, a `how`
string and a default `seconds` value:

```js
{
  id: "desk-reset",
  title: "Desk Reset",
  focus: "One line describing what this targets",
  moves: [
    { name: "Move name", how: "Plain-language instructions.", seconds: 30 }
  ]
}
```

The routine joins the rotation automatically once the shell reloads.

## Development

```sh
# Validate the folder (required before publishing)
omarchy plugin validate ~/Work/omarchy-stand-up

# Lint the QML against the installed shell imports
qmllint -I "$OMARCHY_PATH/shell" ~/Work/omarchy-stand-up/*.qml

# Install into the running shell while developing
mkdir -p ~/.config/omarchy/plugins/towhid.stand-up
cp ~/Work/omarchy-stand-up/{manifest.json,Service.qml,BarWidget.qml,Overlay.qml,Panel.qml,Library.js} \
   ~/.config/omarchy/plugins/towhid.stand-up/
omarchy-shell shell rescanPlugins
omarchy plugin enable towhid.stand-up --section right
```

Service code is only re-read on a shell restart, so after editing `Service.qml`
run `omarchy restart shell`. `BarWidget.qml`, `Overlay.qml` and `Panel.qml`
hot-reload on save.

To test a full cycle without waiting 45 minutes, drop `workMinutes` to 1 in
the panel, or middle-click the bar label for an immediate preview.

## File layout

| File | Role |
|---|---|
| `manifest.json` | Plugin definition (`service` + `bar-widget` + `overlay`) |
| `Service.qml` | Phase machine, settings and stats persistence, IPC. Single source of truth |
| `BarWidget.qml` | Bar countdown, quick controls, loads `Panel.qml` |
| `Overlay.qml` | Fullscreen guided stretch and the self-report question |
| `Panel.qml` | Settings and today's stats |
| `Library.js` | The rotating routine library |

## License

MIT
