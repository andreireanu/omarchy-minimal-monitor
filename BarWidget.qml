import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
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

  // The bar clips nothing and pushes nothing aside, so the widget caps itself.
  // Tunable per screen from shell.json, the same way omarchy.active-window does.
  // This is the text width; the button adds its own padding around it.
  readonly property int maxLabelWidth: Number(setting("maxWidth", 300))

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

  onBarChanged: {
    injectPanel()
    pickLabel()   // the bar carries the font the label is measured in
  }

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

  // Measures a candidate read-out in the bar's own font, so the choice below
  // is made against real drawn width rather than a character count.
  TextMetrics {
    id: metrics
    // Same font the bar draws with, so the measurement matches what appears.
    font.family: root.bar ? root.bar.fontFamily : Style.font.family
    font.pixelSize: Style.font.body
  }

  // The fullest read-out that fits. Whole metrics are dropped rather than the
  // text being elided mid-glyph; the panel still lists every reading.
  //
  // Deliberately a function rather than a binding: choosing needs to write
  // metrics.text and read metrics.width, and a binding that does both loops.
  property string barLabel: ""

  function pickLabel() {
    const options = Model.candidates(root.reading, root.visibleMetrics)
    for (var i = 0; i < options.length; i++) {
      metrics.text = options[i]
      if (metrics.width <= root.maxLabelWidth) {
        root.barLabel = options[i]
        return
      }
    }
    root.barLabel = options[options.length - 1]
  }

  onReadingChanged: pickLabel()
  onVisibleMetricsChanged: pickLabel()
  onMaxLabelWidthChanged: pickLabel()
  Component.onCompleted: pickLabel()

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.barLabel
    tooltipText: Model.tooltip(root.reading)
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.LeftButton) root.toggle()
      else if (buttonCode === Qt.RightButton) root.showRpmUnit = !root.showRpmUnit
    }
  }
}
