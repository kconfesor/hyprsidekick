import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.Commons
import qs.Ui
import "Model.js" as Model

// Mnemonic workspace pill: shows the active named/numbered workspace, left-click
// opens the dropdown (Panel.qml). Named workspaces are matched by name, so the
// stock widget's numeric-only filter no longer hides them. Also hosts the
// Settings panel and the durable config file (see below).
BarWidget {
  id: root
  moduleName: "kconfesor.hyprsidekick"

  readonly property string labelFormat: setting("labelFormat", "key-name")
  readonly property var workspacesConfig: setting("workspaces", [])

  // Durable config, survives `omarchy plugin disable/enable` (which deletes the
  // shell.json entry). The file is the source of truth; shell.json is the live
  // injection surface the pill/dropdown read. On load we restore shell.json from
  // the file if they diverged (i.e. we were reset to manifest defaults).
  readonly property string configPath: Quickshell.env("HOME") + "/.config/hyprsidekick/config.json"
  property var fileConfig: undefined
  property bool fileLoaded: false

  readonly property var focusedWs: Hyprland.focusedWorkspace
  readonly property string focusedName: focusedWs ? focusedWs.name : ""
  readonly property int focusedId: focusedWs ? focusedWs.id : -1

  // Live workspaces flattened to plain objects so Model.js stays QML-free.
  function livePlain() {
    var out = []
    var values = Hyprland.workspaces ? Hyprland.workspaces.values : []
    for (var i = 0; i < values.length; i++) {
      var w = values[i]
      out.push({
        id: w.id,
        name: w.name,
        occupied: w.toplevels && w.toplevels.values.length > 0
      })
    }
    return out
  }

  // The row describing the active workspace, for the pill label.
  readonly property var activeRow: {
    // Touch the reactive singletons so this binding recomputes on change.
    var values = Hyprland.workspaces ? Hyprland.workspaces.values : []
    var _tick = root.focusedName + ":" + (values ? values.length : 0)

    var named = Model.namedRows(root.workspacesConfig, root.livePlain(), root.focusedName)
    for (var i = 0; i < named.length; i++) if (named[i].focused) return named[i]

    // Focused workspace is numbered, or a named one not in config: never blank.
    return {
      kind: root.focusedId > 0 ? "numbered" : "named",
      key: "",
      name: root.focusedName || String(root.focusedId),
      icon: "",
      exists: true,
      occupied: true,
      focused: true
    }
  }

  readonly property string pillText: Model.pillLabel(root.activeRow, root.labelFormat)

  // ---- Popout contract. The dropdown (Panel.qml) and the settings panel
  // (Settings.qml) both use this widget as their KeyboardPanel `owner`, so the
  // outside-click dismiss routes `owner.close()` here — it must close WHICHEVER
  // panel is open, not just the dropdown, or the other stays stuck with a focus
  // grab.
  readonly property bool opened: (panelLoader.item && panelLoader.item.opened === true)
    || (settingsLoader.item && settingsLoader.item.opened === true)
  function open() { if (panelLoader.item) panelLoader.item.open() }
  function close() {
    if (panelLoader.item) panelLoader.item.close()
    if (settingsLoader.item) settingsLoader.item.close()
  }
  function togglePanel() { if (panelLoader.item) panelLoader.item.toggle() }
  readonly property bool popoutSwitchClosing: (panelLoader.item && panelLoader.item.popoutSwitchClosing === true)
    || (settingsLoader.item && settingsLoader.item.popoutSwitchClosing === true)
  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
    if (settingsLoader.item) settingsLoader.item.closeForPopoutSwitch()
  }

  function injectInto(target) {
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }
  function injectPanel() { injectInto(panelLoader.item) }
  function injectSettings() { injectInto(settingsLoader.item) }

  // The dropdown's footer calls this to open the Settings panel (closing the
  // dropdown first — one popout at a time).
  function openSettings() {
    if (panelLoader.item) panelLoader.item.close()
    if (settingsLoader.item) settingsLoader.item.open()
  }
  function closeSettings() { if (settingsLoader.item) settingsLoader.item.close() }

  // ---- durable config (survives disable/enable) ---------------------------

  // Full entry from the current shell.json settings.
  function settingsEntry() {
    return {
      id: root.moduleName,
      labelFormat: setting("labelFormat", "key-name"),
      numberedMode: setting("numberedMode", "active"),
      numberedCount: setting("numberedCount", 9),
      hideStockWidget: setting("hideStockWidget", true),
      barSection: setting("barSection", "left"),
      workspaces: setting("workspaces", [])
    }
  }
  // Normalized entry from the durable file.
  function fileEntry() {
    var fc = root.fileConfig || {}
    return {
      id: root.moduleName,
      labelFormat: fc.labelFormat !== undefined ? fc.labelFormat : "key-name",
      numberedMode: fc.numberedMode !== undefined ? fc.numberedMode : "active",
      numberedCount: fc.numberedCount !== undefined ? fc.numberedCount : 9,
      hideStockWidget: fc.hideStockWidget !== undefined ? fc.hideStockWidget : true,
      barSection: fc.barSection !== undefined ? fc.barSection : "left",
      workspaces: fc.workspaces || []
    }
  }
  // Write the durable file (UTF-8 safe via FileView.setText). Called by
  // Settings on commit; the dir is ensured in reconcile().
  function writeConfig(entry) {
    cfgFile.setText(JSON.stringify(entry, null, 2) + "\n")
  }
  // If the file has config that shell.json lost (post reset), restore it and
  // re-apply the side effects the reset dropped (stock hidden, section).
  function syncFromFile() {
    if (!root.bar || !root.fileConfig) return
    var fe = root.fileEntry()
    if (!fe.workspaces || fe.workspaces.length === 0) return
    if (JSON.stringify(root.settingsEntry()) === JSON.stringify(fe)) return
    if (root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
      root.bar.shell.updateEntryInline(root.moduleName, fe)
    if (fe.hideStockWidget) root.bar.run("omarchy plugin disable omarchy.workspaces")
    root.bar.run("omarchy bar move kconfesor.hyprsidekick --section " + fe.barSection)
  }
  // Runs when the file has settled AND the bar is available.
  function reconcile() {
    if (!root.bar || !root.fileLoaded) return
    root.bar.run("mkdir -p \"$HOME/.config/hyprsidekick\"")
    if (root.fileConfig) root.syncFromFile()
    else Qt.callLater(function() { root.writeConfig(root.settingsEntry()) }) // first run: seed
  }

  FileView {
    id: cfgFile
    path: root.configPath
    watchChanges: true
    printErrors: false
    onLoaded: {
      try { root.fileConfig = JSON.parse(text()) } catch (e) { root.fileConfig = null }
      root.fileLoaded = true
      root.reconcile()
    }
    onLoadFailed: { root.fileConfig = null; root.fileLoaded = true; root.reconcile() }
    onFileChanged: reload()
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight
  onBarChanged: { injectPanel(); injectSettings(); reconcile() }
  onSettingsChanged: { injectPanel(); injectSettings() }

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: { root.injectPanel(); Qt.callLater(root.injectPanel) }
  }

  Loader {
    id: settingsLoader
    active: true
    source: Qt.resolvedUrl("Settings.qml")
    visible: false
    onLoaded: { root.injectSettings(); Qt.callLater(root.injectSettings) }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.pillText
    active: true
    tooltipText: "Workspaces"
    horizontalMargin: 8.75
    verticalPadding: 8.75
    onPressed: function(b) { root.togglePanel() }
  }
}
