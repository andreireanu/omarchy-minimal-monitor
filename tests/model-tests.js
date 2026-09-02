// Check that Model.js refuses to trust the collector's output.
//
// The fan list is built from strings the kernel supplies, so a fan is kept only
// when it carries a usable id and rpm, and its text is forced to one short
// plain line before anything renders it.
//
// Run it from a clone:  node tests/model-tests.js
"use strict"

const fs = require("fs")
const path = require("path")
const vm = require("vm")

// .pragma library is a QML directive; Node does not know it. Running the rest
// in a bare context puts every function on `Model`, the way QML sees them.
const source = fs
  .readFileSync(path.join(__dirname, "..", "Model.js"), "utf8")
  .replace(/^\.pragma library\s*/, "")
const Model = vm.createContext({})
vm.runInContext(source, Model)
const parse = Model.parse

let failed = 0
function check(name, condition) {
  console.log((condition ? "  ok    " : "  FAIL  ") + name)
  if (!condition) failed++
}

function reading(fans) {
  return JSON.stringify({ cpu: 1, temp: null, mem: 1, fans: fans })
}

let r = parse(reading([{ id: "a/fan1", chip: "a", label: "Fan <b>x</b>\tone", rpm: 3000 }]))
check("markup characters leave the label", !/[<>&]/.test(r.fans[0].label))
check("the label is one line", !/[\n\r\t]/.test(r.fans[0].label))

r = parse(reading([
  { id: "", label: "no id", rpm: 1 },
  { label: "no id at all", rpm: 1 },
  { id: "a/fan1", rpm: "abc" },
  { id: "a/fan2", rpm: -5 },
  { id: "good/fan1", rpm: 900 }
]))
check("a fan without a usable id or rpm is dropped", r.fans.length === 1)
check("the good fan survives", r.fans[0].id === "good/fan1")
check("a missing label becomes Fan", r.fans[0].label === "Fan")

r = parse(reading([{ id: "a/fan1", label: { nested: 1 }, rpm: 1 }]))
check("a label that is not a string becomes Fan", r.fans[0].label === "Fan")

r = parse(reading([{ id: "a/fan1", label: "z".repeat(500), rpm: 1 }]))
check("a long label is capped at 64", r.fans[0].label.length === 64)

const many = []
for (let i = 0; i < 100; i++) many.push({ id: "a/fan" + i, label: "F", rpm: 1 })
check("the fan list is capped at 32", parse(reading(many)).fans.length === 32)

r = parse('{"cpu":1,"temp":null,"mem":1,"fans":"not an array"}')
check("fans that are not a list become empty", Array.isArray(r.fans) && r.fans.length === 0)

r = parse("this is not JSON")
check("a broken line reads as empty", r.fans.length === 0 && r.cpu === null)

console.log("")
console.log(failed === 0 ? "all checks passed" : "THERE ARE FAILURES")
process.exit(failed === 0 ? 0 : 1)
