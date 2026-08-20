import QtQuick
import Quickshell.Hyprland
import qs.Commons
import qs.Ui
import "Model.js" as Model

// AeroSpace-style workspace pill: shows the active named/numbered workspace,
// left-click opens the dropdown (Panel.qml, wired in Task 4). Named
// workspaces are matched by name, so the stock widget's numeric-only filter
// no longer hides them.
BarWidget {
  id: root
  moduleName: "kconfesor.aerospace"

  readonly property string labelFormat: setting("labelFormat", "key-name")
  readonly property var workspacesConfig: setting("workspaces", [])

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

  // ---- Popout contract (delegates to Panel.qml; item is null until Task 4).
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  function open() { if (panelLoader.item) panelLoader.item.open() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function togglePanel() { if (panelLoader.item) panelLoader.item.toggle() }
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false
  function closeForPopoutSwitch() { if (panelLoader.item) panelLoader.item.closeForPopoutSwitch() }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight
  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  // Panel.qml is added in Task 4. Until then this Loader stays inactive so the
  // widget renders standalone.
  Loader {
    id: panelLoader
    active: false
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: { root.injectPanel(); Qt.callLater(root.injectPanel) }
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
