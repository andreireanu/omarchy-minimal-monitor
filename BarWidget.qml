import QtQuick
import QtQuick.Window
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
  // Upper bound, so the read-out cannot sprawl across a very wide screen.
  readonly property int maxLabelWidth: Number(setting("maxWidth", 420))

  // Room to leave around the centred clock. The bar exposes no way to ask how
  // wide the centre section is, so this is the one number that has to be
  // guessed; everything else below is measured.
  readonly property int centerReserve: Number(setting("centerReserve", 130))

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

  // How much width the read-out may take before it reaches the clock.
  //
  // The bar anchors its side sections to the screen edges and pins the clock to
  // the midpoint, so the edge of this widget that faces away from the centre
  // stays put no matter how the label grows or shrinks - the widgets beyond it
  // decide where it sits. Measuring from there is stable and needs no loop.
  function availableWidth() {
    const windowWidth = root.Window.width
    if (!windowWidth || root.width <= 0) return root.maxLabelWidth

    const origin = root.mapToItem(null, 0, 0)
    if (!origin) return root.maxLabelWidth

    const middle = windowWidth / 2
    const onTheRight = origin.x + root.width / 2 > middle

    // Distance from the outer edge inwards, less the space kept for the clock.
    const room = onTheRight
      ? (origin.x + root.width) - middle - root.centerReserve
      : middle - root.centerReserve - origin.x

    return Math.max(40, Math.min(root.maxLabelWidth, room))
  }

  function pickLabel() {
    const options = Model.candidates(root.reading, root.visibleMetrics)
    const budget = availableWidth()

    for (var i = 0; i < options.length; i++) {
      metrics.text = options[i]
      if (metrics.width <= budget) {
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

  // At startup the widget has no geometry yet, so the first choice is made
  // blind. Re-choose once the bar has laid itself out.
  Timer {
    interval: 400
    repeat: false
    running: true
    onTriggered: root.pickLabel()
  }

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
