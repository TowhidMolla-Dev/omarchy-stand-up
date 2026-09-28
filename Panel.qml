import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

// Settings panel for the Stand Up plugin. Loaded by BarWidget.qml, so it
// inherits Panel's opened/open/close/toggle from the shell and is
// positioned against the bar button.
Panel {
  id: root
  moduleName: "towhid.stand-up"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  // Injected when the bar widget hands its service over; otherwise looked
  // up from the shell.
  property var service: null

  readonly property var standService: root.service
    ? root.service
    : (root.bar && root.bar.shell ? root.bar.shell.serviceFor("towhid.stand-up") : null)

  readonly property color fg: root.barForeground

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.hostWidget || root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(300))
    contentHeight: panel.fittedContentHeight(content.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: content
        width: parent.width
        spacing: Style.space(12)

        // -------------------------------------------------- bar display
        Text {
          textFormat: Text.PlainText
          width: parent.width
          text: "Bar display"
          color: root.fg
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.subtitle
          font.bold: true
        }

        ButtonGroup {
          width: parent.width
          value: root.standService ? root.standService.barMode : "compact"
          options: [
            { value: "full", label: "Full" },
            { value: "compact", label: "Ring" },
            { value: "hover", label: "Hover" }
          ]
          onChanged: function(value) {
            if (root.standService) root.standService.setBarMode(value)
          }
        }

        Text {
          textFormat: Text.PlainText
          width: parent.width
          wrapMode: Text.WordWrap
          text: root.standService && root.standService.barMode === "compact"
            ? "Icon with a ring that fills as the stretch runs. No numbers, no hover needed."
            : (root.standService && root.standService.barMode === "hover"
                ? "Icon only until you hover it, then the countdown slides in."
                : "Icon plus the countdown, as before.")
          color: Util.alpha(root.fg, 0.6)
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.caption
        }

        // -------------------------------------------------- schedule
        Text {
          textFormat: Text.PlainText
          width: parent.width
          text: "Schedule"
          color: root.fg
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.subtitle
          font.bold: true
        }

        NumberField {
          label: "Stand up every (minutes)"
          value: root.standService ? root.standService.workMinutes : 45
          from: 5
          to: 180
          stepSize: 5
          foreground: root.fg
          onModified: function(v) {
            if (!root.standService) return
            root.standService.workMinutes = v
            root.standService.reapplySettings()
          }
        }

        NumberField {
          label: "Seconds per move"
          value: root.standService ? root.standService.moveSeconds : 30
          from: 10
          to: 180
          stepSize: 5
          foreground: root.fg
          onModified: function(v) {
            if (!root.standService) return
            root.standService.moveSeconds = v
          }
        }

        NumberField {
          label: "Snooze after (minutes)"
          value: root.standService ? root.standService.snoozeMinutes : 5
          from: 1
          to: 30
          stepSize: 1
          foreground: root.fg
          onModified: function(v) {
            if (!root.standService) return
            root.standService.snoozeMinutes = v
          }
        }

        // ------------------------------------------------ bar display
        Text {
          textFormat: Text.PlainText
          width: parent.width
          text: "Bar display"
          color: root.fg
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.subtitle
          font.bold: true
        }

        ButtonGroup {
          width: parent.width
          value: root.standService ? root.standService.barMode : "compact"
          options: [
            { value: "full", label: "Full" },
            { value: "compact", label: "Ring" },
            { value: "hover", label: "Hover" }
          ]
          onChanged: function(value) {
            if (root.standService) root.standService.setBarMode(value)
          }
        }

        Text {
          textFormat: Text.PlainText
          width: parent.width
          wrapMode: Text.WordWrap
          text: root.standService && root.standService.barMode === "compact"
            ? "Icon with a ring that fills as the countdown runs. No numbers, no hover needed."
            : (root.standService && root.standService.barMode === "hover"
                ? "Icon only until you hover it, then the timer slides in."
                : "Icon plus the countdown, as before.")
          color: Util.alpha(root.fg, 0.6)
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.caption
        }

        // ---------------------------------------------------- toggles
        Row {
          width: parent.width
          spacing: Style.space(10)

          Text {
            width: parent.width - Style.space(46)
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: "Sound"
            color: root.fg
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.body
          }

          ToggleSwitch {
            id: soundSwitch
            checked: root.standService ? root.standService.sound : true
            foreground: root.fg
            onToggled: {
              if (root.standService) root.standService.sound = !root.standService.sound
            }
          }
        }

        Row {
          width: parent.width
          spacing: Style.space(10)

          Text {
            width: parent.width - Style.space(46)
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: "Quiet hours"
            color: root.fg
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.body
          }

          ToggleSwitch {
            checked: root.standService ? root.standService.quietEnabled : true
            foreground: root.fg
            onToggled: {
              if (root.standService) {
                root.standService.quietEnabled = !root.standService.quietEnabled
                root.standService.scheduleSave()
              }
            }
          }
        }

        Row {
          width: parent.width
          spacing: Style.space(12)
          visible: root.standService ? root.standService.quietEnabled : true

          NumberField {
            label: "Quiet from (hour)"
            value: root.standService ? root.standService.quietStart : 22
            from: 0
            to: 23
            stepSize: 1
            foreground: root.fg
            onModified: function(v) {
              if (!root.standService) return
              root.standService.quietStart = v
              root.standService.scheduleSave()
            }
          }

          NumberField {
            label: "Until (hour)"
            value: root.standService ? root.standService.quietEnd : 8
            from: 0
            to: 23
            stepSize: 1
            foreground: root.fg
            onModified: function(v) {
              if (!root.standService) return
              root.standService.quietEnd = v
              root.standService.scheduleSave()
            }
          }
        }

        PanelSeparator { width: parent.width; foreground: root.fg }

        // ----------------------------------------------------- today
        Text {
          textFormat: Text.PlainText
          width: parent.width
          text: "Today"
          color: root.fg
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.subtitle
          font.bold: true
        }

        Text {
          textFormat: Text.PlainText
          width: parent.width
          wrapMode: Text.WordWrap
          text: root.standService
            ? (root.standService.completed + " done  ·  "
               + root.standService.skipped + " skipped  ·  "
               + (root.standService.adherence < 0
                  ? "no breaks yet"
                  : root.standService.adherence + "% adhered"))
            : ""
          color: root.fg
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.body
        }

        Text {
          textFormat: Text.PlainText
          width: parent.width
          wrapMode: Text.WordWrap
          opacity: 0.65
          text: root.standService
            ? "Next: " + root.standService.routine.title + " — " + root.standService.routine.focus
            : ""
          color: root.fg
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.caption
        }

        Row {
          anchors.horizontalCenter: parent.horizontalCenter
          spacing: Style.space(8)

          Button {
            text: "Try it now"
            foreground: root.fg
            onClicked: {
              if (root.standService) root.standService.preview()
            }
          }

          Button {
            text: root.standService && root.standService.paused ? "Resume" : "Pause"
            foreground: root.fg
            onClicked: {
              if (root.standService) root.standService.toggle()
            }
          }
        }

        Button {
          anchors.horizontalCenter: parent.horizontalCenter
          text: "Reset today's stats"
          foreground: root.fg
          onClicked: {
            if (root.standService) root.standService.resetStats()
          }
        }

        Text {
          textFormat: Text.PlainText
          width: parent.width
          wrapMode: Text.WordWrap
          opacity: 0.45
          text: "A wellness habit, not medical advice. Move gently and skip anything that hurts."
          color: root.fg
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.caption
        }
      }
    }
  }
}
