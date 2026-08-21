import QtQuick
import QtQuick.Controls as QQC
import qs.Commons
import qs.Ui
import "Model.js" as Model

// Hyprsidekick settings panel: edit workspaces (key / name / icon) and display
// options. Edits preview live (pill + dropdown update via hostWidget.settings)
// but only commit to shell.json on Done; Cancel reverts to the on-open
// snapshot. Duplicate mnemonics are flagged and block Done/Apply. Opened from
// the dropdown's "Settings" footer.
Panel {
  id: root
  moduleName: "kconfesor.hyprsidekick"
  manageIpc: false

  // Set by Widget.injectSettings().
  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  readonly property color fg: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  // Working copy.
  property string wLabelFormat: "key-name"
  property string wNumberedMode: "range"
  property int wNumberedCount: 9
  property bool wHideStock: true
  property string wSection: "left"
  property bool wAccentActive: false
  property string wBindMod: "ALT"

  // Committed state captured on open, for Cancel.
  property var snapshot: null
  // Binds signature at open, to decide whether Done must re-apply to Hyprland.
  property string snapshotBindsSig: ""
  // Keys that appear on more than one workspace (bind conflicts).
  property var dupKeys: []
  readonly property bool hasDups: dupKeys.length > 0

  ListModel { id: wsModel }

  readonly property var labelFormatOptions: [
    { value: "key", label: "Key  (W)" },
    { value: "name", label: "Name  (web)" },
    { value: "key-name", label: "Key·Name" },
    { value: "icon", label: "Icon" }
  ]
  readonly property var numberedModeOptions: [
    { value: "range", label: "Show 1–N" },
    { value: "active", label: "Only active" },
    { value: "hidden", label: "Hidden" }
  ]
  // Modifier for the generated <mod>+<key> binds. Omarchy uses Super for its
  // numbered workspaces and Super+letter for apps, so Alt is the safe default.
  // (No option includes Shift — the move bind appends Shift itself.)
  readonly property var modifierOptions: [
    { value: "ALT", label: "Alt" },
    { value: "SUPER", label: "Super" },
    { value: "CTRL", label: "Ctrl" },
    { value: "SUPER + ALT", label: "Super + Alt" }
  ]
  readonly property var sectionOptions: [
    { value: "left", label: "Left" },
    { value: "center", label: "Center" },
    { value: "right", label: "Right" }
  ]
  // Curated workspace glyphs (Material Design Icons in the Nerd Font
  // F0001–F1AF0 block, which JetBrainsMono Nerd Font covers fully). Built from
  // codepoints so the source carries no literal PUA characters to get mangled.
  readonly property var iconOptions: {
    var cps = [
      0,        // none
      0xf059f,  // web
      0xf018d,  // terminal
      0xf0169,  // code
      0xf0379,  // monitor
      0xf0b79,  // chat
      0xf075a,  // music
      0xf01ee,  // mail
      0xf024b,  // folder
      0xf0493,  // settings
      0xf02b4,  // game
      0xf03d8,  // design
      0xf082e,  // notes
      0xf02dc,  // home
      0xf04ce,  // star
      0xf02d1,  // heart
      0xf02a2,  // git
      0xf01bc,  // database
      0xf02e9,  // image
      0xf0567,  // video
      0xf00ed,  // calendar
      0xf0770   // terminal/bash
    ]
    var out = []
    for (var i = 0; i < cps.length; i++) {
      var g = cps[i] === 0 ? "" : String.fromCodePoint(cps[i])
      out.push({ value: g, label: cps[i] === 0 ? "—" : g })
    }
    return out
  }

  // ---- state helpers ------------------------------------------------------

  function buildEntry() {
    var ws = []
    for (var i = 0; i < wsModel.count; i++) {
      var it = wsModel.get(i)
      ws.push({ key: it.key, name: it.name, icon: it.icon })
    }
    return {
      id: root.moduleName,
      labelFormat: root.wLabelFormat,
      numberedMode: root.wNumberedMode,
      numberedCount: root.wNumberedCount,
      hideStockWidget: root.wHideStock,
      barSection: root.wSection,
      accentActive: root.wAccentActive,
      bindMod: root.wBindMod,
      workspaces: ws
    }
  }

  // Live preview only (pill/dropdown update); no shell.json write.
  function previewEntry(e) {
    root.settings = e
    if (root.hostWidget && "settings" in root.hostWidget) root.hostWidget.settings = e
  }
  // Persist to shell.json (live) AND the durable config file (survives
  // disable/enable) via the host widget.
  function commitEntry(e) {
    previewEntry(e)
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
      root.bar.shell.updateEntryInline(root.moduleName, e)
    if (root.hostWidget && typeof root.hostWidget.writeConfig === "function")
      root.hostWidget.writeConfig(e)
  }

  function recomputeDups() {
    var counts = {}, dups = []
    for (var i = 0; i < wsModel.count; i++) {
      var k = String(wsModel.get(i).key || "").trim()
      if (!k) continue
      counts[k] = (counts[k] || 0) + 1
    }
    for (var kk in counts) if (counts[kk] > 1) dups.push(kk)
    dupKeys = dups
  }
  function isDupKey(k) {
    var t = String(k || "").trim()
    return t !== "" && dupKeys.indexOf(t) >= 0
  }

  // Called after every field edit: refresh dup state + live preview.
  function touch() { recomputeDups(); previewEntry(buildEntry()) }

  function loadFromSettings() {
    wsModel.clear()
    var ws = setting("workspaces", Model.defaultWorkspaces())
    for (var i = 0; i < ws.length; i++)
      wsModel.append({ key: ws[i].key || "", name: ws[i].name || "", icon: ws[i].icon || "" })
    wLabelFormat = setting("labelFormat", "key-name")
    wNumberedMode = setting("numberedMode", "active")
    wNumberedCount = setting("numberedCount", 9)
    wHideStock = setting("hideStockWidget", true)
    wSection = setting("barSection", "left")
    wAccentActive = setting("accentActive", false)
    wBindMod = setting("bindMod", "ALT")
    recomputeDups()
  }

  function addWorkspace() { wsModel.append({ key: "", name: "new", icon: "" }); touch() }
  function removeWorkspace(i) { if (i >= 0 && i < wsModel.count) { wsModel.remove(i); touch() } }
  function setField(i, role, value) { if (i >= 0 && i < wsModel.count) { wsModel.setProperty(i, role, value); touch() } }

  // Order-independent signature of the key→name bindings (only workspaces with
  // both fields are bound). Used to detect when the Hyprland binds went stale.
  function sigFromWs(arr) {
    var parts = []
    var a = arr || []
    for (var i = 0; i < a.length; i++) {
      var w = a[i] || {}
      var k = String(w.key || "").trim(), n = String(w.name || "").trim()
      if (k && n) parts.push(k + "\t" + n)
    }
    parts.sort()
    return parts.join("\n")
  }
  // Full binds signature = modifier + the key→name set; either changing means
  // the generated Hyprland binds are stale.
  function bindsSigOf(mod, wsArr) { return String(mod || "ALT") + "\n" + sigFromWs(wsArr) }

  function open() {
    loadFromSettings()
    snapshot = buildEntry()
    snapshotBindsSig = bindsSigOf(snapshot.bindMod, snapshot.workspaces)
    root.controller.show()
  }

  function done() {
    if (root.hasDups) return
    var entry = buildEntry()
    commitEntry(entry)
    // Only touch Hyprland when the bindings (modifier or key→name) changed.
    if (bindsSigOf(entry.bindMod, entry.workspaces) !== snapshotBindsSig) writeBinds()
    root.close()
  }

  function cancel() {
    if (snapshot) {
      previewEntry(snapshot)
      var snapHide = snapshot.hideStockWidget !== false
      if (snapHide !== root.wHideStock) { root.wHideStock = snapHide; applyStockVisibility() }
    }
    root.close()
  }

  // ---- stock widget + hyprland (immediate, deliberate actions) ------------

  function applyStockVisibility() {
    if (!root.bar) return
    if (root.wHideStock)
      root.bar.run("omarchy plugin disable omarchy.workspaces")
    else
      root.bar.run("omarchy plugin enable omarchy.workspaces && omarchy bar move omarchy.workspaces --section left --index 1")
  }
  // Immediate structural actions persist right away (they take effect now, so
  // config.json must reflect them, or the durable self-heal would fight them).
  function setHideStock(v) { root.wHideStock = v; commitEntry(buildEntry()); applyStockVisibility() }

  // Move the widget between bar sections (preserves its config).
  function setSection(v) {
    var s = Model.safeSection(v)
    root.wSection = s
    commitEntry(buildEntry())
    if (root.bar) root.bar.run("omarchy bar move kconfesor.hyprsidekick --section " + s)
  }

  // Regenerate ~/.config/hypr/hyprsidekick.lua from the workspace list, make
  // sure bindings.lua loads it (one-time, idempotent), and reload Hyprland.
  function writeBinds() {
    if (!root.bar) return
    var ws = []
    for (var i = 0; i < wsModel.count; i++) { var it = wsModel.get(i); ws.push({ key: it.key, name: it.name }) }
    var luaB64 = Qt.btoa(Model.hyprBindsLua(ws, root.wBindMod))
    // Write ONLY the plugin's own generated file, and do it atomically: a fresh
    // mktemp'd file plus `mv -f` replaces (never follows) a symlink at the
    // destination, with no check-then-open gap to race. We deliberately do NOT
    // write the user's bindings.lua; we only read it to check for the require
    // line and, if missing, notify the user to add it themselves.
    root.bar.run(
      "d=\"$HOME/.config/hypr\"; mkdir -p \"$d\"; f=\"$d/hyprsidekick.lua\"; b=\"$d/bindings.lua\"; " +
      "t=$(mktemp \"$d/.hyprsidekick.lua.XXXXXX\") && printf %s " + luaB64 + " | base64 -d > \"$t\" && " +
      "mv -f \"$t\" \"$f\" && hyprctl reload; " +
      "grep -qF hypr.hyprsidekick \"$b\" 2>/dev/null || " +
      "omarchy-notification-send -u normal 'Hyprsidekick' " +
      "'Add  require(\"hypr.hyprsidekick\")  to ~/.config/hypr/bindings.lua to enable the keybinds.'")
  }

  function applyToHyprland() {
    if (root.hasDups) return
    commitEntry(buildEntry()) // applying binds implies keeping the config
    writeBinds()
  }

  function disableSelf() {
    if (!root.bar) return
    root.close()
    root.bar.run(
      "omarchy-notification-send -u normal 'Hyprsidekick disabled' " +
      "'Re-enable from the Omarchy menu → Setup → Plugins → Enable Plugin'; " +
      "omarchy plugin enable omarchy.workspaces && " +
      "omarchy bar move omarchy.workspaces --section left --index 1 && " +
      "omarchy plugin disable kconfesor.hyprsidekick")
  }

  // ---- layout -------------------------------------------------------------

  readonly property int footerH: Style.space(30)

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    centerOnBar: false
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(400))
    contentHeight: panel.fittedContentHeight(Math.min(form.implicitHeight, Style.space(680)) + root.footerH + Style.space(12))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: true

      // blocked:true forwards keys to the text fields, which also swallows the
      // panel's own Escape handling — restore Escape-to-close explicitly.
      Shortcut {
        sequence: "Escape"
        onActivated: root.close()
      }

      // Scrolling form (everything except the pinned footer).
      Flickable {
        id: flick
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: footer.top
        anchors.bottomMargin: Style.space(8)
        contentWidth: width
        contentHeight: form.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        // Visible scroll cue when the form overflows.
        QQC.ScrollBar.vertical: QQC.ScrollBar {
          policy: QQC.ScrollBar.AsNeeded
          width: Style.space(6)
          contentItem: Rectangle {
            radius: width / 2
            color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.45)
          }
        }

        Column {
          id: form
          width: parent.width
          spacing: Style.space(8)

          PanelSectionHeader { text: "WORKSPACES"; foreground: root.fg; fontFamily: root.fontFamily }

          Text {
            visible: root.hasDups
            width: form.width
            text: "Duplicate mnemonic: " + root.dupKeys.join(", ") + " — each key must be unique."
            color: root.urgent
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
          }

          Repeater {
            model: wsModel

            Item {
              required property int index
              required property string key
              required property string name
              required property string icon
              width: form.width
              height: keyField.implicitHeight

              TextField {
                id: keyField
                anchors.left: parent.left
                width: Style.space(36)
                text: parent.key
                placeholderText: "K"
                foreground: root.isDupKey(parent.key) ? root.urgent : root.fg
                verticalPadding: Style.space(4)
                onEditingFinished: root.setField(parent.index, "key", text)
              }
              PanelActionButton {
                id: removeBtn
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                iconText: "󰅖"
                tooltipText: "Remove"
                foreground: root.fg
                hoverColor: root.urgent
                onClicked: root.removeWorkspace(parent.index)
              }
              Dropdown {
                id: iconPick
                anchors.right: removeBtn.left
                anchors.rightMargin: Style.space(6)
                anchors.verticalCenter: parent.verticalCenter
                width: Style.space(70)
                label: ""
                value: parent.icon
                options: root.iconOptions
                foreground: root.fg
                onChanged: function(v) { root.setField(parent.index, "icon", v) }
              }
              TextField {
                id: nameField
                anchors.left: keyField.right
                anchors.leftMargin: Style.space(6)
                anchors.right: iconPick.left
                anchors.rightMargin: Style.space(6)
                anchors.verticalCenter: parent.verticalCenter
                text: parent.name
                placeholderText: "name"
                foreground: root.fg
                verticalPadding: Style.space(4)
                onEditingFinished: root.setField(parent.index, "name", text)
              }
            }
          }

          Button {
            text: "Add workspace"
            iconText: "󰐕"
            bordered: true
            leftAlign: true
            foreground: root.fg
            onClicked: root.addWorkspace()
          }

          PanelSeparator { foreground: root.fg }

          PanelSectionHeader { text: "DISPLAY"; foreground: root.fg; fontFamily: root.fontFamily }

          Dropdown {
            label: "Label format"
            value: root.wLabelFormat
            options: root.labelFormatOptions
            foreground: root.fg
            onChanged: function(v) { root.wLabelFormat = v; root.touch() }
          }
          Dropdown {
            label: "Numbered"
            value: root.wNumberedMode
            options: root.numberedModeOptions
            foreground: root.fg
            onChanged: function(v) { root.wNumberedMode = v; root.touch() }
          }
          NumberField {
            visible: root.wNumberedMode === "range"
            label: "Count"
            value: root.wNumberedCount
            from: 0
            to: 20
            foreground: root.fg
            onModified: function(v) { root.wNumberedCount = v; root.touch() }
          }

          PanelSeparator { foreground: root.fg }

          PanelSectionHeader { text: "BAR"; foreground: root.fg; fontFamily: root.fontFamily }

          Dropdown {
            label: "Position"
            value: root.wSection
            options: root.sectionOptions
            foreground: root.fg
            onChanged: function(v) { root.setSection(v) }
          }

          Item {
            width: form.width
            height: stockToggle.height
            Text {
              anchors.left: parent.left
              anchors.right: stockToggle.left
              anchors.rightMargin: Style.space(8)
              anchors.verticalCenter: parent.verticalCenter
              text: "Hide default workspaces widget"
              color: root.fg
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              elide: Text.ElideRight
              verticalAlignment: Text.AlignVCenter
            }
            ToggleSwitch {
              id: stockToggle
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              checked: root.wHideStock
              onToggled: root.setHideStock(!root.wHideStock)
            }
          }

          Item {
            width: form.width
            height: accentToggle.height
            Text {
              anchors.left: parent.left
              anchors.right: accentToggle.left
              anchors.rightMargin: Style.space(8)
              anchors.verticalCenter: parent.verticalCenter
              text: "Accent color on the bar"
              color: root.fg
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              elide: Text.ElideRight
              verticalAlignment: Text.AlignVCenter
            }
            ToggleSwitch {
              id: accentToggle
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              checked: root.wAccentActive
              onToggled: { root.wAccentActive = !root.wAccentActive; root.touch() }
            }
          }

          PanelSeparator { foreground: root.fg }

          PanelSectionHeader { text: "HYPRLAND"; foreground: root.fg; fontFamily: root.fontFamily }

          Dropdown {
            label: "Modifier (<mod> + key)"
            value: root.wBindMod
            options: root.modifierOptions
            foreground: root.fg
            onChanged: function(v) { root.wBindMod = v; root.touch() }
          }

          Button {
            text: "Apply to Hyprland (reload binds)"
            iconText: "󰑓"
            bordered: true
            leftAlign: true
            enabled: !root.hasDups
            foreground: root.fg
            onClicked: root.applyToHyprland()
          }

          Button {
            text: "Disable Hyprsidekick (restore default)"
            bordered: true
            leftAlign: true
            foreground: root.fg
            onClicked: root.disableSelf()
          }
        }
      }

      // Pinned footer — always visible regardless of list length.
      Item {
        id: footer
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: root.footerH

        Button {
          id: cancelBtn
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          text: "Cancel"
          bordered: true
          foreground: root.fg
          onClicked: root.cancel()
        }
        Button {
          id: doneBtn
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          text: "Done"
          bordered: true
          enabled: !root.hasDups
          foreground: root.fg
          onClicked: root.done()
        }
      }
    }
  }
}
