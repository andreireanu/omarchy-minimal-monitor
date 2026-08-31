.pragma library

// Nerd Font glyphs. How wide these draw depends on the bar font, so the gap
// after an icon and the gap between metrics are both settable rather than
// baked in.
var GLYPH = {
  cpu:  "\uf2db",        // nf-fa-microchip
  temp: "\uf2c9",        // nf-fa-thermometer_half
  mem:  "\uefc5",        // nf-md-memory (RAM stick)
  fan:  "\udb80\ude10"   // nf-md-fan
}

var DEFAULT_ICON_GAP = " "
var DEFAULT_METRIC_GAP = " "

// The thermometer is drawn narrower than the other icons but occupies the same
// cell, so it carries built-in trailing space. Trim the shared gap after it to
// keep every icon the same visual distance from its number.
// Measured at 40px in a Nerd Font: every icon advances one cell (24px) but
// draws wider — thermometer 24, fan 34, chip 37, RAM stick 42. Only the
// thermometer fits its cell, so only it can sit flush against its number.
// Trimming the fan as well made the glyph collide with the digits.
var GAP_TRIM = { cpu: 0, temp: 1, mem: 0, fan: 0 }

// Every metric ends on a full-width character — "%", "C", "M" — so one shared
// separator looks the same after each. A bare "°" is narrow and would leave a
// wider-looking gap, which is why the unit letter is kept.
var SEP_TRIM = { cpu: 0, temp: 0, mem: 0, fan: 0 }

function icon(kind, value, gap) {
  var base = (gap === undefined ? DEFAULT_ICON_GAP : gap)
  return GLYPH[kind] + base.slice(GAP_TRIM[kind] || 0) + value
}

var EMPTY = { cpu: null, temp: null, mem: null, fans: [] }

// Parse one line of `scripts/sysread`. Returns a well-formed reading on any
// bad input, so a single failed read never blanks the bar with an error.
function parse(line) {
  try {
    var doc = JSON.parse(line)
    return {
      cpu: numberOrNull(doc.cpu),
      temp: numberOrNull(doc.temp),
      mem: numberOrNull(doc.mem),
      fans: Array.isArray(doc.fans) ? doc.fans : []
    }
  } catch (e) {
    return EMPTY
  }
}

function numberOrNull(value) {
  return (typeof value === "number" && isFinite(value)) ? value : null
}

function hasReading(reading) {
  if (!reading) return false
  return reading.cpu !== null || reading.temp !== null
    || reading.mem !== null || reading.fans.length > 0
}

// Build the bar read-out. `show` selects which metrics appear, so the widget
// can be trimmed down without touching the collector.
function barText(reading, show) {
  if (!reading) return ""
  var gap = (show && show.iconGap !== undefined) ? show.iconGap : DEFAULT_ICON_GAP
  var sep = (show && show.metricGap !== undefined) ? show.metricGap : DEFAULT_METRIC_GAP
  var parts = []

  if (show.cpu && reading.cpu !== null)
    parts.push({ kind: "cpu", text: icon("cpu", reading.cpu + "%", gap) })
  if (show.temp && reading.temp !== null)
    parts.push({ kind: "temp", text: icon("temp", reading.temp + "°C", gap) })
  if (show.mem && reading.mem !== null)
    parts.push({ kind: "mem", text: icon("mem", reading.mem + "%", gap) })
  if (show.fans) {
    for (var i = 0; i < reading.fans.length; i++)
      parts.push({ kind: "fan", text: icon("fan", reading.fans[i].rpm
        + (show.rpmUnit ? " RPM" : ""), gap) })
  }

  if (parts.length === 0) return icon("cpu", "n/a", gap)

  // Join by hand: the separator depends on which metric precedes it.
  var out = parts[0].text
  for (var j = 1; j < parts.length; j++)
    out += sep.slice(SEP_TRIM[parts[j - 1].kind] || 0) + parts[j].text
  return out
}

function rows(reading) {
  if (!reading) return []
  var out = []
  if (reading.cpu !== null)
    out.push({ label: "CPU", value: reading.cpu + " %", dim: false })
  if (reading.temp !== null)
    out.push({ label: "Temperature", value: reading.temp + " °C", dim: false })
  if (reading.mem !== null)
    out.push({ label: "Memory", value: reading.mem + " %", dim: false })
  for (var i = 0; i < reading.fans.length; i++) {
    var fan = reading.fans[i]
    out.push({
      label: fan.label,
      // A stopped fan is worth flagging, not hiding.
      value: fan.rpm === 0 ? "stopped" : fan.rpm + " RPM",
      dim: fan.rpm === 0
    })
  }
  return out
}

function tooltip(reading) {
  var list = rows(reading)
  if (list.length === 0) return "No readings available"
  var lines = []
  for (var i = 0; i < list.length; i++)
    lines.push(list[i].label + ": " + list[i].value)
  return lines.join("\n")
}
