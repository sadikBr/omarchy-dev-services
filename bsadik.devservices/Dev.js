.pragma library

// Pure helpers for the dev services plugin: icons, parsing the collector's
// JSON, and turning raw rows into what the popup shows.

function g(cp) { return String.fromCodePoint(cp) }

var icons = {
  docker: g(0xF0868),
  server: g(0xF048B),
  cube: g(0xF01A7),
  play: g(0xF040A),
  stop: g(0xF04DB),
  restart: g(0xF0709),
  refresh: g(0xF0450),
  console: g(0xF018D),
  logs: g(0xF09ED),
  open: g(0xF03CC),
  close: g(0xF0156),
  copy: g(0xF018F),
  folder: g(0xF0256),
  alert: g(0xF05D6),
  power: g(0xF0425),
  broom: g(0xF00E2)
}

function empty() {
  return { docker: { state: "unknown", containers: [] }, ports: [] }
}

function parse(text) {
  var raw = null
  try { raw = JSON.parse(text) } catch (e) { return null }
  if (!raw || typeof raw !== "object") return null
  var docker = raw.docker && typeof raw.docker === "object" ? raw.docker : {}
  return {
    docker: {
      state: String(docker.state || "unknown"),
      containers: Array.isArray(docker.containers) ? docker.containers : []
    },
    ports: Array.isArray(raw.ports) ? raw.ports : []
  }
}

// Host ports a container publishes, from docker's "0.0.0.0:8080->80/tcp,
// [::]:8080->80/tcp" string. Deduplicated, IPv4 and IPv6 bindings collapse.
function hostPorts(portsText) {
  var seen = {}
  var out = []
  var re = /:(\d+)->\d+\/tcp/g
  var m
  while ((m = re.exec(String(portsText || ""))) !== null) {
    var p = Number(m[1])
    if (!seen[p]) { seen[p] = true; out.push(p) }
  }
  return out.sort(function(a, b) { return a - b })
}

// Running containers first, then by compose project and name.
function sortContainers(list) {
  return list.slice().sort(function(a, b) {
    var ra = a.state === "running" ? 0 : 1
    var rb = b.state === "running" ? 0 : 1
    if (ra !== rb) return ra - rb
    var pa = String(a.project || ""), pb = String(b.project || "")
    if (pa !== pb) return pa < pb ? -1 : 1
    return String(a.name) < String(b.name) ? -1 : 1
  })
}

function basename(path) {
  var parts = String(path || "").split("/").filter(function(s) { return s !== "" })
  return parts.length > 0 ? parts[parts.length - 1] : ""
}

function homeRelative(path, home) {
  path = String(path || "")
  if (home && path.indexOf(home) === 0) return "~" + path.slice(home.length)
  return path
}

// One row per process: a dev server listening on 3000 and 24678 (vite's HMR
// socket) is one server, not two.
function groupServers(ports) {
  var byPid = {}
  var order = []
  for (var i = 0; i < ports.length; i++) {
    var p = ports[i]
    if (!byPid[p.pid]) {
      byPid[p.pid] = {
        pid: p.pid,
        process: String(p.process || ""),
        command: String(p.command || ""),
        cwd: String(p.cwd || ""),
        ports: [],
        public: false
      }
      order.push(p.pid)
    }
    var row = byPid[p.pid]
    if (row.ports.indexOf(p.port) < 0) row.ports.push(p.port)
    if (!isLoopback(p.address)) row.public = true
  }
  return order.map(function(pid) {
    var row = byPid[pid]
    row.ports.sort(function(a, b) { return a - b })
    row.title = basename(row.cwd) || row.process
    return row
  })
}

function isLoopback(address) {
  var a = String(address || "").replace(/^\[|\]$/g, "")
  return a.indexOf("127.") === 0 || a === "::1" || a === "localhost"
}

function plural(n, word) {
  return n + " " + word + (n === 1 ? "" : "s")
}
