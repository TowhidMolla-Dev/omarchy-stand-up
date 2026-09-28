import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Ui

// Fullscreen guided stretch overlay.
//
// Opened by Service.startBreak(). It walks the current routine's three
// moves with a per-move countdown, then asks the one question that makes
// the stats meaningful: did you actually move? Esc, a click outside the
// card, or Skip all end the break early and log it as skipped.
Item {
  id: root

  property var shell: null
  property var manifest: null
  // omarchy-shell injects the matching service singleton when the item
  // declares a `service` property. Falls back to a serviceFor lookup in
  // case the service is not loaded yet.
  property var service: null

  property bool opened: false

  readonly property var standService: root.service
    ? root.service
    : (root.shell ? root.shell.serviceFor("towhid.stand-up") : null)

  readonly property string phase: standService ? String(standService.phase) : "work"
  readonly property bool reporting: phase === "report"

  readonly property var routine: standService ? standService.routine : null
  readonly property var move: standService ? standService.currentMove : null
  readonly property var nextMove: standService ? standService.nextMove() : null
  readonly property int moveIndex: standService ? Number(standService.moveIndex) + 1 : 1
  readonly property int moveCount: standService ? Number(standService.moveCount) : 3
  readonly property int moveRemaining: standService ? Number(standService.moveRemaining) : 0
  // The effective hold time, which is the library default rescaled by the
  // panel's length setting - not the raw library value.
  readonly property int moveLength: standService ? Number(standService.currentMoveLength) : 30
  readonly property int completed: standService ? Number(standService.completed) : 0
  readonly property bool snoozed: standService ? !!standService.snoozed : false

  readonly property real moveProgress: moveLength > 0
    ? 1 - Math.min(1, Math.max(0, root.moveRemaining / root.moveLength))
    : 0

  property color background: Color.menu.background
  property color foreground: Color.menu.text
  property color border: Color.menu.border
  property var borderSpec: Border.surfaceSpec("menu", "border", border, Math.max(1, Style.space(2)))
  property color scrim: Color.menu.scrim
  readonly property int cornerRadius: Style.cornerRadius
  property int contentMargin: Style.spacing.panelPadding

  function open(payloadJson) {
    root.opened = true
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function close() {
    root.opened = false
  }

  // Ending the break early always counts as "did not move" - that is the
  // honest reading of dismissing the reminder.
  function dismiss() {
    if (root.standService) root.standService.completeBreak(false)
    else if (root.shell && typeof root.shell.hide === "function")
      root.shell.hide("towhid.stand-up")
    else root.opened = false
  }

  function toggle() {
    if (root.opened) root.dismiss()
    else root.open("{}")
  }

  PanelWindow {
    id: panel
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "towhid-stand-up"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    Rectangle {
      anchors.fill: parent
      color: root.scrim
    }

    MouseArea {
      anchors.fill: parent
      onClicked: root.dismiss()
    }

    BorderSurface {
      id: card
      width: Math.min(Style.space(360), panel.width - Style.gapsOut * 2)
      anchors.centerIn: parent
      color: root.background
      borderSpec: root.borderSpec
      radius: root.cornerRadius
      padding: root.contentMargin

      MouseArea { anchors.fill: parent; onClicked: {} }

      Column {
        id: content
        anchors.fill: parent
        anchors.topMargin: card.contentTopInset
        anchors.rightMargin: card.contentRightInset
        anchors.bottomMargin: card.contentBottomInset
        anchors.leftMargin: card.contentLeftInset
        spacing: Style.space(10)

        Text {
          textFormat: Text.PlainText
          width: parent.width
          horizontalAlignment: Text.AlignHCenter
          text: root.reporting ? "Did you actually move?" : (root.routine ? root.routine.title : "Stand up")
          color: root.foreground
          font.family: Style.font.menuFamily
          font.pixelSize: Style.font.title
          font.bold: true
          wrapMode: Text.WordWrap
        }

        Text {
          textFormat: Text.PlainText
          width: parent.width
          horizontalAlignment: Text.AlignHCenter
          text: root.reporting
            ? "Be honest - it is what makes the streak count"
            : (root.routine ? root.routine.focus : "")
          color: root.foreground
          opacity: 0.65
          font.family: Style.font.menuFamily
          font.pixelSize: Style.font.caption
          wrapMode: Text.WordWrap
        }

        // Big per-move countdown. Hidden in the report state, where the
        // question replaces the timer.
        Text {
          visible: !root.reporting
          textFormat: Text.PlainText
          width: parent.width
          horizontalAlignment: Text.AlignHCenter
          text: root.moveRemaining
          color: Color.accent
          font.family: Style.font.menuFamily
          font.pixelSize: Style.font.displayLarge
        }

        Text {
          visible: !root.reporting
          textFormat: Text.PlainText
          width: parent.width
          horizontalAlignment: Text.AlignHCenter
          text: "Move " + root.moveIndex + " of " + root.moveCount
          color: root.foreground
          font.family: Style.font.menuFamily
          font.pixelSize: Style.font.subtitle
        }

        // Progress through the current move.
        Rectangle {
          visible: !root.reporting
          width: parent.width
          height: Style.space(8)
          radius: height / 2
          color: Util.alpha(root.foreground, 0.18)

          Rectangle {
            width: parent.width * Math.min(1, Math.max(0, root.moveProgress))
            height: parent.height
            radius: parent.radius
            color: Color.accent
          }
        }

        Text {
          visible: !root.reporting
          textFormat: Text.PlainText
          width: parent.width
          horizontalAlignment: Text.AlignHCenter
          text: root.move ? root.move.name : ""
          color: root.foreground
          font.family: Style.font.menuFamily
          font.pixelSize: Style.font.subtitle
          font.bold: true
          wrapMode: Text.WordWrap
        }

        Text {
          visible: !root.reporting
          textFormat: Text.PlainText
          width: parent.width
          horizontalAlignment: Text.AlignHCenter
          wrapMode: Text.WordWrap
          text: root.move ? root.move.how : ""
          color: root.foreground
          font.family: Style.font.menuFamily
          font.pixelSize: Style.font.body
        }

        Text {
          visible: !root.reporting && root.nextMove !== null
          textFormat: Text.PlainText
          width: parent.width
          horizontalAlignment: Text.AlignHCenter
          text: "Next: " + (root.nextMove ? root.nextMove.name : "")
          color: root.foreground
          opacity: 0.6
          font.family: Style.font.menuFamily
          font.pixelSize: Style.font.caption
          wrapMode: Text.WordWrap
        }

        // Report state: the self-report that the whole plugin is built
        // around.
        Text {
          visible: root.reporting
          textFormat: Text.PlainText
          width: parent.width
          horizontalAlignment: Text.AlignHCenter
          text: root.completed + " done today"
          color: root.foreground
          font.family: Style.font.menuFamily
          font.pixelSize: Style.font.subtitle
        }

        Row {
          anchors.horizontalCenter: parent.horizontalCenter
          spacing: Style.space(8)

          Button {
            visible: root.reporting
            text: "I did the moves"
            onClicked: {
              if (root.standService) root.standService.completeBreak(true)
            }
          }

          Button {
            text: root.reporting ? "I skipped" : "Skip"
            onClicked: root.dismiss()
          }
        }

        Row {
          anchors.horizontalCenter: parent.horizontalCenter
          spacing: Style.space(8)

          Button {
            visible: !root.reporting && !root.snoozed
            text: "Later"
            onClicked: {
              if (root.standService) root.standService.snooze()
            }
          }
        }

        Text {
          textFormat: Text.PlainText
          width: parent.width
          horizontalAlignment: Text.AlignHCenter
          wrapMode: Text.WordWrap
          opacity: 0.45
          text: "Move gently. Nothing here should ever hurt - skip it if it does. Esc to dismiss."
          color: root.foreground
          font.family: Style.font.menuFamily
          font.pixelSize: Style.font.caption
        }

        Item {
          id: keyCatcher
          width: 1
          height: 1
          focus: true
          Keys.priority: Keys.BeforeItem
          Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
              root.dismiss()
              event.accepted = true
            }
          }
        }
      }
    }
  }
}
