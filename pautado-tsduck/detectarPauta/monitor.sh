#!/usr/bin/env bash
set -euo pipefail

LOCAL_IF="10.100.1.6"
ONLY_OUT=false

API_OBTENER_SPOT="/var/www/html/Monitoreo_pautado/api/get_spot.php"

# --- CAMBIO 1: Añadir la ruta al script de grabación para cada canal ---
# Formato: "IP:PUERTO NOMBRE /ruta/pauta.sh /ruta/grabar.sh"
CANALES=(
  "224.120.120.20:4000 TELEHIT_URBANO /home/pi/pautado-tsduck/canales/telehit_urbano/pauta.sh /home/pi/pautado-tsduck/canales/telehit_urbano/grabar.sh"
  "224.120.120.21:4000 BITME /home/pi/pautado-tsduck/canales/bitme/pauta.sh /home/pi/pautado-tsduck/canales/bitme/grabar.sh"
  "224.120.120.29:4000 BANDAMAX /home/pi/pautado-tsduck/canales/bandamax/pauta.sh /home/pi/pautado-tsduck/canales/bandamax/grabar.sh"
  "224.120.120.13:4000 ANIMAL_PLANET /home/pi/pautado-tsduck/canales/animal_planet/pauta.sh /home/pi/pautado-tsduck/canales/animal_planet/grabar.sh"
  "224.120.120.14:4000 DE_PELICULA /home/pi/pautado-tsduck/canales/de_pelicula/pauta.sh /home/pi/pautado-tsduck/canales/de_pelicula/grabar.sh"
  "224.120.120.36:4000 EL_FINANCIERO /home/pi/pautado-tsduck/canales/el_financiero/pauta.sh /home/pi/pautado-tsduck/canales/el_financiero/grabar.sh"
  "224.120.120.19:4000 GOLDEN /home/pi/pautado-tsduck/canales/golden/pauta.sh /home/pi/pautado-tsduck/canales/golden/grabar.sh"
  "224.120.120.18:4000 GOLDEN_EDGE /home/pi/pautado-tsduck/canales/golden_edge/pauta.sh /home/pi/pautado-tsduck/canales/golden_edge/grabar.sh"
  "224.120.120.48:4000 GOLDEN_MPX /home/pi/pautado-tsduck/canales/golden_mpx/pauta.sh /home/pi/pautado-tsduck/canales/golden_mpx/grabar.sh"
  "224.120.120.27:4000 LAS_ESTRELLAS-2 /home/pi/pautado-tsduck/canales/las_estrellas-2/pauta.sh /home/pi/pautado-tsduck/canales/las_estrellas-2/grabar.sh"
  "224.120.120.5:4000 STUDIO_UNIVERSAL /home/pi/pautado-tsduck/canales/studio_universal/pauta.sh /home/pi/pautado-tsduck/canales/studio_universal/grabar.sh"
  "224.120.120.25:4000 TELEHIT_MUSICA /home/pi/pautado-tsduck/canales/telehit_musica/pauta.sh /home/pi/pautado-tsduck/canales/telehit_musica/grabar.sh"
  "224.120.120.49:4000 TUDN /home/pi/pautado-tsduck/canales/tudn/pauta.sh /home/pi/pautado-tsduck/canales/tudn/grabar.sh"
  "224.120.120.9:4000 UNIVERSAL /home/pi/pautado-tsduck/canales/universal/pauta.sh /home/pi/pautado-tsduck/canales/universal/grabar.sh"
  "224.120.120.3:4000 DISTRITO_COMEDIA /home/pi/pautado-tsduck/canales/distrito_comedia/pauta.sh /home/pi/pautado-tsduck/canales/distrito_comedia/grabar.sh"
  "224.120.120.4:4000 ADRENALINA /home/pi/pautado-tsduck/canales/adrenalina/pauta.sh /home/pi/pautado-tsduck/canales/adrenalina/grabar.sh"
  "224.120.120.28:4000 TL_NOVELAS /home/pi/pautado-tsduck/canales/tl_novelas/pauta.sh /home/pi/pautado-tsduck/canales/tl_novelas/grabar.sh"
  "224.120.120.30:4000 UNICABLE /home/pi/pautado-tsduck/canales/unicable/pauta.sh /home/pi/pautado-tsduck/canales/unicable/grabar.sh"
)

LOG_DIR="./logs"
mkdir -p "$LOG_DIR"
EVENT_LOG="${LOG_DIR}/scte35_events_$(date +%F).txt"
PAUTA_LOG_REDIR="${LOG_DIR}/pauta_caller_$(date +%F).log"

# --- CAMBIO 2: Crear una nueva función para llamar al script de grabación ---
# Es una buena práctica para mantener el código limpio. 
call_grabar() {
  local chan="$1"
  local grabar_script="$2"

  log_info "[DBG-CALL] call_grabar(chan='$chan', script='$grabar_script')"

  if [[ -z "$grabar_script" ]]; then
    log_info "[$chan] No tiene script de grabación configurado. Omitiendo."
    return
  fi

  if [[ -x "$grabar_script" ]]; then
    log_info "[$chan] Lanzando grabación en segundo plano: $grabar_script"
    
    "$grabar_script" >>"$PAUTA_LOG_REDIR" 2>&1 &
  else
    log_info "[$chan] ERROR: no es ejecutable $grabar_script"
  fi
}

check_spot_actual() {
    local channel_name="$1"
    local default_spot="1" # Define el valor por defecto en caso de fallo

    # 1. Validar que se proporcionó un nombre de canal
    if [[ -z "$channel_name" ]]; then
        # Imprime el error en stderr (>&2)
        echo "Error en 'check_spot_actual': No se proporcionó un nombre de canal." >&2
        # Devuelve el valor por defecto en stdout
        echo "$default_spot"
        return
    fi

    # 2. Ejecutar el script PHP y capturar la respuesta JSON
    # El comando 'php' es mucho más rápido que 'curl' en el mismo servidor
    local response
    response=$(php "$API_OBTENER_SPOT" "$channel_name")

    # 3. Verificar si el script PHP se ejecutó correctamente
    if [[ $? -ne 0 ]] || [[ -z "$response" ]]; then
        echo "Error en 'check_spot_actual': El script PHP falló o no devolvió nada para '$channel_name'." >&2
        echo "$default_spot"
        return
    fi

    # 4. Usar 'jq' para parsear el JSON de forma segura
    # 'jq .' valida que el JSON sea correcto. '>/dev/null 2>&1' oculta la salida de esta validación.
    if ! echo "$response" | jq '.' >/dev/null 2>&1; then
        echo "Error en 'check_spot_actual': La API devolvió un JSON inválido para '$channel_name'." >&2
        echo "$default_spot"
        return
    fi

    # 5. Extraer el estado 'success' del JSON
    local success
    success=$(echo "$response" | jq -r '.success')

    if [[ "$success" == "true" ]]; then
        # Si fue exitoso, extrae y devuelve el número del spot
        local spot_id
        spot_id=$(echo "$response" | jq -r '.spot_actual')
        echo "$spot_id"
    else
        # Si la API reportó un error, lo registramos y devolvemos el valor por defecto
        local error_msg
        error_msg=$(echo "$response" | jq -r '.error')
        echo "Error en API para '$channel_name': $error_msg. Usando spot por defecto." >&2
        echo "$default_spot"
    fi
}

call_pauta() {
  local chan="$1"
  local pauta_script="$2"
  local SAFE_PATH="/usr/sbin:/usr/bin:/sbin:/bin:$PATH"

  log_info "[DBG-CALL] call_pauta(chan='$chan', script='$pauta_script')"

  if [[ -z "$pauta_script" ]]; then
    log_info "[$chan] No tiene script de pauta configurado. Omitiendo."
    return
  fi

  # 1. Obtener el número del spot actual desde la API
  log_info "[$chan] Consultando spot actual desde la API..."
  local spot_id
  spot_id=$(check_spot_actual "$chan")
  log_info "[$chan] API devolvió ID de spot: $spot_id"

  # 2. Construir el nombre del spot que espera tu script (ej: SPOT1, SPOT2)
  local spot_name="SPOT${spot_id}"
  log_info "[$chan] Construido nombre del spot: $spot_name"

  # 3. Ejecutar el script pauta.sh, pasándole el nombre del spot como argumento
  if [[ -x "$pauta_script" ]]; then
    log_info "[$chan] Lanzando pauta: $pauta_script con argumento '$spot_name'"
    # El spot_name se pasa como el primer argumento ($1) al script pauta.sh
    ( PATH="$SAFE_PATH"; "$pauta_script" "$spot_name" ) >>"$PAUTA_LOG_REDIR" 2>&1 &
  else
    log_info "[$chan] ERROR: El script de pauta no es ejecutable: $pauta_script"
  fi
}

log_info() { echo "[$(date +'%F %T')] $*"; }
log_warn() { echo "[$(date +'%F %T')] [WARN] $*"; }

declare -A MAP_PROGID=()
declare -A MAP_OON=()
declare -A OUT_TIME=()
declare -A OUT_PID=()
declare -A PRINTED=()

to_epoch() {
  local ts="$1"
  date -d "$ts" +%s 2>/dev/null || echo 0
}

print_line() {
  local fecha="$1" pid="$2" oon="$3" eid="$4" name="$5" prog="${6:-N/A}"
  printf -v pid_hex '0x%04X' "$pid"
  printf '[%s] PID: %d (%s) | ProgramID: %s | Command: Splice Insert | OutOfNetwork: %s | SpliceEventID: %s | Canal: %s\n' \
    "$fecha" "$pid" "$pid_hex" "$prog" "$oon" "$eid" "$name" >> "$EVENT_LOG"
}

print_duration() {
  local out_ts="$1" in_ts="$2"
  local out_s in_s dur
  out_s=$(to_epoch "$out_ts"); in_s=$(to_epoch "$in_ts")
  dur=$(( in_s - out_s )); (( dur < 0 )) && dur=0
  printf 'Duración (event-time OUT→IN): %02d:%02d\n\n' $((dur/60)) $((dur%60)) >> "$EVENT_LOG"
}

process_line_with_jq() {
  local raw="$1"

  if jq -e '."#name"=="splice_information_table"' >/dev/null 2>&1 <<<"$raw"; then
    local eid prog oon
    eid=$(jq -r '.. | .splice_event_id? // empty' <<<"$raw" | head -n1)
    prog=$(jq -r '.. | .unique_program_id? // empty' <<<"$raw" | head -n1)
    oon=$(jq -r '.. | .out_of_network?     // empty' <<<"$raw" | head -n1)
    [[ -n "$eid" && -n "$prog" ]] && MAP_PROGID["$CURRENT_CHAN:$eid"]="$prog"
    [[ -n "$eid" && -n "$oon"  ]] && MAP_OON["$CURRENT_CHAN:$eid"]="$oon"
    return
  fi

  jq -e '."#name"=="event" and .progress=="occurred"' >/dev/null 2>&1 <<<"$raw" || return

  local fecha eid etype splice_pid name key oon prog
  fecha=$(jq -r '.["event-time"] // .time // ""' <<<"$raw")
  eid=$(jq   -r '."event-id" // empty' <<<"$raw")
  etype=$(jq -r '."event-type" // empty' <<<"$raw")
  splice_pid=$(jq -r '."splice-pid" // 0' <<<"$raw")
  name=$(jq -r '.tag // "UNKNOWN"' <<<"$raw")
  key="$name:$eid"

  log_info "[DBG] detectado event-type=$etype, tag=$name, eid=$eid, fecha=$fecha"
  local dedup_key="$key|$etype|$fecha"
  [[ -n "${PRINTED[$dedup_key]:-}" ]] && return
  PRINTED[$dedup_key]=1
  $ONLY_OUT && [[ "$etype" != "out" ]] && return
  oon="${MAP_OON[$key]:-}"
  [[ -z "$oon" ]] && { [[ "$etype" == "out" ]] && oon="True" || oon="False"; }
  prog="${MAP_PROGID[$key]:-N/A}"

  if [[ "$etype" == "out" ]]; then
    OUT_TIME["$key"]="$fecha"
    OUT_PID["$key"]="$splice_pid"
    log_info "[DBG] OUT para $name (eid=$eid) -> llamando scripts de acción"
    
    # --- CAMBIO 3: Llamar a AMBOS scripts, pauta y grabación ---
    # Primero grabamos, esperamos 3 segundos y luego pautamos. 
    call_grabar "$name" "$GRABAR_SCRIPT_FOR_CHAN"
    sleep 5
    call_pauta "$name" "$PAUTA_SCRIPT_FOR_CHAN"
    

    if $ONLY_OUT; then
      print_line "$fecha" "$splice_pid" "$oon" "$eid" "$name" "$prog"
    fi
  else # etype == in
    if [[ -n "${OUT_TIME[$key]:-}" ]]; then
      local out_ts="${OUT_TIME[$key]}"
      local out_pid="${OUT_PID[$key]:-0}"
      print_line "$out_ts" "$out_pid" "True"  "$eid" "$name" "$prog"
      print_line "$fecha"  "$splice_pid" "False" "$eid" "$name" "$prog"
      print_duration "$out_ts" "$fecha"
      unset OUT_TIME["$key"] OUT_PID["$key"]
    else
      if ! $ONLY_OUT; then
        print_line "$fecha" "$splice_pid" "$oon" "$eid" "$name" "$prog"
        printf 'Duración: N/A (no se observó OUT previo en esta sesión)\n\n' >> "$EVENT_LOG"
      fi
    fi
  fi
}

process_line_no_jq() {
  local raw="$1"
  [[ "$raw" =~ \"#name\"[[:space:]]*:[[:space:]]*\"event\" ]] || return
  [[ "$raw" =~ \"progress\"[[:space:]]*:[[:space:]]*\"occurred\" ]] || return

  local fecha eid etype spid name key oon
  fecha=""
  if [[ "$raw" =~ \"event-time\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]]; then fecha="${BASH_REMATCH[1]}";
  elif [[ "$raw" =~ \"time\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]]; then fecha="${BASH_REMATCH[1]}";
  else fecha="$(date +'%F %T')"; fi
  eid="";   [[ "$raw" =~ \"event-id\"[[:space:]]*:[[:space:]]*([0-9]+) ]] && eid="${BASH_REMATCH[1]}"
  etype=""; if [[ "$raw" =~ \"event-type\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]]; then etype="${BASH_REMATCH[1]}"; fi
  spid="0"; if [[ "$raw" =~ \"splice-pid\"[[:space:]]*:[[:space:]]*([0-9]+) ]]; then spid="${BASH_REMATCH[1]}"; fi
  name="${CURRENT_CHAN:-UNKNOWN}"
  key="$name:$eid"

  log_info "[DBG-NO-JQ] tag=$name eid=$eid etype=$etype fecha=$fecha"
  local dedup_key="$key|$etype|$fecha"
  [[ -n "${PRINTED[$dedup_key]:-}" ]] && return
  PRINTED[$dedup_key]=1
  $ONLY_OUT && [[ "$etype" != "out" ]] && return
  [[ "$etype" == "out" ]] && oon="True" || oon="False"

  if [[ "$etype" == "out" ]]; then
    log_info "[DBG-NO-JQ] OUT para $name (eid=$eid) -> llamando scripts de acción"
    # --- CAMBIO 3 (bis): Llamar a ambos scripts también en el modo sin JQ ---
    # Primero grabamos, esperamos 3 segundos y luego pautamos.
    call_grabar "$name" "$GRABAR_SCRIPT_FOR_CHAN" # <--- NUEVA LÍNEA
    sleep 5
    call_pauta "$name" "$PAUTA_SCRIPT_FOR_CHAN"
  fi

  print_line "$fecha" "$spid" "$oon" "$eid" "$name" "N/A"
  if [[ "$etype" == "in" && "$ONLY_OUT" == "false" ]]; then
    printf 'Duración: N/A (modo sin jq)\n\n' >> "$EVENT_LOG"
  fi
}

# --- CAMBIO 4: Adaptar start_monitor para que acepte un cuarto argumento ---
start_monitor() {
  local ipport="$1"
  local name="$2"
  local pauta_script_path="${3:-}"
  local grabar_script_path="${4:-}" # <--- NUEVO ARGUMENTO
  local chan_log="${LOG_DIR}/${name}_$(date +%F).jsonl"
  : > "$chan_log"

  export CURRENT_CHAN="$name"
  export PAUTA_SCRIPT_FOR_CHAN="$pauta_script_path"
  export GRABAR_SCRIPT_FOR_CHAN="$grabar_script_path" # <--- NUEVA VARIABLE DE ENTORNO

  tsp \
    -I ip "$ipport" --local-address "$LOCAL_IF" \
    -P splicemonitor --json-line --time-stamp --tag "$name" \
    -O drop >> "$chan_log" 2>&1 &
  local tsp_pid=$!
  log_info "[$name] escuchando $ipport (PID $tsp_pid) -> $chan_log"
  [[ -n "$pauta_script_path" ]] && log_info "[$name] Script de pauta: $pauta_script_path"
  [[ -n "$grabar_script_path" ]] && log_info "[$name] Script de grabación: $grabar_script_path" # <--- Log para confirmar

  (
    export CURRENT_CHAN="$name"
    export PAUTA_SCRIPT_FOR_CHAN="$pauta_script_path"
    export GRABAR_SCRIPT_FOR_CHAN="$grabar_script_path"
    set +e; set +o pipefail 2>/dev/null || true

    stdbuf -oL -eL tail -n0 -F "$chan_log" \
      | stdbuf -oL -eL grep --line-buffered . \
      | stdbuf -oL -eL tr -d '\r' \
      | while IFS= read -r line; do
          if [[ "$line" =~ (\{.*\}) ]]; then
            local json="${BASH_REMATCH[1]}"
            if command -v jq >/dev/null 2>&1; then
              process_line_with_jq "$json" \
                || log_warn "[$name-LOOP] process_line_with_jq falló (exit $?) y se continúa."
            else
              process_line_no_jq "$json" \
                || log_warn "[$name-LOOP] process_line_no_jq falló (exit $?) y se continúa."
            fi
          fi
        done \
      || true
  ) &
  parser_pids+=($!)
  tsp_pids+=($tsp_pid)
}

declare -a tsp_pids=()
declare -a parser_pids=()

# --- CAMBIO 5: Adaptar el bucle principal para leer los 4 campos ---
for entry in "${CANALES[@]}"; do
  # `read` ahora separará los 4 componentes de la línea
  read -r ipport name pauta_script_path grabar_script_path <<< "$entry"
  start_monitor "$ipport" "$name" "$pauta_script_path" "$grabar_script_path"
done

log_info "Escribiendo eventos en: $EVENT_LOG"
log_info "Presiona Ctrl+C para detener."

trap '
  log_info "Deteniendo monitores..."
  ((${#tsp_pids[@]}))   && kill "${tsp_pids[@]}" 2>/dev/null || true
  ((${#parser_pids[@]})) && kill "${parser_pids[@]}" 2>/dev/null || true
  wait
  log_info "Listo."
' INT TERM

wait
