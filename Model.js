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
      fans: sanitizeFans(doc.fans)
    }
  } catch (e) {
    return EMPTY
  }
}

// The fan list comes from a shell script reading kernel-supplied strings, so
// nothing in it is trusted on sight. A fan is kept only if it has a usable id
// and rpm; its text is forced to a plain, single-line, bounded string. Anything
// that fails is dropped rather than repaired, so a broken chip cannot rename
// another one.
function sanitizeFans(list) {
  if (!Array.isArray(list)) return []
  var out = []
  for (var i = 0; i < list.length && out.length < 32; i++) {
    var fan = list[i]
    if (!fan || typeof fan !== "object") continue
    var id = plainString(fan.id)
    var rpm = numberOrNull(fan.rpm)
    if (id === "" || rpm === null || rpm < 0) continue
    var label = plainString(fan.label)
    out.push({
      id: id,
      chip: plainString(fan.chip),
      label: label === "" ? "Fan" : label,
      rpm: rpm
    })
  }
  return out
}

// One line, no control characters, no markup a rich-text sink could act on,
// and short enough to belong in a bar.
function plainString(value) {
  if (typeof value !== "string") return ""
  return value
    .replace(/[\x00-\x1f\x7f]/g, " ")
    .replace(/[<>&]/g, " ")
    .replace(/\s+/g, " ")
    .trim()
    .slice(0, 64)
}

// Settings arrive from shell.json as whatever JSON held, and a hand-edited
// file may hold the string "false", which is truthy in JavaScript.
function truthy(value) {
  if (typeof value === "boolean") return value
  if (typeof value === "number") return value !== 0
  if (typeof value === "string") {
    var v = value.trim().toLowerCase()
    return !(v === "" || v === "false" || v === "0" || v === "no" || v === "off")
  }
  return !!value
}

// A fan is drawn unless its id was ticked off. `hiddenFans` is whatever
// shell.json held, so treat anything that is not a list as "hide nothing".
function fanShown(fan, show) {
  if (!show || show.fans === false) return false
  var hidden = show.hiddenFans
  if (!Array.isArray(hidden)) return true
  return hidden.indexOf(fan.id) === -1
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
  for (var i = 0; i < reading.fans.length; i++) {
    if (!fanShown(reading.fans[i], show)) continue
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

// The bar has no collision handling at all: the clock is pinned to the screen
// midpoint and the side sections are pinned to the edges, so a wide read-out
// simply paints over the clock. The widget therefore has to fit itself.
//
// Rather than eliding mid-glyph, drop whole metrics. These are the read-outs
// from fullest to shortest; the caller picks the first one that fits, and the
// panel always lists everything regardless.
function candidates(reading, show) {
  var ladder = [
    { cpu: 1, temp: 1, mem: 1, fans: 1, rpmUnit: 1 },
    { cpu: 1, temp: 1, mem: 1, fans: 1, rpmUnit: 0 },
    { cpu: 1, temp: 1, mem: 1, fans: 0, rpmUnit: 0 },
    { cpu: 1, temp: 1, mem: 0, fans: 0, rpmUnit: 0 },
    { cpu: 1, temp: 0, mem: 0, fans: 0, rpmUnit: 0 }
  ]

  var out = []
  var seen = {}
  for (var i = 0; i < ladder.length; i++) {
    var step = ladder[i]
    var text = barText(reading, {
      // A metric the user switched off never comes back just because there
      // is room for it.
      cpu: show.cpu && step.cpu,
      temp: show.temp && step.temp,
      mem: show.mem && step.mem,
      fans: show.fans && step.fans,
      hiddenFans: show.hiddenFans,
      rpmUnit: show.rpmUnit && step.rpmUnit,
      iconGap: show.iconGap,
      metricGap: show.metricGap
    })
    if (!seen[text]) {
      seen[text] = true
      out.push(text)
    }
  }
  return out
}

// Every reading the machine offers, whether or not it is shown in the bar.
// `key` names the setting that decides that, so a row can carry its own tick.
function rows(reading) {
  if (!reading) return []
  var out = []
  if (reading.cpu !== null)
    out.push({ label: "CPU", value: reading.cpu + " %", dim: false, key: "showCpu" })
  if (reading.temp !== null)
    out.push({ label: "Temperature", value: reading.temp + " °C", dim: false, key: "showTemp" })
  if (reading.mem !== null)
    out.push({ label: "Memory", value: reading.mem + " %", dim: false, key: "showMem" })
  for (var i = 0; i < reading.fans.length; i++) {
    var fan = reading.fans[i]
    out.push({
      key: "fan:" + fan.id,
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
