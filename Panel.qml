import QtQuick
import Quickshell.Hyprland
import qs.Commons
import qs.Ui
import "Model.js" as Model

// The workspace dropdown. Left-clicking the pill (Widget.qml) opens this.
// Named mnemonics list first, then active numbered workspaces; a row click
// jumps to that workspace. Anchored to the pill via KeyboardPanel, the same
// popout primitive the first-party clock uses.
Panel {
  id: root
  moduleName: "kconfesor.hyprsidekick"
  ipcTarget: "kconfesor.hyprsidekick"
  manageIpc: false

  // Set by Widget.injectPanel().
  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  readonly property string labelFormat: setting("labelFormat", "key-name")
  readonly property var workspacesConfig: setting("workspaces", Model.defaultWorkspaces())
  // "range" (always 1..numberedCount) | "active" (only occupied/focused) | "hidden"
  readonly property string numberedMode: setting("numberedMode", "active")
  readonly property int numberedCount: setting("numberedCount", 9)

  readonly property var focusedWs: Hyprland.focusedWorkspace
  readonly property string focusedName: focusedWs ? focusedWs.name : ""
  readonly property int focusedId: focusedWs ? focusedWs.id : -1

  readonly property color contentForeground: bar ? bar.foreground : Color.foreground
  readonly property string contentFontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property color accent: Color.accent

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

  readonly property var rows: {
    var values = Hyprland.workspaces ? Hyprland.workspaces.values : []
    var _tick = root.focusedName + ":" + (values ? values.length : 0)
    var live = root.livePlain()
    var named = Model.namedRows(root.workspacesConfig, live, root.focusedName)
    var numbered = root.numberedMode === "hidden" ? []
      : (root.numberedMode === "active" ? Model.numberedRows(live, root.focusedId)
      : Model.numberedRange(live, root.focusedId, root.numberedCount))
    return named.concat(numbered)
  }

  function jump(row) {
    // This Hyprland (Omarchy "Quattro", Lua config) rejects the classic
    // `hyprctl dispatch workspace <id>` syntax; dispatch through the Lua
    // helper instead, exactly as the stock omarchy.workspaces widget does.
    // NB: shellQuote lives on Util (qs.Commons), not on `bar`. The workspace
    // target is Lua-escaped so a crafted name can't break out of the string and
    // inject Lua into the dispatch, then the whole expression is shell-quoted.
    if (!root.bar) return
    var target = Model.luaEsc(Model.jumpTarget(row))
    root.bar.run("hyprctl dispatch " + Util.shellQuote("hl.dsp.focus({ workspace = \"" + target + "\" })"))
    root.close()
  }

  function rgbaFg(alpha) {
    var c = root.contentForeground
    return Qt.rgba(c.r, c.g, c.b, alpha)
  }

  function rgbaAccent(alpha) {
    var c = root.accent
    return Qt.rgba(c.r, c.g, c.b, alpha)
  }

  function openSettings() {
    // Hand off to the host widget, which closes this dropdown and opens the
    // Settings panel (one popout at a time).
    root.close()
    if (root.hostWidget && root.hostWidget.openSettings) root.hostWidget.openSettings()
  }

  readonly property int rowHeight: Style.space(28)

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    centerOnBar: false
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(200))
    contentHeight: panel.fittedContentHeight(listColumn.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()

      Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: listColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        Column {
          id: listColumn
          width: parent.width
          spacing: Style.space(1)

          Repeater {
            model: root.rows

            Rectangle {
              id: rowItem
              required property var modelData
              width: listColumn.width
              height: root.rowHeight
              radius: Style.cornerRadius
              color: modelData.focused ? root.rgbaAccent(0.16)
                   : (rowMouse.containsMouse ? root.rgbaFg(0.08) : "transparent")

              Row {
                anchors.left: parent.left
                anchors.leftMargin: Style.space(9)
                anchors.right: parent.right
                anchors.rightMargin: Style.space(9)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(7)

                Text {
                  width: Style.space(16)
                  // Numbered rows have key == name; showing both reads as "1 1".
                  text: rowItem.modelData.key === rowItem.modelData.name ? "" : rowItem.modelData.key
                  textFormat: Text.PlainText
                  color: rowItem.modelData.focused ? root.accent : root.contentForeground
                  opacity: rowItem.modelData.focused ? 1 : 0.5
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: true
                  verticalAlignment: Text.AlignVCenter
                }

                Text {
                  visible: rowItem.modelData.icon !== ""
                  text: rowItem.modelData.icon
                  textFormat: Text.PlainText
                  color: rowItem.modelData.focused ? root.accent : root.contentForeground
                  opacity: rowItem.modelData.occupied || rowItem.modelData.focused ? 1 : 0.5
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.body
                  verticalAlignment: Text.AlignVCenter
                }

                Text {
                  text: rowItem.modelData.name
                  textFormat: Text.PlainText
                  color: rowItem.modelData.focused ? root.accent : root.contentForeground
                  opacity: rowItem.modelData.occupied || rowItem.modelData.focused ? 1 : 0.5
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.body
                  verticalAlignment: Text.AlignVCenter
                }
              }

              Rectangle {
                visible: rowItem.modelData.occupied
                anchors.right: parent.right
                anchors.rightMargin: Style.space(11)
                anchors.verticalCenter: parent.verticalCenter
                width: Style.space(5)
                height: Style.space(5)
                radius: width / 2
                color: rowItem.modelData.focused ? root.accent : root.contentForeground
                opacity: rowItem.modelData.focused ? 1 : 0.6
              }

              MouseArea {
                id: rowMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.jump(rowItem.modelData)
              }
            }
          }

          // Divider between the workspace list and the config action.
          Item {
            width: listColumn.width
            height: Style.space(9)
            PanelSeparator {
              anchors.verticalCenter: parent.verticalCenter
              foreground: root.contentForeground
            }
          }

          // Footer action: open the config file this widget reads from.
          Rectangle {
            id: configRow
            width: listColumn.width
            height: root.rowHeight
            radius: Style.cornerRadius
            color: configMouse.containsMouse ? root.rgbaFg(0.08) : "transparent"

            Row {
              anchors.left: parent.left
              anchors.leftMargin: Style.space(9)
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(7)

              Text {
                width: Style.space(16)
                text: "" // gear
                textFormat: Text.PlainText
                color: root.contentForeground
                opacity: 0.6
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
                verticalAlignment: Text.AlignVCenter
              }

              Text {
                text: "Settings"
                textFormat: Text.PlainText
                color: root.contentForeground
                opacity: 0.85
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.body
                verticalAlignment: Text.AlignVCenter
              }
            }

            MouseArea {
              id: configMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.openSettings()
            }
          }
        }
      }
    }
  }
}
