import QtQuick
import Quickshell
import Quickshell.Io
import qs.Ui
import "Model.js" as Model

BarWidget {
  id: root
  moduleName: "io.github.andreireanu.minimal-monitor"

  readonly property bool opened: panelLoader.item
    ? panelLoader.item.opened === true
    : false
  readonly property bool popoutSwitchClosing: panelLoader.item
    ? panelLoader.item.popoutSwitchClosing === true
    : false

  property var reading: Model.EMPTY

  // Which metrics reach the bar. The panel always lists everything.
  property bool showCpu: true
  property bool showTemp: true
  property bool showMem: true
  property bool showFans: true
  property bool showRpmUnit: true

  // Icon widths differ between bar fonts, so both gaps are settable from
  // shell.json rather than baked into the read-out.
  property string iconGap: " "
  property string metricGap: " "

  readonly property var visibleMetrics: ({
    cpu: root.showCpu,
    temp: root.showTemp,
    mem: root.showMem,
    fans: root.showFans,
    rpmUnit: root.showRpmUnit,
    iconGap: root.iconGap,
    metricGap: root.metricGap
  })

  function open() { if (panelLoader.item) panelLoader.item.open() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function toggle() { if (panelLoader.item) panelLoader.item.toggle() }
  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  function injectPanel() {
    if (!panelLoader.item) return
    panelLoader.item.bar = root.bar
    panelLoader.item.anchorItem = button
    panelLoader.item.hostWidget = root
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()

  // These numbers move slowly. Poll lazily until the panel is open.
  readonly property int pollSeconds: opened ? 1 : 3
  readonly property string readerPath:
    String(Qt.resolvedUrl("scripts/sysread")).replace("file://", "")

  Process {
    id: reader
    command: [root.readerPath, "--loop", "--interval", String(root.pollSeconds)]
    running: true

    stdout: SplitParser {
      onRead: data => {
        const parsed = Model.parse(data)
        // Keep the last good reading rather than flashing "n/a" on one bad line.
        if (Model.hasReading(parsed)) root.reading = parsed
      }
    }
  }

  onPollSecondsChanged: {
    reader.running = false
    reader.command = [root.readerPath, "--loop", "--interval", String(pollSeconds)]
    reader.running = true
  }

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

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: Model.barText(root.reading, root.visibleMetrics)
    tooltipText: Model.tooltip(root.reading)
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.LeftButton) root.toggle()
      else if (buttonCode === Qt.RightButton) root.showRpmUnit = !root.showRpmUnit
    }
  }
}
