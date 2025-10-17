#!/usr/bin/env bash
set -euo pipefail

# Directorio base (para rutas relativas)
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
CANAL=$(basename "${SCRIPT_DIR}")

# Config y logs (programacion = vlm.conf)
VLM_CONF="${SCRIPT_DIR}/vlm.conf"
LOG_FILE="${SCRIPT_DIR}/vlc.log"

# --- Verificación de seguridad ---
if [ ! -f "$VLM_CONF" ]; then
    echo "ERROR: No se encontró el archivo de configuración en: $VLM_CONF"
    exit 1
fi

# Puerto telnet para controlar VLC
TELNET_PORT="9027"

# Matar instancias viejas de VLC relacionadas a ESTE canal específico
pkill -f "vlc .*${VLM_CONF}" 2>/dev/null || true
pkill -f "cvlc .*${VLM_CONF}" 2>/dev/null || true
sleep 1

# Arrancar VLC headless con interfaz Telnet en puerto 9500
nohup cvlc \
  -I dummy \
  --extraintf telnet \
  --telnet-host 127.0.0.1 \
  --telnet-port "$TELNET_PORT" \
  --telnet-password pautado \
  --vlm-conf "$VLM_CONF" \
  --no-sout-all \
  --file-logging --logfile "$LOG_FILE" \
  >/dev/null 2>&1 &

echo "VLC ($CANAL) iniciado con Telnet en el puerto $TELNET_PORT. Log: $LOG_FILE"