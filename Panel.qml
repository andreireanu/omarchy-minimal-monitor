import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "io.github.andreireanu.minimal-monitor"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null

  readonly property var w: hostWidget

  readonly property var rows:
    Model.rows(hostWidget ? hostWidget.reading : Model.EMPTY)

  function open() { root.controller.show() }
  function close() { root.controller.hide() }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.hostWidget || root, direction)
    return false
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.hostWidget || root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(260))
    contentHeight: panel.fittedContentHeight(content.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: content
        width: parent.width
        spacing: Style.space(8)

        Text {
          width: parent.width
          text: "Minimal Monitor"
          color: root.barForeground
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.subtitle
          font.bold: true
        }

        Text {
          width: parent.width
          visible: root.rows.length === 0
          text: "No readings yet."
          wrapMode: Text.WordWrap
          color: root.barForeground
          opacity: 0.7
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.body
        }

        // One line per reading, laid out like the hover tooltip, with a tick
        // that decides whether it also appears in the bar. Unticking only
        // takes it off the bar; the reading stays here.
        // One line per reading, laid out like the hover tooltip, with a tick
        // that decides whether it also appears in the bar. Unticking only
        // takes it off the bar; the reading stays here.
        //
        // The click target is the delegate itself: a MouseArea placed inside a
        // RowLayout would be laid out as another column and squeeze the text.
        Repeater {
          model: root.rows

          delegate: MouseArea {
            id: readingRow
            required property var modelData

            width: content.width
            implicitHeight: line.implicitHeight
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              if (root.w) root.w.toggleMetric(modelData.key)
            }

            readonly property bool shown:
              root.w ? root.w.metricShown(modelData.key) : true

            RowLayout {
              id: line
              anchors.fill: parent
              spacing: Style.space(8)

              Rectangle {
                Layout.preferredWidth: Style.space(13)
                Layout.preferredHeight: Style.space(13)
                radius: Style.space(3)
                color: readingRow.shown ? root.barForeground : "transparent"
                border.width: 1
                border.color: root.barForeground
                opacity: readingRow.shown ? 1.0 : 0.45
              }

              Text {
                Layout.fillWidth: true
                text: readingRow.modelData.label + ": " + readingRow.modelData.value
                elide: Text.ElideRight
                color: root.barForeground
                opacity: readingRow.modelData.dim
                  ? 0.5
                  : (readingRow.shown ? 1.0 : 0.55)
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.body
              }
            }
          }
        }
      }
    }
  }
}
