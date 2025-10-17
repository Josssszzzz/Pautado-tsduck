
# --- CONFIGURACIÓN ---
UDP_URL="udp://@224.120.0.16:1234"
DURACION=75

# 1. Detecta el nombre del canal.
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
NOMBRE_CANAL=$(basename "${SCRIPT_DIR}")

# 2. Construye la ruta de salida con la estructura de carpetas por fecha.
BASE_GRABACIONES="/home/pi/pautado-tsduck/grabaciones"
FECHA_CARPETA=$(date +%Y-%m-%d)
HORA_ARCHIVO=$(date +%H-%M-%S)

# Ruta al script PHP que devuelve el JSON.
API_SCRIPT_PATH="/var/www/html/Monitoreo_pautado/api/get_spot.php"

echo "[GRABANDO] Consultando API para obtener el ID del spot..."
# Ejecuta el script PHP y captura su salida (el JSON).
JSON_RESPONSE=$(php "${API_SCRIPT_PATH}" "${NOMBRE_CANAL}")

# El flag '-r' es para obtener el valor raw (sin comillas).
SPOT_VALOR=$(echo "${JSON_RESPONSE}" | jq -r '.spot_actual')

# Si el valor obtenido es válido (no es nulo ni vacío), se formatea.
if [ -n "${SPOT_VALOR}" ] && [ "${SPOT_VALOR}" != "null" ]; then
    SUFIJO_NOMBRE="_G${SPOT_VALOR}"
    echo "[GRABANDO] Spot ID obtenido: ${SPOT_VALOR}"
else
    SUFIJO_NOMBRE="_GX"
    echo "[GRABANDO] ADVERTENCIA: No se pudo obtener un ID de spot válido de la API."
fi

CARPETA_SALIDA_FECHA="${BASE_GRABACIONES}/${NOMBRE_CANAL}/${FECHA_CARPETA}/"
NOMBRE_ARCHIVO="${HORA_ARCHIVO}${SUFIJO_NOMBRE}.mp4"
RUTA_COMPLETA="${CARPETA_SALIDA_FECHA}${NOMBRE_ARCHIVO}"

#    Usa la variable correcta que incluye la fecha.
echo "[GRABANDO] Verificando directorio de salida: ${CARPETA_SALIDA_FECHA}"
mkdir -p "${CARPETA_SALIDA_FECHA}"

# 4. Ejecutar el comando FFmpeg para grabar.
echo "[GRABANDO] Iniciando captura de ${DURACION}s para el canal '${NOMBRE_CANAL}'..."
echo "[GRABANDO] Archivo de salida: ${RUTA_COMPLETA}"

# Comando ffmepg para la grabación.
timeout 80s ffmpeg -i "${UDP_URL}" -t "${DURACION}" -c:v libx264 -crf 30 -preset slow -c:a aac -b:a 128k "${RUTA_COMPLETA}"

echo "[GRABANDO] Captura para '${NOMBRE_CANAL}' finalizada."