#!/usr/bin/env bash
# Prints one JSON object describing Docker and local dev servers:
#
#   { "docker": { "state": "running|stopped|denied|missing", "containers": [...] },
#     "ports":  [ { "pid", "process", "command", "cwd", "address", "port" } ] }
#
# Ports are TCP listeners owned by the current user (ss only resolves the
# owning process for our own sockets without root), so system daemons such as
# cups or resolved never show up.

set -uo pipefail

docker_json() {
  if ! command -v docker >/dev/null; then
    jq -n '{state: "missing", containers: []}'
    return
  fi

  local out
  if out=$(docker ps -a --no-trunc --format '{{json .}}' 2>&1); then
    jq -s '{state: "running", containers: map({
        id: .ID, name: .Names, image: .Image, state: .State,
        status: .Status, ports: .Ports, project: (.Labels | capture("com.docker.compose.project=(?<p>[^,]+)").p? // "")
      })}' <<<"$out"
  elif [[ $out == *"permission denied"* ]]; then
    jq -n '{state: "denied", containers: []}'
  else
    jq -n '{state: "stopped", containers: []}'
  fi
}

ports_json() {
  ss -ltnpH 2>/dev/null | while read -r _ _ _ local _ users; do
    [[ $users =~ pid=([0-9]+) ]] || continue
    local pid=${BASH_REMATCH[1]}
    local port=${local##*:}
    local address=${local%:*}
    local process cmd cwd
    process=$(cat "/proc/$pid/comm" 2>/dev/null) || continue
    cmd=$(tr '\0' ' ' <"/proc/$pid/cmdline" 2>/dev/null | head -c 300)
    cwd=$(readlink "/proc/$pid/cwd" 2>/dev/null)
    jq -nc --arg pid "$pid" --arg process "$process" --arg cmd "$cmd" --arg cwd "$cwd" \
      --arg address "$address" --arg port "$port" \
      '{pid: ($pid | tonumber), process: $process, command: ($cmd | rtrimstr(" ")),
        cwd: $cwd, address: $address, port: ($port | tonumber)}'
  done | jq -s 'unique_by([.pid, .port]) | sort_by(.port)'
}

jq -n --argjson docker "$(docker_json)" --argjson ports "$(ports_json)" \
  '{docker: $docker, ports: $ports}'
