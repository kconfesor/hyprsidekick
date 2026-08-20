import QtQuick
import qs.Commons
import qs.Ui

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
      workspaces: ws
    }
    // Apply locally first, then write through the shell so shell.json and the
    // other panels stay in step (same pattern as omarchy.clock).
    root.settings = entry
    if (root.hostWidget && "settings" in root.hostWidget) root.hostWidget.settings = entry
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
      root.bar.shell.updateEntryInline(root.moduleName, entry)
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
