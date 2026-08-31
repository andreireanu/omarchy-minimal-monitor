// Development harness. Omarchy is not needed: this draws the same read-out in a
// plain window so the widget can be seen and tuned on any Wayland desktop.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "Model.js" as Model

ShellRoot {
  id: shell

  property var reading: Model.EMPTY

  // The installed widget inherits the Omarchy bar font. The harness has no
  // bar, so it asks fontconfig which Nerd Font this machine actually has.
  property string devFont: "monospace"

  Process {
    command: [String(Qt.resolvedUrl("dev/devfont")).replace("file://", "")]
    running: true
    stdout: SplitParser {
      onRead: data => {
        const name = data.trim()
        if (name.length > 0) shell.devFont = name
      }
    }
  }

  readonly property var visibleMetrics: ({
    cpu: true, temp: true, mem: true, fans: true, rpmUnit: true,
    iconGap: " ", metricGap: "  "
  })

  readonly property string readerPath:
    String(Qt.resolvedUrl("scripts/sysread")).replace("file://", "")

  Process {
    id: reader
    command: [shell.readerPath, "--loop", "--interval", "1"]
    running: true
    stdout: SplitParser {
      onRead: data => {
        const parsed = Model.parse(data)
        if (Model.hasReading(parsed)) shell.reading = parsed
      }
    }
  }

  FloatingWindow {
    id: window
    title: "omarchy-minimal-monitor preview"
    // FloatingWindow reads these once, at startup, before the first reading
    // arrives — so they cannot track the text. Fixed and roomy instead; the
    // window is resizable if a machine has more fans than this fits.
    implicitWidth: 900
    implicitHeight: 440
    color: "#1a1b26"

    Column {
      id: preview
      width: parent.width
      anchors.verticalCenter: parent.verticalCenter
      spacing: 24

      // What the Omarchy bar will show.
      Rectangle {
        id: pill
        anchors.horizontalCenter: parent.horizontalCenter
        width: barText.implicitWidth + 28
        height: barText.implicitHeight + 14
        radius: 6
        color: "#24283b"

        Text {
          id: barText
          anchors.centerIn: parent
          text: Model.barText(shell.reading, shell.visibleMetrics)
          color: "#c0caf5"
          font.family: shell.devFont
          font.pixelSize: 20
        }
      }

      // What the click panel will show.
      Column {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 6

        Repeater {
          model: Model.rows(shell.reading)
          delegate: RowLayout {
            required property var modelData
            width: 340
            spacing: 16

            Text {
              Layout.fillWidth: true
              text: modelData.label
              color: "#7f88b0"
              font.family: shell.devFont
              font.pixelSize: 14
            }
            Text {
              text: modelData.value
              color: modelData.dim ? "#7f88b0" : "#c0caf5"
              font.family: shell.devFont
              font.pixelSize: 14
              font.bold: !modelData.dim
            }
          }
        }
      }

    }
  }
}
