#!/bin/bash

# --- CONFIGURACIÓN ---
# Directorio raíz que contiene todas las grabaciones.
DIRECTORIO_GRABACIONES="/home/pi/pautado-tsduck/grabaciones"

# Parámetros de compresión de FFmpeg (nuestro objetivo)
CRF="30"
PRESET="slow"
AUDIO_CODEC="aac"
AUDIO_BITRATE="128k"
VIDEO_CODEC="libx264"

# --- LÓGICA DEL SCRIPT ---
echo "Iniciando el proceso de búsqueda y compresión de videos."
echo "IMPORTANTE: Solo se procesarán archivos creados ANTES de la fecha de hoy."
echo "Directorio de análisis: ${DIRECTORIO_GRABACIONES}"
echo "----------------------------------------------------------------"

# Busca todos los archivos .mp4 modificados ANTES de hoy.
find "${DIRECTORIO_GRABACIONES}" -type f -name "*.mp4" -daystart -mtime +0 | while read -r archivo_original
do
    # Verificación de existencia del archivo
    if [ ! -f "${archivo_original}" ]; then
        echo "[OMITIENDO] Ruta inválida o incompleta: ${archivo_original}"
        continue
    fi

    echo "[PROCESANDO] ==> ${archivo_original}"

    # --- NUEVA VERIFICACIÓN DE CÓDEC ---
    # Usamos ffprobe para obtener el códec del primer stream de audio.
    # -v error: Oculta la información de ffprobe, solo muestra errores.
    # -select_streams a:0: Selecciona solo el primer stream de audio.
    # -show_entries stream=codec_name: Pide que muestre solo el nombre del códec.
    # -of default=...: Formatea la salida para que sea solo el valor (ej: "aac").
    current_audio_codec=$(ffprobe -v error -select_streams a:0 -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 "${archivo_original}")

    # Comparamos el códec actual con nuestro códec objetivo.
    if [ "${current_audio_codec}" == "${AUDIO_CODEC}" ]; then
        echo "[OMITIENDO] El archivo ya está comprimido (Audio: ${current_audio_codec})."
        echo "----------------------------------------------------------------"
        continue # Salta al siguiente archivo del bucle
    fi
    # --- FIN DE LA VERIFICACIÓN ---

    ruta_temporal="${archivo_original}.temp.mp4"

    # Comando FFmpeg para comprimir (solo se ejecuta si la verificación anterior falla)
    ffmpeg -y -nostdin -fflags +igndts -i "${archivo_original}" \
        -c:v ${VIDEO_CODEC} -crf ${CRF} -preset ${PRESET} \
        -c:a ${AUDIO_CODEC} -b:a ${AUDIO_BITRATE} \
        -threads 2 \
        "${ruta_temporal}" -loglevel error

    # Comprobación de seguridad
    if [ $? -eq 0 ] && [ -s "${ruta_temporal}" ]; then
        mv "${ruta_temporal}" "${archivo_original}"
        echo "[ÉXITO] El archivo fue recomprimido y reemplazado correctamente."
    else
        echo "[ERROR] Falló la compresión para ${archivo_original}. No se ha modificado el original."
        rm -f "${ruta_temporal}"
    fi
    echo "----------------------------------------------------------------"
done

echo "¡PROCESO COMPLETADO! Todos los videos antiguos han sido analizados."