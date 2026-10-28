import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "Dev.js" as D

// Popup body: Docker containers (or why they can't be listed) and the dev
// servers the user has listening on TCP ports.
Column {
  id: root

  property var service: null
  property color foreground: Commons.Color.foreground
  property color accent: Commons.Color.accent
  property string fontFamily: Style.font.family
  property string iconFamily: "JetBrainsMono Nerd Font"

  readonly property bool ready: service !== null && service.loaded === true
  readonly property string dockerState: ready ? service.dockerState : "unknown"
  readonly property var containers: ready ? service.containers : []
  readonly property var servers: ready ? service.servers : []
  readonly property color muted: Qt.darker(foreground, 1.4)
  readonly property color urgent: Commons.Color.urgent
  readonly property string home: service ? service.home : ""

  spacing: Style.space(10)

  // ------------------------------------------------------------ header

  Item {
    width: parent.width
    height: Math.max(headerColumn.implicitHeight, refreshButton.height)

    Column {
      id: headerColumn
      anchors.left: parent.left
      anchors.right: refreshButton.left
      anchors.rightMargin: Style.space(8)
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(2)

      Text {
        textFormat: Text.PlainText
        text: "Dev services"
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.subtitle
        font.bold: true
      }

      Text {
        width: parent.width
        elide: Text.ElideRight
        textFormat: Text.PlainText
        text: root.ready ? root.service.summary() : "Loading…"
        color: root.muted
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
      }
    }

    PanelActionButton {
      id: refreshButton
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      iconText: D.icons.refresh
      tooltipText: "Refresh"
      fontFamily: root.iconFamily
      foreground: root.foreground
      enabled: root.service !== null && !root.service.refreshing
      onClicked: root.service.refresh()
    }
  }

  PanelSeparator { width: parent.width; foreground: root.foreground }

  // ------------------------------------------------------------ docker

  Item {
    width: parent.width
    height: Math.max(dockerHeader.implicitHeight, dockerActions.height)

    PanelSectionHeader {
      id: dockerHeader
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      text: "DOCKER"
      foreground: root.foreground
      fontFamily: root.fontFamily
    }

    Row {
      id: dockerActions
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(4)

      PanelActionButton {
        visible: root.ready && root.service.runningContainers.length > 0
        iconText: D.icons.stop
        tooltipText: "Stop all running containers"
        fontFamily: root.iconFamily
        foreground: root.foreground
        hoverColor: root.urgent
        enabled: root.ready && !root.service.isBusy("all")
        onClicked: root.service.stopAllContainers()
      }

      PanelActionButton {
        visible: root.dockerState === "running"
        iconText: D.icons.power
        tooltipText: "Stop the Docker daemon"
        fontFamily: root.iconFamily
        foreground: root.foreground
        hoverColor: root.urgent
        enabled: root.ready && !root.service.isBusy("daemon")
        onClicked: root.service.stopDocker()
      }
    }
  }

  // Why there is nothing to list, with the one action that fixes it.
  Column {
    width: parent.width
    spacing: Style.space(8)
    visible: root.ready && root.dockerState !== "running"

    Row {
      width: parent.width
      spacing: Style.space(8)

      Text {
        id: dockerAlertIcon
        text: D.icons.alert
        color: root.dockerState === "denied" ? root.urgent : root.muted
        font.family: root.iconFamily
        font.pixelSize: Style.font.icon
      }

      Text {
        width: parent.width - dockerAlertIcon.width - parent.spacing
        wrapMode: Text.WordWrap
        textFormat: Text.PlainText
        text: root.dockerState === "stopped" ? "The Docker daemon isn't running."
          : root.dockerState === "denied" ? "Docker is running, but your user can't reach its socket. Add yourself to the docker group, then log out and back in."
          : root.dockerState === "missing" ? "Docker isn't installed. Install it with: omarchy install docker"
          : "Couldn't read Docker's state."
        color: root.muted
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
      }
    }

    Button {
      visible: root.dockerState === "stopped" || root.dockerState === "denied"
      iconText: root.dockerState === "stopped" ? D.icons.play : D.icons.copy
      text: root.dockerState === "stopped" ? "Start Docker" : "Copy fix command"
      tooltipText: root.dockerState === "stopped" ? "systemctl start docker (asks for your password)" : "sudo usermod -aG docker $USER"
      bordered: true
      selected: true
      enabled: root.ready && !root.service.isBusy("daemon")
      opacity: enabled ? 1 : 0.4
      foreground: root.foreground
      accent: root.accent
      onClicked: root.dockerState === "stopped" ? root.service.startDocker() : root.service.copyGroupFix()
    }
  }

  Text {
    visible: root.ready && root.dockerState === "running" && root.containers.length === 0
    textFormat: Text.PlainText
    text: "No containers."
    color: root.muted
    font.family: root.fontFamily
    font.pixelSize: Style.font.bodySmall
  }

  Column {
    width: parent.width
    spacing: Style.space(6)
    visible: root.dockerState === "running" && root.containers.length > 0

    Repeater {
      model: root.dockerState === "running" ? root.containers : []

      Item {
        id: containerRow
        required property var modelData
        readonly property bool running: modelData.state === "running"
        readonly property bool busy: root.service.isBusy(modelData.id) || root.service.isBusy("all")
        readonly property var ports: D.hostPorts(modelData.ports)

        width: parent.width
        height: Math.max(containerText.implicitHeight, containerButtons.height)
        opacity: busy ? 0.5 : 1

        Rectangle {
          id: stateDot
          anchors.left: parent.left
          anchors.top: parent.top
          anchors.topMargin: Style.space(6)
          width: Style.space(8)
          height: width
          radius: width / 2
          color: containerRow.running ? root.accent : Util.alpha(root.foreground, 0.25)
        }

        Column {
          id: containerText
          anchors.left: stateDot.right
          anchors.leftMargin: Style.space(8)
          anchors.right: containerButtons.left
          anchors.rightMargin: Style.space(6)
          spacing: Style.space(3)

          Text {
            width: parent.width
            elide: Text.ElideRight
            textFormat: Text.PlainText
            text: containerRow.modelData.name
            color: containerRow.running ? root.foreground : root.muted
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            font.bold: containerRow.running
          }

          Text {
            width: parent.width
            elide: Text.ElideRight
            textFormat: Text.PlainText
            text: (containerRow.modelData.project ? containerRow.modelData.project + " · " : "")
              + containerRow.modelData.image + " · " + containerRow.modelData.status
            color: root.muted
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }

          Flow {
            width: parent.width
            spacing: Style.space(4)
            visible: containerRow.running && containerRow.ports.length > 0

            Repeater {
              model: containerRow.running ? containerRow.ports : []

              PortChip {
                required property var modelData
                port: modelData
                foreground: root.foreground
                accent: root.accent
                fontFamily: root.fontFamily
                onClicked: root.service.openPort(modelData)
              }
            }
          }
        }

        Row {
          id: containerButtons
          anchors.right: parent.right
          anchors.top: parent.top
          spacing: Style.space(2)

          PanelActionButton {
            iconText: D.icons.logs
            tooltipText: "Follow logs"
            fontFamily: root.iconFamily
            foreground: root.foreground
            onClicked: root.service.containerLogs(containerRow.modelData)
          }

          PanelActionButton {
            visible: containerRow.running
            iconText: D.icons.console
            tooltipText: "Open a shell inside"
            fontFamily: root.iconFamily
            foreground: root.foreground
            onClicked: root.service.containerShell(containerRow.modelData)
          }

          PanelActionButton {
            visible: containerRow.running
            iconText: D.icons.restart
            tooltipText: "Restart"
            fontFamily: root.iconFamily
            foreground: root.foreground
            enabled: !containerRow.busy
            onClicked: root.service.containerAction(containerRow.modelData, "restart")
          }

          PanelActionButton {
            iconText: containerRow.running ? D.icons.stop : D.icons.play
            tooltipText: containerRow.running ? "Stop" : "Start"
            fontFamily: root.iconFamily
            foreground: root.foreground
            hoverColor: containerRow.running ? root.urgent : root.foreground
            enabled: !containerRow.busy
            onClicked: root.service.containerAction(containerRow.modelData, containerRow.running ? "stop" : "start")
          }
        }
      }
    }
  }

  PanelSeparator { width: parent.width; foreground: root.foreground }

  // ------------------------------------------------------- dev servers

  PanelSectionHeader {
    text: "DEV SERVERS"
    foreground: root.foreground
    fontFamily: root.fontFamily
  }

  Text {
    visible: root.ready && root.servers.length === 0
    textFormat: Text.PlainText
    text: "Nothing of yours is listening on a TCP port."
    color: root.muted
    font.family: root.fontFamily
    font.pixelSize: Style.font.bodySmall
  }

  Column {
    width: parent.width
    spacing: Style.space(8)
    visible: root.servers.length > 0

    Repeater {
      model: root.servers

      Item {
        id: serverRow
        required property var modelData
        readonly property bool termed: root.service.wasTerminated(modelData)

        width: parent.width
        height: Math.max(serverText.implicitHeight, serverButtons.height)

        Text {
          id: serverIcon
          anchors.left: parent.left
          anchors.top: parent.top
          text: D.icons.server
          color: root.accent
          font.family: root.iconFamily
          font.pixelSize: Style.font.body
        }

        Column {
          id: serverText
          anchors.left: serverIcon.right
          anchors.leftMargin: Style.space(8)
          anchors.right: serverButtons.left
          anchors.rightMargin: Style.space(6)
          spacing: Style.space(3)

          Text {
            width: parent.width
            elide: Text.ElideRight
            textFormat: Text.PlainText
            text: serverRow.modelData.title
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            font.bold: true
          }

          Text {
            width: parent.width
            elide: Text.ElideMiddle
            textFormat: Text.PlainText
            text: serverRow.modelData.process + " · pid " + serverRow.modelData.pid
              + (serverRow.modelData.cwd ? " · " + D.homeRelative(serverRow.modelData.cwd, root.home) : "")
              + (serverRow.modelData.public ? " · all interfaces" : "")
            color: root.muted
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }

          Flow {
            width: parent.width
            spacing: Style.space(4)

            Repeater {
              model: serverRow.modelData.ports

              PortChip {
                required property var modelData
                port: modelData
                foreground: root.foreground
                accent: root.accent
                fontFamily: root.fontFamily
                onClicked: root.service.openPort(modelData)
              }
            }
          }
        }

        Row {
          id: serverButtons
          anchors.right: parent.right
          anchors.top: parent.top
          spacing: Style.space(2)

          PanelActionButton {
            visible: serverRow.modelData.cwd !== ""
            iconText: D.icons.folder
            tooltipText: "Open a terminal in " + D.homeRelative(serverRow.modelData.cwd, root.home)
            fontFamily: root.iconFamily
            foreground: root.foreground
            onClicked: root.service.openFolder(serverRow.modelData.cwd)
          }

          PanelActionButton {
            iconText: D.icons.close
            tooltipText: serverRow.termed ? "Still running: click to force kill" : "Stop (SIGTERM)"
            fontFamily: root.iconFamily
            foreground: serverRow.termed ? root.urgent : root.foreground
            hoverColor: root.urgent
            onClicked: root.service.stopServer(serverRow.modelData)
          }
        }
      }
    }
  }
}
