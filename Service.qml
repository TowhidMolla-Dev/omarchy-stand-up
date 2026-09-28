import QtQuick
import Quickshell
import Quickshell.Io
import "Library.js" as Library

// Timer core for the Stand Up plugin. Single source of truth: the bar
// widget, the settings panel and the break overlay all read their state
// from here through shell.serviceFor("towhid.stand-up").
//
// Phase machine:
//
//   work --(interval elapses)--> break --> report --(self-report)--> work
//     ^                             |                              |
//     |                             +--(skip / Esc)--------------+
//     |                                                          |
//     +-------------------- snooze() ----------------------------+
//
// A break walks the current routine's three moves one at a time. When the
// last move finishes the phase becomes "report", where the overlay asks
// whether the stretches were actually done. Nothing is inferred from
// input activity: self-reporting is the contract, and the answer is what
// feeds the adherence numbers.
Item {
  id: root

  // Injected by omarchy-shell.
  property var shell: null
  property var manifest: null
  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  readonly property string home: Quickshell.env("HOME")
  readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || root.home + "/.local/state") + "/omarchy/towhid.stand-up/"
  readonly property string settingsPath: root.stateDir + "settings.json"

  readonly property string pluginId: "towhid.stand-up"
  readonly property var routines: Library.ROUTINES

  // ------------------------------------------------------------- settings
  property int workMinutes: 45
  property int moveSeconds: 30
  property int snoozeMinutes: 5
  property bool sound: true
  property bool quietEnabled: true
  property int quietStart: 22
  property int quietEnd: 8
  // How much the bar widget spends on the countdown: "full" shows icon and
  // timer, "compact" shows icon plus a progress ring, "hover" reveals the
  // timer while the pointer is on the widget.
  property string barMode: "compact"
  property bool settingsLoaded: false

  readonly property int workSeconds: Math.max(60, root.workMinutes * 60)
  readonly property int snoozeSeconds: Math.max(60, root.snoozeMinutes * 60)

  readonly property var barModes: ["full", "compact", "hover"]

  // Fraction of the current countdown already elapsed, for the bar's
  // progress ring. A snoozed stretch counts against the short snooze
  // interval, not the full one.
  readonly property int workTotalSeconds: root.pendingSnooze ? root.snoozeSeconds : root.workSeconds
  readonly property real progress: root.phase !== "work" || root.workTotalSeconds <= 0
    ? 1
    : Math.min(1, Math.max(0, 1 - root.remaining / root.workTotalSeconds))

  // ---------------------------------------------------------------- stats
  property string statsDate: ""
  property int completed: 0
  property int skipped: 0
  readonly property int totalBreaks: root.completed + root.skipped
  readonly property int adherence: root.totalBreaks > 0 ? Math.round((root.completed / root.totalBreaks) * 100) : -1

  // ---------------------------------------------------------- phase state
  property string phase: "work"   // "work" | "break" | "report"
  property int remaining: 2700
  property int moveIndex: 0
  property int moveRemaining: 30
  property bool paused: false
  property bool pendingSnooze: false
  property int routineIndex: 0

  // Wall-clock anchor for the work countdown, in epoch milliseconds.
  // 0 means "not counting down" (paused). Storing an absolute deadline
  // rather than a remaining-seconds counter is what lets the timer
  // survive `omarchy restart shell`: the new process subtracts the
  // current time from the deadline the old one wrote, so the countdown
  // resumes where it would have been instead of starting over.
  //
  // Must be `double`, not `int`: a millisecond epoch is around 1.79e12 and
  // silently overflows a 32-bit QML int (max ~2.1e9), which would make
  // every restored countdown read as already expired.
  property double deadline: 0

  // A trial run opened from the settings panel. It walks a routine so the
  // user can see the format, but it never touches the countdown or the
  // stats: finishing a preview puts the work phase back exactly as it was.
  property bool previewing: false
  property int previewSavedRemaining: 0

  readonly property bool resting: root.phase === "break" || root.phase === "report"
  readonly property var routine: root.routines[root.routineIndex % root.routines.length]
  readonly property var currentMove: root.routine.moves[Math.min(root.moveIndex, root.routine.moves.length - 1)]
  readonly property int currentMoveLength: root.moveLength(root.currentMove)
  readonly property int moveCount: root.routine.moves.length
  readonly property bool lastMove: root.moveIndex >= root.routine.moves.length - 1
  readonly property bool snoozed: root.pendingSnooze

  // The library carries a default hold time per move; the `moveSeconds`
  // setting overrides it so a single control in the panel rescales the
  // whole routine.
  function moveLength(entry) {
    var fallback = entry && entry.seconds ? entry.seconds : 30
    return root.moveSeconds > 0 ? root.moveSeconds : fallback
  }

  function breakSeconds() {
    var total = 0
    var moves = root.routine.moves
    for (var i = 0; i < moves.length; i++) total += root.moveLength(moves[i])
    return total
  }

  function nextMove() {
    if (root.lastMove) return null
    return root.routine.moves[root.moveIndex + 1]
  }

  function formatTime(totalSeconds) {
    var s = Math.max(0, totalSeconds)
    var m = Math.floor(s / 60)
    var r = s % 60
    return m + ":" + (r < 10 ? "0" + r : "" + r)
  }

  function today() {
    return Qt.formatDate(new Date(), "yyyy-MM-dd")
  }

  // Midnight rollover: the counters are per-day, so a long-running shell
  // resets them instead of showing yesterday's adherence forever.
  function rollDay() {
    var t = root.today()
    if (root.statsDate === t) return
    root.statsDate = t
    root.completed = 0
    root.skipped = 0
    root.scheduleSave()
  }

  function inQuietHours() {
    if (!root.quietEnabled) return false
    var h = new Date().getHours()
    if (root.quietStart > root.quietEnd) return h >= root.quietStart || h < root.quietEnd
    return h >= root.quietStart && h < root.quietEnd
  }

  // ------------------------------------------------------------ behaviour
  function notify(headline, body) {
    if (!root.omarchyPath) return
    Quickshell.execDetached([root.omarchyPath + "/bin/omarchy-notification-send", "-g", "󰢄", headline, body])
  }

  function playSound() {
    if (!root.sound) return
    Quickshell.execDetached(["pw-play", "/usr/share/sounds/freedesktop/stereo/message-new-instant.oga"])
  }

  function summonOverlay() {
    if (root.shell && typeof root.shell.summon === "function")
      root.shell.summon(root.pluginId, "{}")
  }

  function hideOverlay() {
    if (root.shell && typeof root.shell.hide === "function")
      root.shell.hide(root.pluginId)
  }

  // Arm (or disarm) the work countdown. Everything that starts, resumes
  // or re-times the work phase goes through here so the persisted deadline
  // and the on-screen number can never disagree.
  function armWorkCountdown(seconds) {
    var s = Math.max(0, seconds)
    root.remaining = s
    root.deadline = s > 0 ? Date.now() + s * 1000 : 0
    root.scheduleSave()
  }

  // Recompute the display from the wall clock. Deriving instead of
  // decrementing also stops the countdown from drifting when a tick is
  // late or the system is briefly busy.
  function syncRemaining() {
    if (root.paused || root.deadline === 0) return
    root.remaining = Math.max(0, Math.ceil((root.deadline - Date.now()) / 1000))
  }

  function beginWorkPhase() {
    root.phase = "work"
    root.moveIndex = 0
    root.moveRemaining = 0
    root.armWorkCountdown(root.pendingSnooze ? root.snoozeSeconds : root.workSeconds)
  }

  // --------------------------------------------------- media playback guard
  // A break that only blacks out the screen is useless during a film: the
  // audio keeps going and the video keeps advancing behind the block, so
  // nothing is actually restful and the film plays on regardless. Pause
  // whatever is playing when the break opens, and resume exactly that set
  // when it is dismissed.
  //
  // MPRIS is spoken directly over busctl; playerctl is not installed here.
  // Two rules keep this from being obnoxious: only a player found in the
  // Playing state is ever touched, and only the players we paused are
  // resumed, so a track the user paused themselves never starts up behind
  // their back.
  property var mediaPausedBy: []
  readonly property bool mediaActive: mediaPausedBy.length > 0

  // Single line on purpose: this is handed to `bash -c` as one string, and
  // a multi-line if/then does not survive being joined into one.
  readonly property string mediaScanCommand:
    "for b in $(busctl --user list --no-pager 2>/dev/null | awk '$1 ~ /^org\\.mpris\\.MediaPlayer2\\./ {print $1}'); do "
    + "busctl --user get-property \"$b\" /org/mpris/MediaPlayer2 org.mpris.MediaPlayer2.Player PlaybackStatus 2>/dev/null | grep -q Playing "
    + "&& busctl --user call \"$b\" /org/mpris/MediaPlayer2 org.mpris.MediaPlayer2.Player Pause >/dev/null 2>&1 "
    + "&& echo \"$b\"; done"

  readonly property string mediaPlayCommand:
    "for b in \"$@\"; do busctl --user call \"$b\" /org/mpris/MediaPlayer2 org.mpris.MediaPlayer2.Player Play >/dev/null 2>&1; done"

  // Echoes one bus name per line, and only for players it actually paused.
  Process {
    id: mediaScan
    command: ["bash", "-c", root.mediaScanCommand]
    stdout: StdioCollector {
      id: mediaScanOut
      onStreamFinished: {
        var names = mediaScanOut.text.split("\n").filter(function(n) { return n.length > 0 })
        if (names.length > 0) root.mediaPausedBy = names
      }
    }
  }

  Process {
    id: mediaPlay
    property var targets: []
    command: ["bash", "-c", root.mediaPlayCommand, "media-resume"].concat(targets)
  }

  function pauseMedia() {
    if (mediaScan.running) return
    mediaScan.running = true
  }

  function resumeMedia() {
    if (mediaPausedBy.length === 0) return
    // Hand the list to the process before clearing it, so a second dismiss
    // within one break cannot resume the same player twice.
    mediaPlay.targets = mediaPausedBy
    root.mediaPausedBy = []
    mediaPlay.running = true
  }

  function startBreak() {
    root.phase = "break"
    root.moveIndex = 0
    root.moveRemaining = root.currentMoveLength
    root.remaining = root.breakSeconds()
    // The work countdown is over; clear the deadline so a restart during
    // the break cannot resurrect a stale one.
    root.deadline = 0
    root.scheduleSave()
    root.notify("Time to stand up", root.routine.title + " - " + root.routine.focus)
    root.playSound()
    if (!root.previewing) root.pauseMedia()
    root.summonOverlay()
  }

  // `moved` is the honest answer to "did you actually do them".
  function completeBreak(moved) {
    root.resumeMedia()
    if (root.previewing) {
      root.finishPreview()
      return
    }
    if (moved) root.completed += 1
    else root.skipped += 1
    root.pendingSnooze = false
    root.hideOverlay()
    root.scheduleSave()
    root.routineIndex = (root.routineIndex + 1) % root.routines.length
    root.notify(moved ? "Break logged" : "Break skipped",
      moved ? "Nice work - " + root.completed + " done today" : "Next routine in " + root.workMinutes + " min")
    root.beginWorkPhase()
  }

  function finishPreview() {
    root.resumeMedia()
    root.previewing = false
    root.pendingSnooze = false
    root.hideOverlay()
    root.phase = "work"
    root.moveIndex = 0
    root.moveRemaining = 0
    root.armWorkCountdown(root.previewSavedRemaining)
  }

  // Remind again shortly, without touching the stats.
  function snooze() {
    root.resumeMedia()
    if (root.previewing) {
      root.finishPreview()
      return
    }
    root.pendingSnooze = true
    root.hideOverlay()
    root.beginWorkPhase()
  }

  // Pausing freezes the number and drops the deadline; resuming re-arms it
  // from whatever was left. Otherwise a pause that survived a restart would
  // come back already expired.
  function pause() {
    if (root.paused) return
    root.syncRemaining()
    root.paused = true
    root.deadline = 0
    root.scheduleSave()
  }

  function resume() {
    if (!root.paused) return
    root.paused = false
    root.armWorkCountdown(root.phase === "work" ? root.remaining : 0)
  }

  function toggle() {
    if (root.paused) root.resume()
    else root.pause()
  }

  function start() {
    root.resume()
  }

  function stop() {
    // Never leave somebody's film parked on pause because the plugin was
    // switched off mid-stretch.
    root.resumeMedia()
    root.pause()
  }

  // Right-click / IPC: jump to the other phase.
  function skip() {
    if (root.resting) root.completeBreak(false)
    else root.startBreak()
  }

  // Open the overlay right now for a trial run. The work countdown is
  // stashed and restored when the preview ends.
  function preview() {
    if (root.resting) {
      root.summonOverlay()
      return
    }
    root.previewing = true
    root.previewSavedRemaining = root.remaining
    root.startBreak()
  }

  function tick() {
    if (root.paused) return
    root.rollDay()

    if (root.phase === "work") {
      root.syncRemaining()
      if (root.remaining > 0) return
      if (root.inQuietHours()) {
        // Hold fire during quiet hours and re-check in a minute rather
        // than waking the user with a stretch overlay.
        root.armWorkCountdown(60)
        return
      }
      root.startBreak()
      return
    }

    if (root.phase === "break") {
      root.remaining -= 1
      root.moveRemaining -= 1
      if (root.moveRemaining > 0) return
      if (root.moveIndex < root.routine.moves.length - 1) {
        root.moveIndex += 1
        root.moveRemaining = root.currentMoveLength
        return
      }
      root.phase = "report"
      root.remaining = 0
      root.moveRemaining = 0
    }
  }

  Timer {
    id: ticker
    interval: 1000
    repeat: true
    running: true
    onTriggered: root.tick()
  }

  // Applied when the panel changes an interval mid-phase: never let the
  // countdown outlive the new setting. A pending snooze keeps its own
  // shorter countdown, and a paused timer is left exactly as the user set it.
  function reapplySettings() {
    if (root.phase === "work" && !root.pendingSnooze) {
      if (root.paused) {
        root.remaining = Math.min(root.remaining, root.workSeconds)
        root.scheduleSave()
      } else {
        root.armWorkCountdown(Math.min(root.remaining, root.workSeconds))
      }
      return
    }
    root.scheduleSave()
  }

  function resetStats() {
    root.completed = 0
    root.skipped = 0
    root.statsDate = root.today()
    root.scheduleSave()
  }

  // ---------------------------------------------------------- persistence
  Process {
    id: ensureDirs
    command: ["mkdir", "-p", root.stateDir]
    running: false
  }

  FileView {
    id: settingsFile
    path: root.settingsPath
    watchChanges: false
    atomicWrites: true
    printErrors: false
    onLoaded: root.loadSettings(text())
    onLoadFailed: root.loadSettings("")
  }

  Timer {
    id: saveTimer
    interval: 200
    repeat: false
    onTriggered: root.flushSettings()
  }

  function scheduleSave() {
    if (!root.settingsLoaded) return
    saveTimer.restart()
  }

  function setBarMode(value) {
    if (root.barModes.indexOf(String(value)) < 0) return false
    if (root.barMode === String(value)) return true
    root.barMode = String(value)
    root.scheduleSave()
    return true
  }

  function loadSettings(raw) {
    if (root.settingsLoaded) return
    var parsed = {}
    try { parsed = JSON.parse(raw || "{}") || {} } catch (e) { parsed = {} }

    if (typeof parsed.workMinutes === "number") root.workMinutes = Math.min(180, Math.max(5, parsed.workMinutes))
    if (typeof parsed.moveSeconds === "number") root.moveSeconds = Math.min(180, Math.max(10, parsed.moveSeconds))
    if (typeof parsed.snoozeMinutes === "number") root.snoozeMinutes = Math.min(30, Math.max(1, parsed.snoozeMinutes))
    if (typeof parsed.sound === "boolean") root.sound = parsed.sound
    if (typeof parsed.quietEnabled === "boolean") root.quietEnabled = parsed.quietEnabled
    if (typeof parsed.quietStart === "number") root.quietStart = Math.min(23, Math.max(0, parsed.quietStart))
    if (typeof parsed.quietEnd === "number") root.quietEnd = Math.min(23, Math.max(0, parsed.quietEnd))
    if (root.barModes.indexOf(String(parsed.barMode)) >= 0) root.barMode = String(parsed.barMode)
    if (parsed.stats && typeof parsed.stats === "object") {
      if (typeof parsed.stats.date === "string") root.statsDate = parsed.stats.date
      if (typeof parsed.stats.completed === "number") root.completed = parsed.stats.completed
      if (typeof parsed.stats.skipped === "number") root.skipped = parsed.stats.skipped
    }

    root.rollDay()
    root.settingsLoaded = true
    root.restoreTimer(parsed)
  }

  // Rebuild the countdown from disk.
  //
  // The persisted deadline wins over the persisted remaining count: the
  // shell may have been stopped for a few seconds (a restart) or for
  // hours (a reboot), and only the wall clock can tell those apart. A
  // deadline that already elapsed while the shell was down falls back to
  // a fresh work phase instead of firing a stale stretch at login.
  function restoreTimer(parsed) {
    var timer = parsed.timer && typeof parsed.timer === "object" ? parsed.timer : null
    if (!timer) {
      root.beginWorkPhase()
      return
    }

    if (typeof timer.routineIndex === "number")
      root.routineIndex = ((timer.routineIndex % root.routines.length) + root.routines.length) % root.routines.length
    if (typeof timer.paused === "boolean") root.paused = timer.paused
    root.pendingSnooze = timer.pendingSnooze === true

    // Only a work phase is resumable. A break interrupted by the restart
    // is not counted either way - the user never got to answer.
    if (timer.phase !== "work") {
      root.beginWorkPhase()
      return
    }

    var left = 0
    if (!root.paused && typeof timer.deadline === "number" && timer.deadline > 0)
      left = Math.ceil((timer.deadline - Date.now()) / 1000)
    else if (typeof timer.remaining === "number")
      left = timer.remaining

    if (left <= 0) {
      root.beginWorkPhase()
      return
    }

    root.phase = "work"
    root.moveIndex = 0
    root.moveRemaining = 0
    root.remaining = left
    root.deadline = root.paused ? 0 : Date.now() + left * 1000
  }

  function flushSettings() {
    settingsFile.setText(JSON.stringify({
      version: 2,
      workMinutes: root.workMinutes,
      moveSeconds: root.moveSeconds,
      snoozeMinutes: root.snoozeMinutes,
      sound: root.sound,
      quietEnabled: root.quietEnabled,
      quietStart: root.quietStart,
      quietEnd: root.quietEnd,
      barMode: root.barMode,
      timer: {
        phase: root.phase,
        deadline: root.deadline,
        remaining: root.remaining,
        paused: root.paused,
        pendingSnooze: root.pendingSnooze,
        routineIndex: root.routineIndex
      },
      stats: {
        date: root.statsDate,
        completed: root.completed,
        skipped: root.skipped
      }
    }, null, 2) + "\n")
  }

  Component.onCompleted: {
    ensureDirs.running = true
    // Once mkdir has had a tick, read the persisted state. Reading after
    // the directory exists keeps the first run (no file yet) from
    // reporting a path error instead of a missing file.
    Qt.callLater(function() {
      settingsFile.reload()
    })
  }

  function statusJson() {
    return JSON.stringify({
      phase: root.phase,
      remaining: root.remaining,
      display: root.formatTime(root.remaining),
      deadline: root.deadline,
      paused: root.paused,
      mediaActive: root.mediaActive,
      snoozed: root.pendingSnooze,
      move: root.moveIndex + 1,
      moveCount: root.moveCount,
      routine: root.routine.title,
      completed: root.completed,
      skipped: root.skipped,
      adherence: root.adherence,
      barMode: root.barMode,
      progress: Math.round(root.progress * 1000) / 1000
    })
  }

  IpcHandler {
    target: "stand-up"

    function status(): string { return root.statusJson() }
    function start(): string { root.start(); return root.statusJson() }
    function stop(): string { root.stop(); return root.statusJson() }
    function toggle(): string { root.toggle(); return root.statusJson() }
    function skip(): string { root.skip(); return root.statusJson() }
    function done(): string { root.completeBreak(true); return root.statusJson() }
    function snooze(): string { root.snooze(); return root.statusJson() }
    function preview(): string { root.preview(); return root.statusJson() }
    function reset(): string { root.resetStats(); return root.statusJson() }
    function mode(value: string): string { root.setBarMode(value); return root.statusJson() }
    function ping(): string { return "ok" }
  }
}
