// Pure workspace-model helpers for kconfesor.hyprsidekick.
//
// No QML imports and no `.pragma` here: the same file loads in the shell via
// `import "Model.js" as Model` and in node tests via a Function() wrapper.

// Starter workspaces for a fresh install. The shell does NOT apply the
// manifest's barWidget.defaults to a bare entry, so this is the real fallback
// used everywhere `setting("workspaces", …)` is read — a new user immediately
// sees named workspaces instead of an empty widget.
function defaultWorkspaces() {
  return [
    { key: "W", name: "web", icon: "" },
    { key: "G", name: "G", icon: "" },
    { key: "E", name: "E", icon: "" },
    { key: "C", name: "C", icon: "" }
  ]
}

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

// A fixed range of numbered workspaces 1..count, whether or not they exist
// yet. Existing ones carry their occupied/focused state; the rest are empty
// placeholders (clicking one creates it).
function numberedRange(live, focusedId, count) {
  var byId = {}
  for (var i = 0; i < live.length; i++) if (live[i].id > 0) byId[live[i].id] = live[i]

  var n = Number(count)
  if (!isFinite(n) || n < 0) n = 0

  var rows = []
  for (var id = 1; id <= n; id++) {
    var w = byId[id] || null
    rows.push({
      kind: "numbered",
      key: String(id),
      name: String(id),
      icon: "",
      exists: w !== null,
      occupied: w !== null && w.occupied === true,
      focused: id === focusedId
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
    // Collapse "C·C" (key == name, e.g. a single-letter named workspace) to "C".
    case "key-name": return (row.key && row.key !== row.name) ? (row.key + "·" + row.name) : (row.name || "")
    case "name":
    default: return row.name || ""
  }
}

// Escape a string so it is safe inside a Lua double-quoted literal (backslash,
// quote, and newlines) — used both for the generated binds file and for the
// click-to-jump `hl.dsp.focus` dispatch.
function luaEsc(s) {
  return String(s == null ? "" : s)
    .replace(/\\/g, "\\\\").replace(/"/g, "\\\"")
    .replace(/\n/g, "\\n").replace(/\r/g, "\\r")
}
// True if the string contains any control character (NUL, newline, etc.).
function hasControlChar(s) { return /[\x00-\x1f\x7f]/.test(String(s == null ? "" : s)) }

// Whitelist the bind modifier: a "+"-joined combo of known Hyprland modifier
// tokens only. Anything else (unknown token, injection attempt) falls back to
// "ALT". Returns a canonical "SUPER + ALT" form.
function safeMod(mod) {
  var allowed = { SUPER: 1, ALT: 1, CTRL: 1, SHIFT: 1, META: 1 }
  var toks = String(mod == null ? "" : mod).split("+")
  var out = []
  for (var i = 0; i < toks.length; i++) {
    var t = toks[i].trim().toUpperCase()
    if (t === "") continue
    if (!allowed[t]) return "ALT"
    out.push(t)
  }
  return out.length ? out.join(" + ") : "ALT"
}

// A bind key must be a bare alphanumeric token (W, 1, F5). Reject anything else
// so it can't break out of the generated `<mod> + <key>` bind string.
function validKey(k) { return /^[A-Za-z0-9]+$/.test(String(k == null ? "" : k)) }

// Build the Hyprland Lua binds file. Every value is strictly validated: keys
// must be alphanumeric, names may not contain control characters, and the
// modifier is whitelisted — invalid workspaces are skipped rather than emitted.
function hyprBindsLua(workspaces, mod) {
  var m = safeMod(mod)
  var lines = [
    "-- Generated by kconfesor.hyprsidekick. Do not edit; use the Settings panel.",
    "-- Regenerated on apply; manual edits here are overwritten.",
    ""
  ]
  for (var i = 0; i < (workspaces || []).length; i++) {
    var w = workspaces[i] || {}
    var key = String(w.key || "").trim()
    var name = String(w.name || "").trim()
    if (!key || !name) continue
    if (!validKey(key)) continue
    if (hasControlChar(key) || hasControlChar(name)) continue
    var en = luaEsc(name)
    lines.push('o.bind("' + m + ' + ' + key + '", "Switch to ' + en + ' workspace", hl.dsp.focus({ workspace = "name:' + en + '" }))')
    lines.push('o.bind("' + m + ' + SHIFT + ' + key + '", "Move window to ' + en + ' workspace", hl.dsp.window.move({ workspace = "name:' + en + '" }))')
  }
  lines.push("")
  return lines.join("\n")
}

// Validate a bar section against the fixed allowlist before it is ever placed
// into a shell command. Anything else collapses to "left".
function safeSection(s) {
  var v = String(s == null ? "" : s).trim().toLowerCase()
  return (v === "left" || v === "center" || v === "right") ? v : "left"
}

// Argument for `hyprctl dispatch workspace <target>`.
function jumpTarget(row) {
  if (!row) return ""
  return row.kind === "named" ? ("name:" + row.name) : String(row.name)
}
