import QtQuick
import qs.Commons
import qs.Ui
import "Model.js" as Model

// Hyprsidekick settings panel: edit workspaces (key / name / icon) and display
// options (label format, numbered mode/count). Persists back to the widget's
// shell.json entry via the shell's updateEntryInline, so the pill and dropdown
// update live with no restart. Opened from the dropdown's "Settings" footer.
Panel {
  id: root
  moduleName: "kconfesor.hyprsidekick"
  manageIpc: false

  // Set by Widget.injectSettings().
  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  readonly property color fg: bar ? bar.foreground : Color.foreground
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  // Working copy of display settings (committed via persist()).
  property string wLabelFormat: "key-name"
  property string wNumberedMode: "range"
  property int wNumberedCount: 9
  property bool wHideStock: true

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

  function loadFromSettings() {
    wsModel.clear()
    var ws = setting("workspaces", [])
    for (var i = 0; i < ws.length; i++)
      wsModel.append({ key: ws[i].key || "", name: ws[i].name || "", icon: ws[i].icon || "" })
    wLabelFormat = setting("labelFormat", "key-name")
    wNumberedMode = setting("numberedMode", "range")
    wNumberedCount = setting("numberedCount", 9)
    wHideStock = setting("hideStockWidget", true)
  }

  function persist() {
    var ws = []
    for (var i = 0; i < wsModel.count; i++) {
      var it = wsModel.get(i)
      ws.push({ key: it.key, name: it.name, icon: it.icon })
    }
    var entry = {
      id: root.moduleName,
      labelFormat: root.wLabelFormat,
      numberedMode: root.wNumberedMode,
      numberedCount: root.wNumberedCount,
      hideStockWidget: root.wHideStock,
      workspaces: ws
    }
    // Apply locally first, then write through the shell so shell.json and the
    // other panels stay in step (same pattern as omarchy.clock).
    root.settings = entry
    if (root.hostWidget && "settings" in root.hostWidget) root.hostWidget.settings = entry
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
      root.bar.shell.updateEntryInline(root.moduleName, entry)
  }

  // Modifier for generated Hyprland binds (matches the user's existing setup).
  readonly property string bindMod: setting("bindMod", "ALT")

  // Regenerate ~/.config/hypr/hyprsidekick.lua from the current workspace list
  // and reload Hyprland. Content is base64'd to survive the bash handoff intact.
  function applyToHyprland() {
    var ws = []
    for (var i = 0; i < wsModel.count; i++) {
      var it = wsModel.get(i)
      ws.push({ key: it.key, name: it.name })
    }
    var content = Model.hyprBindsLua(ws, root.bindMod)
    if (root.bar)
      root.bar.run("printf %s " + Qt.btoa(content) + " | base64 -d > \"$HOME/.config/hypr/hyprsidekick.lua\" && hyprctl reload")
  }

  // Show/hide the stock omarchy.workspaces widget. Disabling removes it from
  // the bar layout; re-enabling restores it to the left, before this widget.
  function applyStockVisibility() {
    if (!root.bar) return
    if (root.wHideStock)
      root.bar.run("omarchy plugin disable omarchy.workspaces")
    else
      root.bar.run("omarchy plugin enable omarchy.workspaces && omarchy bar move omarchy.workspaces --section left --index 1")
  }

  function setHideStock(v) {
    root.wHideStock = v
    persist()
    applyStockVisibility()
  }

  // Off-switch: restore the stock widget and disable Hyprsidekick. Reversible
  // with `omarchy plugin enable kconfesor.hyprsidekick`.
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

  function addWorkspace() { wsModel.append({ key: "", name: "new", icon: "" }); persist() }
  function removeWorkspace(i) { if (i >= 0 && i < wsModel.count) { wsModel.remove(i); persist() } }
  function setField(i, role, value) { if (i >= 0 && i < wsModel.count) { wsModel.setProperty(i, role, value); persist() } }

  // Reload the working copy each time the panel opens.
  function open() { loadFromSettings(); root.controller.show() }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    centerOnBar: false
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(Math.min(form.implicitHeight, Style.space(520)))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      // Forward keys to the text fields; Escape/arrows are not panel actions here.
      blocked: true

      Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: form.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        Column {
          id: form
          width: parent.width
          spacing: Style.space(8)

          PanelSectionHeader { text: "WORKSPACES"; foreground: root.fg; fontFamily: root.fontFamily }

          Repeater {
            model: wsModel

            Row {
              required property int index
              required property string key
              required property string name
              required property string icon
              width: form.width
              spacing: Style.space(6)

              TextField {
                width: Style.space(40)
                text: parent.key
                placeholderText: "K"
                foreground: root.fg
                verticalPadding: Style.space(4)
                onEditingFinished: root.setField(parent.index, "key", text)
              }
              TextField {
                width: Style.space(150)
                text: parent.name
                placeholderText: "name"
                foreground: root.fg
                verticalPadding: Style.space(4)
                onEditingFinished: root.setField(parent.index, "name", text)
              }
              TextField {
                width: Style.space(52)
                text: parent.icon
                placeholderText: "icon"
                foreground: root.fg
                verticalPadding: Style.space(4)
                onEditingFinished: root.setField(parent.index, "icon", text)
              }
              PanelActionButton {
                iconText: "󰅛" // trash-can-outline
                tooltipText: "Remove"
                foreground: root.fg
                hoverColor: root.bar ? root.bar.urgent : Color.urgent
                onClicked: root.removeWorkspace(parent.index)
              }
            }
          }

          Button {
            text: "Add workspace"
            iconText: "󰄕" // plus
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
            onChanged: function(v) { root.wLabelFormat = v; root.persist() }
          }

          Dropdown {
            label: "Numbered"
            value: root.wNumberedMode
            options: root.numberedModeOptions
            foreground: root.fg
            onChanged: function(v) { root.wNumberedMode = v; root.persist() }
          }

          NumberField {
            visible: root.wNumberedMode === "range"
            label: "Count"
            value: root.wNumberedCount
            from: 0
            to: 20
            foreground: root.fg
            onModified: function(v) { root.wNumberedCount = v; root.persist() }
          }

          PanelSeparator { foreground: root.fg }

          PanelSectionHeader { text: "BAR"; foreground: root.fg; fontFamily: root.fontFamily }

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

          Button {
            text: "Disable Hyprsidekick (restore default)"
            bordered: true
            leftAlign: true
            foreground: root.fg
            onClicked: root.disableSelf()
          }

          PanelSeparator { foreground: root.fg }

          PanelSectionHeader { text: "HYPRLAND"; foreground: root.fg; fontFamily: root.fontFamily }

          Button {
            text: "Apply to Hyprland (reload binds)"
            iconText: "󰑓" // reload
            bordered: true
            leftAlign: true
            foreground: root.fg
            onClicked: root.applyToHyprland()
          }

          PanelSeparator { foreground: root.fg }

          Button {
            text: "Done"
            bordered: true
            foreground: root.fg
            onClicked: root.close()
          }
        }
      }
    }
  }
}
