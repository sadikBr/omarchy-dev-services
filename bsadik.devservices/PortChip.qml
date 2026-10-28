import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// Clickable ":3000" pill that opens localhost:<port> in the browser.
BorderSurface {
  id: root

  property int port: 0
  property color foreground: Commons.Color.foreground
  property color accent: Commons.Color.accent
  property string fontFamily: Style.font.family

  signal clicked()

  implicitWidth: label.implicitWidth + Style.space(12)
  implicitHeight: label.implicitHeight + Style.space(4)
  radius: Style.cornerRadius > 0 ? height / 2 : 0
  color: mouse.containsMouse ? Util.alpha(root.accent, 0.25) : Util.alpha(root.accent, 0.12)
  borderSpec: Border.controlSpec(mouse.containsMouse ? "hover-cursor" : "normal", root.foreground, root.accent)

  Text {
    id: label
    anchors.centerIn: parent
    textFormat: Text.PlainText
    text: ":" + root.port
    color: root.accent
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.clicked()
  }
}
