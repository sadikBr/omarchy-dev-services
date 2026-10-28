import QtQuick
import Quickshell
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "Dev.js" as D

// Bar entry for dev services. A docker glyph plus the number of running
// containers and listening dev servers; dimmed when nothing is running.
//
//   left click    open the popup
//   right click   refresh now
//   middle click  stop all running containers
BarWidget {
  id: root
  moduleName: "bsadik.devservices"

  // The service is created by the shell independently of the widget, and a
  // plugin reload recreates it, so keep looking it up until it is there.
  property var service: null
  property bool popupOpen: false

  readonly property bool ready: service !== null && service.loaded === true
  readonly property int count: ready ? service.activeCount : 0

  readonly property color barColor: root.bar ? root.bar.barForeground : Commons.Color.foreground
  readonly property color fg: root.bar ? root.bar.foreground : Commons.Color.foreground
  readonly property color accent: Commons.Color.accent
  readonly property string fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
  readonly property string iconFamily: "JetBrainsMono Nerd Font"

  readonly property color glyphColor: count > 0 ? barColor : Util.alpha(barColor, 0.45)
  readonly property string label: count > 0 ? String(count) : ""

  readonly property string tooltip: !ready ? "Dev services"
    : "Dev services · " + service.summary() + "\nRight-click to refresh"

  // Shape contract for shell.summon/hide/toggle routing: the bar looks for
  // open/close/opened on the widget root and picks the copy on the focused
  // monitor.
  readonly property bool opened: popupOpen
  function close() { popupOpen = false }
  function open() { popupOpen = true }

  // Tell the service a popup is watching so it polls fast while open.
  property bool watching: false
  function syncWatch() {
    var want = root.popupOpen && root.service !== null
    if (want === root.watching) return
    root.watching = want
    if (root.service) root.service.watch(want)
  }
  onPopupOpenChanged: syncWatch()
  onServiceChanged: { root.watching = false; syncWatch() }
  Component.onDestruction: if (root.watching && root.service) root.service.watch(false)

  function findService() {
    if (!root.bar || !root.bar.shell) return
    var s = root.bar.shell.serviceFor(root.moduleName) || null
    if (s !== root.service) root.service = s
  }

  Timer {
    interval: root.service ? 2000 : 400
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: root.findService()
  }

  implicitWidth: vertical ? barSize : row.implicitWidth + Style.space(14)
  implicitHeight: vertical ? column.implicitHeight + Style.space(10) : barSize

  Row {
    id: row
    visible: !root.vertical
    anchors.centerIn: parent
    spacing: Style.space(5)

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: D.icons.docker
      color: root.glyphColor
      font.family: root.iconFamily
      font.pixelSize: Style.font.body + 2
      Behavior on color {
        enabled: !root.bar || root.bar.foregroundAnimationEnabled
        ColorAnimation { duration: 160 }
      }
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      visible: root.label !== ""
      textFormat: Text.PlainText
      text: root.label
      color: root.barColor
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
    }
  }

  Column {
    id: column
    visible: root.vertical
    anchors.centerIn: parent
    spacing: Style.space(2)

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: D.icons.docker
      color: root.glyphColor
      font.family: root.iconFamily
      font.pixelSize: Style.font.body + 2
    }

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      visible: root.label !== ""
      textFormat: Text.PlainText
      text: root.label
      color: root.barColor
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
    }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

    onClicked: function(mouse) {
      if (mouse.button === Qt.RightButton) { if (root.service) root.service.refresh() }
      else if (mouse.button === Qt.MiddleButton) { if (root.ready) root.service.stopAllContainers() }
      else root.popupOpen = !root.popupOpen
    }
    onEntered: if (root.bar) root.bar.showTooltip(root, root.tooltip)
    onExited: if (root.bar) root.bar.hideTooltip(root)
  }

  PopupCard {
    id: popup
    anchorItem: root
    bar: root.bar
    owner: root
    open: root.popupOpen
    contentWidth: popup.fittedContentWidth(Style.space(440))
    contentHeight: popup.fittedContentHeight(panel.implicitHeight, Style.space(620))

    Flickable {
      anchors.fill: parent
      contentWidth: width
      contentHeight: panel.implicitHeight
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      interactive: contentHeight > height

      DevPanel {
        id: panel
        width: parent.width
        service: root.service
        foreground: root.fg
        accent: root.accent
        fontFamily: root.fontFamily
        iconFamily: root.iconFamily
      }
    }
  }
}
