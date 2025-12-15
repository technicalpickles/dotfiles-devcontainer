#!/usr/bin/env bash
set -euo pipefail

USERNAME="${USERNAME:-${_REMOTE_USER:-vscode}}"
START_DIR="/usr/local/share/dind"
START_SCRIPT="${START_DIR}/start-dind.sh"

sudo_if() {
	if [ "$(id -u)" -ne 0 ]; then
		sudo "$@"
	else
		"$@"
	fi
}

write_start_script() {
	sudo_if mkdir -p "$START_DIR"
	sudo_if tee "$START_SCRIPT" >/dev/null <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

USERNAME="${USERNAME:-${_REMOTE_USER:-vscode}}"
SOCKET="${DOCKER_HOST:-unix:///var/run/docker.sock}"
DATA_ROOT="${DOCKER_DATA_ROOT:-/var/lib/docker}"
LOGFILE="${DOCKERD_LOG_FILE:-/var/log/dockerd.log}"
DOCKERD_LOG_LEVEL="${DOCKERD_LOG_LEVEL:-info}"

sudo_if() {
  if [ "$(id -u)" -ne 0 ]; then
    sudo "$@"
  else
    "$@"
  fi
}

socket_path="${SOCKET#unix://}"
if [[ "$SOCKET" != unix://* ]]; then
  socket_path="/var/run/docker.sock"
fi
DOCKER_HOST_EFFECTIVE="unix://${socket_path}"
export DOCKER_HOST="${DOCKER_HOST_EFFECTIVE}"

ensure_directories() {
  sudo_if mkdir -p "$(dirname "$socket_path")" "$DATA_ROOT" "$(dirname "$LOGFILE")"
  sudo_if chown -R root:root "$DATA_ROOT" "$(dirname "$socket_path")"
  sudo_if touch "$LOGFILE"
  sudo_if chown root:root "$LOGFILE"
}

start_dockerd() {
  if command -v dockerd >/dev/null 2>&1; then
    local cmd="dockerd --host=\"${DOCKER_HOST_EFFECTIVE}\" --data-root=\"${DATA_ROOT}\" --exec-root=/var/run/docker --group=vscode --log-level=\"${DOCKERD_LOG_LEVEL}\""
    if [ "$(id -u)" -ne 0 ]; then
      sudo sh -c "${cmd} >\"${LOGFILE}\" 2>&1 &"
    else
      sh -c "${cmd} >\"${LOGFILE}\" 2>&1 &"
    fi
  else
    echo "Docker engine not found. Base image must include Docker components compatible with this feature." >&2
    exit 1
  fi
}

wait_for_docker() {
  local retries=30
  local i
  for i in $(seq 1 "$retries"); do
    if DOCKER_HOST="${DOCKER_HOST_EFFECTIVE}" docker info >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done
  echo "dockerd did not become ready after ${retries}s" >&2
  return 1
}

ensure_directories

echo "→ DinD wiring using ${DOCKER_HOST_EFFECTIVE} (data root ${DATA_ROOT}, log ${LOGFILE})"

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker CLI not found. Base image must include Docker CLI alongside dockerd for DinD feature." >&2
  exit 1
fi

if ! pgrep -x dockerd >/dev/null 2>&1; then
  start_dockerd
fi

wait_for_docker

if [ "$(id -u)" -eq 0 ] && [ "$USERNAME" != "root" ]; then
  exec sudo -E -H -u "$USERNAME" "$@"
fi

exec "$@"
EOF
	sudo_if chmod +x "$START_SCRIPT"
}

write_start_script
