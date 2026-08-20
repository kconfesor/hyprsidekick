const fs = require("fs")
const path = require("path")
const assert = require("assert")

// Load Model.js (plain ECMAScript, no QML deps) into this process.
const src = fs.readFileSync(path.join(__dirname, "..", "Model.js"), "utf8")
const factory = new Function(
  src + "\nreturn { namedRows, numberedRows, pillLabel, jumpTarget };"
)
const Model = factory()

let passed = 0
function check(name, fn) { fn(); passed++; console.log("ok - " + name) }

const config = [
  { key: "W", name: "web", icon: "" },
  { key: "G", name: "G", icon: "" },
]

check("namedRows marks focused + occupied by name", () => {
  const live = [
    { id: 1, name: "web", occupied: true },
    { id: 2, name: "1", occupied: true },
  ]
  const rows = Model.namedRows(config, live, "web")
  assert.strictEqual(rows.length, 2)
  assert.strictEqual(rows[0].name, "web")
  assert.strictEqual(rows[0].focused, true)
  assert.strictEqual(rows[0].occupied, true)
  assert.strictEqual(rows[0].exists, true)
  assert.strictEqual(rows[1].name, "G")
  assert.strictEqual(rows[1].exists, false)
  assert.strictEqual(rows[1].occupied, false)
  assert.strictEqual(rows[1].focused, false)
})

check("numberedRows returns sorted active numerics incl focused", () => {
  const live = [
    { id: 3, name: "3", occupied: true },
    { id: 1, name: "1", occupied: true },
  ]
  const rows = Model.numberedRows(live, 5)
  const keys = rows.map(r => r.key)
  assert.deepStrictEqual(keys, ["1", "3", "5"])
  assert.strictEqual(rows.find(r => r.key === "5").focused, true)
  assert.strictEqual(rows.find(r => r.key === "5").occupied, false)
  assert.strictEqual(rows.every(r => r.kind === "numbered"), true)
})

check("pillLabel honors each format", () => {
  const row = { kind: "named", key: "W", name: "web", icon: "◆" }
  assert.strictEqual(Model.pillLabel(row, "key"), "W")
  assert.strictEqual(Model.pillLabel(row, "name"), "web")
  assert.strictEqual(Model.pillLabel(row, "key-name"), "W·web")
  assert.strictEqual(Model.pillLabel(row, "icon"), "◆")
  assert.strictEqual(Model.pillLabel(row, "[{key}] {name}"), "[W] web")
})

check("pillLabel icon falls back to name when icon empty", () => {
  const row = { kind: "named", key: "W", name: "web", icon: "" }
  assert.strictEqual(Model.pillLabel(row, "icon"), "web")
})

check("jumpTarget prefixes named, bare numbered", () => {
  assert.strictEqual(Model.jumpTarget({ kind: "named", name: "web" }), "name:web")
  assert.strictEqual(Model.jumpTarget({ kind: "numbered", name: "5" }), "5")
})

console.log(`\n${passed} checks passed`)
