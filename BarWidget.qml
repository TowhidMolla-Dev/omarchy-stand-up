import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

// Bar countdown. The timer itself lives in Service.qml; this is a
// read-only view plus quick controls, and it owns the settings panel
// (loaded from Panel.qml) the same way the built-in clock does.
BarWidget {
  id: root
  moduleName: "towhid.stand-up"

  readonly property var standService: bar && bar.shell ? bar.shell.serviceFor("towhid.stand-up") : null
  readonly property string phase: standService ? String(standService.phase) : "work"
  readonly property int remaining: standService ? Number(standService.remaining) : 2700
  readonly property bool paused: standService ? !!standService.paused : false
  readonly property int move: standService ? Number(standService.moveIndex) + 1 : 1
  readonly property int moveCount: standService ? Number(standService.moveCount) : 3
  readonly property string routineTitle: standService ? String(standService.routine.title) : ""
  readonly property int completed: standService ? Number(standService.completed) : 0
  readonly property int skipped: standService ? Number(standService.skipped) : 0

  readonly property bool breaking: phase === "break"
  readonly property bool reporting: phase === "report"
  readonly property bool snoozed: standService ? !!standService.snoozed : false

  // ------------------------------------------------------- bar layout mode
  readonly property string barMode: standService ? String(standService.barMode) : "compact"
  readonly property real progress: standService ? Number(standService.progress) : 0
  readonly property bool compact: barMode === "compact"
  readonly property bool hoverMode: barMode === "hover"
  readonly property bool urgent: breaking || reporting || paused

  // The widget the pointer is actually over, decoupled from what is drawn.
  // Collapsing on the same frame the pointer leaves would shrink the hit
  // area out from under it and re-enter immediately, so the two would
  // oscillate; the grace delay collapses once the pointer is clearly gone.
  property bool pointerInside: false
  property bool showTimer: false
  readonly property bool hovered: compact ? false : (showTimer || pointerInside)

  Timer {
    id: collapseDelay
    interval: 280
    onTriggered: root.showTimer = false
  }

  readonly property bool opened: panelLoader.item
    ? panelLoader.item.opened === true
    : false
  readonly property bool popoutSwitchClosing: panelLoader.item
    ? panelLoader.item.popoutSwitchClosing === true
    : false

  function open() {
    if (panelLoader.item) panelLoader.item.open()
  }

  function close() {
    if (panelLoader.item) panelLoader.item.close()
  }

  function toggle() {
    if (panelLoader.item) panelLoader.item.toggle()
  }

  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  function injectPanel() {
    if (!panelLoader.item) return
    panelLoader.item.bar = root.bar
    panelLoader.item.anchorItem = button
    panelLoader.item.hostWidget = root
  }

  function formatTime(totalSeconds) {
    var s = Math.max(0, totalSeconds)
    var m = Math.floor(s / 60)
    var r = s % 60
    return m + ":" + (r < 10 ? "0" + r : "" + r)
  }

  readonly property string labelText: root.breaking
    ? root.move + "/" + root.moveCount
    : (root.reporting ? "?" : root.formatTime(root.remaining))

  // The timer is the payload in full mode, hidden behind hover in hover
  // mode, and replaced by the ring in compact mode. Only the two text
  // modes below ever reach WidgetButton.
  readonly property string buttonText: root.hoverMode
    ? (root.hovered ? "󰢄 " + root.labelText : "󰢄")
    : (root.compact ? "󰢄" : "󰢄 " + root.labelText)

  readonly property string tooltipText: root.paused
    ? "Stand Up: paused (right-click to resume)"
    : (root.breaking ? "Stand Up: " + root.routineTitle + " - move " + root.move + " of " + root.moveCount
                     : (root.reporting ? "Stand Up: did you actually move? (left-click for settings)"
                                       : (root.snoozed ? "Stand Up: snoozed, resuming shortly"
                                                       : "Stand Up: " + root.formatTime(root.remaining)
                                                         + " until the next stretch (left-click for settings, right-click to pause)")))

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  // Behind the glyph: in compact mode the ring is the only thing carrying
  // elapsed time, so it has to sit under the icon rather than beside it.
  ProgressRing {
    visible: root.compact
    width: button.height
    height: button.height
    anchors.horizontalCenter: button.horizontalCenter
    anchors.verticalCenter: button.verticalCenter
    progress: root.progress
    trackColor: Util.alpha(
      root.urgent ? (root.bar ? root.bar.urgent : Color.urgent) : root.barForeground,
      0.22
    )
    progressColor: root.urgent
      ? (root.bar ? root.bar.urgent : Color.urgent)
      : Color.accent
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.buttonText
    tooltipText: root.tooltipText
    active: root.urgent

    // The bar sizes each slot from implicitWidth, so animating it here
    // slides the rest of the bar instead of teleporting it.
    Behavior on implicitWidth {
      NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
    }

    onPressed: function(b) {
      if (!root.standService) return
      if (b === Qt.RightButton) root.standService.toggle()
      else if (b === Qt.MiddleButton) root.standService.preview()
      else root.toggle()
    }
  }

  Connections {
    target: button
    function onTooltipHoveredChanged() {
      if (button.tooltipHovered) {
        collapseDelay.stop()
        root.pointerInside = true
        root.showTimer = true
      } else {
        root.pointerInside = false
        collapseDelay.restart()
      }
    }
  }
}
