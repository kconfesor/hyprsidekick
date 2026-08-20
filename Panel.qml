import QtQuick
import Quickshell.Hyprland
import qs.Commons
import qs.Ui
import "Model.js" as Model

// The workspace dropdown. Left-clicking the pill (Aerospace.qml) opens this.
// Named mnemonics list first, then active numbered workspaces; a row click
// jumps to that workspace. Anchored to the pill via KeyboardPanel, the same
// popout primitive the first-party clock uses.
Panel {
  id: root
  moduleName: "kconfesor.aerospace"
  ipcTarget: "kconfesor.aerospace"
  manageIpc: false

  // Set by Aerospace.injectPanel().
  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  readonly property string labelFormat: setting("labelFormat", "key-name")
  readonly property var workspacesConfig: setting("workspaces", [])
  readonly property bool showNumbered: setting("showNumbered", true)

  readonly property var focusedWs: Hyprland.focusedWorkspace
  readonly property string focusedName: focusedWs ? focusedWs.name : ""
  readonly property int focusedId: focusedWs ? focusedWs.id : -1

  readonly property color contentForeground: bar ? bar.foreground : Color.foreground
  readonly property string contentFontFamily: bar ? bar.fontFamily : Style.font.family

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
    if (!root.showNumbered) return named
    return named.concat(Model.numberedRows(live, root.focusedId))
  }

  function jump(row) {
    // This Hyprland (Omarchy "Quattro", Lua config) rejects the classic
    // `hyprctl dispatch workspace <id>` syntax; dispatch through the Lua
    // helper instead, exactly as the stock omarchy.workspaces widget does.
    if (root.bar) root.bar.run("hyprctl dispatch " + root.bar.shellQuote("hl.dsp.focus({ workspace = \"" + Model.jumpTarget(row) + "\" })"))
    root.close()
  }

  function rgbaFg(alpha) {
    var c = root.contentForeground
    return Qt.rgba(c.r, c.g, c.b, alpha)
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    centerOnBar: false
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(320))
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
          topPadding: Style.space(8)
          bottomPadding: Style.space(8)
          spacing: Style.space(2)

          Repeater {
            model: root.rows

            Rectangle {
              id: rowItem
              required property var modelData
              width: listColumn.width
              height: Style.space(30)
              radius: Style.space(6)
              color: modelData.focused ? root.rgbaFg(0.16)
                   : (rowMouse.containsMouse ? root.rgbaFg(0.08) : "transparent")

              Row {
                anchors.left: parent.left
                anchors.leftMargin: Style.space(10)
                anchors.right: parent.right
                anchors.rightMargin: Style.space(10)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(8)

                Text {
                  width: Style.space(22)
                  text: rowItem.modelData.key
                  color: root.contentForeground
                  opacity: 0.55
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.body
                  verticalAlignment: Text.AlignVCenter
                }

                Text {
                  text: rowItem.modelData.name
                  color: root.contentForeground
                  opacity: rowItem.modelData.occupied || rowItem.modelData.focused ? 1 : 0.5
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.body
                  verticalAlignment: Text.AlignVCenter
                }
              }

              Rectangle {
                visible: rowItem.modelData.occupied
                anchors.right: parent.right
                anchors.rightMargin: Style.space(12)
                anchors.verticalCenter: parent.verticalCenter
                width: Style.space(6)
                height: Style.space(6)
                radius: width / 2
                color: root.contentForeground
                opacity: 0.7
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
        }
      }
    }
  }
}
