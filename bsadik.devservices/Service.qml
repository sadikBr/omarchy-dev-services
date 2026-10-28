import Quickshell
import Quickshell.Io
import QtQuick
import "Dev.js" as D

// Dev services engine. One instance per shell: it polls Docker and the
// user's listening TCP sockets through collect.sh and runs container and
// process actions. Bar widgets (one per monitor) only read from it and call
// into it.
//
// Polling is slow in the background and fast while a popup is open, so the
// bar count stays roughly current without running docker every few seconds
// all day.
Item {
  id: root

  property var shell: null
  property var manifest: null
  property string omarchyPath: Quickshell.env("OMARCHY_PATH") || "/usr/share/omarchy"
  readonly property string home: Quickshell.env("HOME") || ""
  readonly property string collector: String(Qt.resolvedUrl("collect.sh")).replace(/^file:\/\//, "")

  // ---------------------------------------------------------------- state

  property var info: D.empty()
  property bool loaded: false
  property bool refreshing: false
  property int watchers: 0             // open popups; >0 switches to fast polling
  property var busy: ({})              // container id / pid -> true while an action runs
  property var terminated: ({})        // pid -> true once SIGTERM was sent

  readonly property string dockerState: info.docker.state
  readonly property var containers: D.sortContainers(info.docker.containers)
  readonly property var runningContainers: containers.filter(function(c) { return c.state === "running" })
  readonly property var servers: D.groupServers(info.ports)
  readonly property int activeCount: runningContainers.length + servers.length

  function summary() {
    var parts = []
    if (dockerState === "running") parts.push(D.plural(runningContainers.length, "container") + " running")
    else if (dockerState === "stopped") parts.push("Docker stopped")
    else if (dockerState === "denied") parts.push("Docker: no access")
    parts.push(D.plural(servers.length, "dev server"))
    return parts.join(" · ")
  }

  // --------------------------------------------------------------- polling

  function refresh() {
    if (collectProcess.running) return
    root.refreshing = true
    collectProcess.running = true
  }

  function watch(on) {
    root.watchers = Math.max(0, root.watchers + (on ? 1 : -1))
    if (on) refresh()
  }

  Process {
    id: collectProcess
    command: ["bash", root.collector]
    stdout: StdioCollector {
      id: collectOut
      waitForEnd: true
    }
    onExited: function(exitCode) {
      root.refreshing = false
      var parsed = exitCode === 0 ? D.parse(collectOut.text) : null
      if (parsed) {
        root.info = parsed
        root.forgetGonePids()
      }
      root.loaded = true
    }
  }

  Timer {
    interval: root.watchers > 0 ? 3000 : 20000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  // --------------------------------------------------------------- actions

  // Runs a command, marks `key` busy until it exits, then refreshes.
  function run(key, args) {
    var b = Object.assign({}, root.busy)
    b[key] = true
    root.busy = b
    actionComponent.createObject(root, { key: key, command: args })
  }

  function isBusy(key) { return root.busy[key] === true }

  Component {
    id: actionComponent

    Process {
      property string key: ""
      running: true
      onExited: {
        var b = Object.assign({}, root.busy)
        delete b[key]
        root.busy = b
        root.refresh()
        destroy()
      }
    }
  }

  function containerAction(c, action) {
    if (!c || ["start", "stop", "restart"].indexOf(action) < 0) return
    run(c.id, ["docker", action, c.id])
  }

  function stopAllContainers() {
    var ids = root.runningContainers.map(function(c) { return c.id })
    if (ids.length === 0) return
    run("all", ["docker", "stop"].concat(ids))
  }

  function containerLogs(c) {
    launchTui(["docker", "logs", "--follow", "--tail", "200", c.name])
  }

  function containerShell(c) {
    // bash when the image has it, sh otherwise.
    launchTui(["docker", "exec", "-it", c.name, "sh", "-c", "command -v bash >/dev/null && exec bash || exec sh"])
  }

  // SIGTERM first; pressing again while it is still listening sends SIGKILL.
  function stopServer(s) {
    var termed = root.terminated[s.pid] === true
    var t = Object.assign({}, root.terminated)
    t[s.pid] = true
    root.terminated = t
    run("pid:" + s.pid, ["kill", termed ? "-KILL" : "-TERM", String(s.pid)])
  }

  function wasTerminated(s) { return root.terminated[s.pid] === true }

  function forgetGonePids() {
    var live = {}
    root.info.ports.forEach(function(p) { live[p.pid] = true })
    var t = {}
    for (var pid in root.terminated) if (live[pid]) t[pid] = true
    root.terminated = t
  }

  function openPort(port) {
    Quickshell.execDetached([root.omarchyPath + "/bin/omarchy-launch-browser", "http://localhost:" + port])
  }

  function openFolder(path) {
    if (path) Quickshell.execDetached(["setsid", "uwsm-app", "--", "xdg-terminal-exec", "--dir=" + path])
  }

  function launchTui(args) {
    Quickshell.execDetached([root.omarchyPath + "/bin/omarchy-launch-tui"].concat(args))
  }

  // The popup runs outside any terminal, so privilege goes through polkit.
  function startDocker() { run("daemon", ["pkexec", "systemctl", "start", "docker"]) }
  function stopDocker() { run("daemon", ["pkexec", "systemctl", "stop", "docker.socket", "docker"]) }

  function copyGroupFix() {
    Quickshell.execDetached(["wl-copy", "sudo usermod -aG docker $USER"])
    notify("Command copied", "Run it in a terminal, then log out and back in.")
  }

  function notify(title, body) {
    Quickshell.execDetached([root.omarchyPath + "/bin/omarchy-notification-send", "--app-name", "Dev services", "-g", D.icons.docker, title, body || ""])
  }

  function status() {
    return JSON.stringify({
      docker: root.dockerState,
      containers: root.containers.map(function(c) { return { name: c.name, image: c.image, state: c.state, ports: D.hostPorts(c.ports) } }),
      servers: root.servers.map(function(s) { return { pid: s.pid, title: s.title, process: s.process, cwd: s.cwd, ports: s.ports } })
    })
  }

  IpcHandler {
    target: "bsadik.devservices"

    function status(): string { return root.status() }
    function refresh(): void { root.refresh() }
    function stopAll(): void { root.stopAllContainers() }
    function panel(): void { if (root.shell) root.shell.toggle("bsadik.devservices", "") }
  }
}
