#!/usr/bin/env bash
set -euo pipefail

# ===== Config =====
RC_HOST="127.0.0.1"
RC_PORT="9027"
RC_PASS="pautado"
SPOT_DEF="SPOT1"
DUR_DEF=60

# Directorio del script (para rutas relativas)
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
CANAL=$(basename "${SCRIPT_DIR}")

# Rutas de los logs y lock
LOG_DIR="${SCRIPT_DIR}"
LOG_FILE="${LOG_DIR}/pauta_actions.log"
LOCK_FILE="${LOG_DIR}/pauta.lock" # Mantenemos todo en el mismo directorio

# Parámetros: spot y duración (opcional)
SPOT="${1:-$SPOT_DEF}"
DUR="${2:-$DUR_DEF}"

# ===== Util =====
timestamp(){ date +'%F %T'; }
say(){ echo "[$(timestamp)] $*" | tee -a "$LOG_FILE"; }
need(){ command -v "$1" >/dev/null 2>&1 || { echo "Falta $1"; exit 1; }; }

# En caso de que no exista el directorio de logs, lo creamos
mkdir -p "$LOG_DIR"

need nc
ss -ltn | grep -q ":${RC_PORT}\b" || { echo "RC ${RC_PORT} no abierto"; exit 1; }

[ -e "$LOCK_FILE" ] && { echo "Pauta en curso (lock)"; exit 1; }
trap 'rm -f "$LOCK_FILE"' EXIT
echo $$ > "$LOCK_FILE"

# Detecta flags de nc según implementación (OpenBSD vs GNU/busybox)
if nc -h 2>&1 | grep -q ' -N'; then
  NC_OPTS="-N"        # OpenBSD nc: cierra tras EOF
else
  NC_OPTS="-q 0 -w 1" # GNU/BusyBox: espera 0s tras EOF y timeout 1s
fi

# Enviar UNA conexión por comando: primero password (posible vacío), luego comando (CRLF)
rc() {
  {
    printf "%s\r\n" "$RC_PASS"
    printf "%s\r\n" "$*"
  } | nc $NC_OPTS "$RC_HOST" "$RC_PORT" >/dev/null 2>&1 || true
}

# Enviar y registrar respuesta (debug)
rc_out() {
  local cmd="$*"
  local out
  out="$({
    printf "%s\r\n" "$RC_PASS"
    printf "%s\r\n" "$cmd"
  } | nc $NC_OPTS "$RC_HOST" "$RC_PORT" || true)"
  say "RC> $cmd"
  # compacta saltos de línea para el log
  out="${out//$'\r'/}"
  out="${out//$'\n'/ | }"
  say "RC< $out"
}

say ">> PAUTA start: SPOT=${SPOT}, DUR=${DUR}s"

# Estado previo (debug)
rc_out "show ${CANAL}"
rc_out "show ${SPOT}"

# 1) STOP canal, pequeña pausa
rc "control ${CANAL} stop"
sleep 0.4
rc_out "show ${CANAL}"

# 2) PLAY spot
rc "control ${SPOT} play"
sleep 0.3
rc_out "show ${SPOT}"
say "Canal ${CANAL} -> STOP | Spot ${SPOT} -> PLAY"

# 3) Espera duración
sleep "$DUR"

# 4) STOP spot, pequeña pausa, PLAY canal
rc "control ${SPOT} stop"
sleep 0.2
rc "control ${CANAL} play"
sleep 0.3 

# Estado final (debug)
rc_out "show ${CANAL}"
rc_out "show ${SPOT}"

say "<< PAUTA fin"
