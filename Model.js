// Pure workspace-model helpers for kconfesor.aerospace.
//
// No QML imports and no `.pragma` here: the same file loads in the shell via
// `import "Model.js" as Model` and in node tests via a Function() wrapper.

// One row per configured workspace, joined to live Hyprland state BY NAME.
// This name-join is the fix for the stock widget, which drops named
// workspaces by filtering on numeric id.
//   config: [{ key, name, icon }]
//   live:   [{ id, name, occupied }]
//   focusedName: string|null
function namedRows(config, live, focusedName) {
  var byName = {}
  for (var i = 0; i < live.length; i++) byName[live[i].name] = live[i]

  var rows = []
  for (var j = 0; j < config.length; j++) {
    var c = config[j]
    var w = byName[c.name] || null
    rows.push({
      kind: "named",
      key: c.key || "",
      name: c.name,
      icon: c.icon || "",
      exists: w !== null,
      occupied: w !== null && w.occupied === true,
      focused: focusedName !== null && focusedName !== undefined && focusedName === c.name
    })
  }
  return rows
}

// Active numeric workspaces 1..10, sorted ascending; the focused numeric id is
// always included even if it has no windows yet.
function numberedRows(live, focusedId) {
  var byId = {}
  var ids = []
  for (var i = 0; i < live.length; i++) {
    var id = live[i].id
    if (id > 0 && id <= 10 && !byId[id]) { byId[id] = live[i]; ids.push(id) }
  }
  if (focusedId > 0 && focusedId <= 10 && !byId[focusedId]) {
    byId[focusedId] = { id: focusedId, name: String(focusedId), occupied: false }
    ids.push(focusedId)
  }
  ids.sort(function(a, b) { return a - b })

  var rows = []
  for (var k = 0; k < ids.length; k++) {
    var w = byId[ids[k]]
    rows.push({
      kind: "numbered",
      key: String(ids[k]),
      name: String(ids[k]),
      icon: "",
      exists: true,
      occupied: w && w.occupied === true,
      focused: ids[k] === focusedId
    })
  }
  return rows
}

// Resolve a display label for a row given the configured format.
//   "key" | "name" | "key-name" | "icon" | any string containing
//   {key}/{name}/{icon} (templated verbatim).
function pillLabel(row, format) {
  if (!row) return ""
  var f = format || "name"
  if (f.indexOf("{") !== -1) {
    return f.replace(/\{key\}/g, row.key || "")
            .replace(/\{name\}/g, row.name || "")
            .replace(/\{icon\}/g, row.icon || "")
  }
  switch (f) {
    case "key": return row.key || row.name || ""
    case "icon": return row.icon || row.name || ""
    case "key-name": return row.key ? (row.key + "·" + row.name) : (row.name || "")
    case "name":
    default: return row.name || ""
  }
}

// Argument for `hyprctl dispatch workspace <target>`.
function jumpTarget(row) {
  if (!row) return ""
  return row.kind === "named" ? ("name:" + row.name) : String(row.name)
}
