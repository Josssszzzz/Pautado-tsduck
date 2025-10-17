#!/bin/bash

# --- CONFIGURACIÓN ---
# Directorio raíz que contiene todas las grabaciones.
DIRECTORIO_GRABACIONES="/home/pi/pautado-tsduck/grabaciones"

# --- LÓGICA DEL SCRIPT ---
echo "Iniciando el proceso de búsqueda y renombrado de videos."
echo "IMPORTANTE: Solo se procesarán archivos que no tengan el sufijo _GX.mp4 (ej: _G1.mp4)."
echo "Directorio de análisis: ${DIRECTORIO_GRABACIONES}"
echo "----------------------------------------------------------------"

# Busca todos los archivos .mp4 en el directorio y subdirectorios.
find "${DIRECTORIO_GRABACIONES}" -type f -name "*.mp4" | while read -r archivo_original
do
    # Verificación de existencia del archivo (es una buena práctica mantenerla)
    if [ ! -f "${archivo_original}" ]; then
        echo "[OMITIENDO] Ruta inválida o archivo no encontrado: ${archivo_original}"
        continue
    fi

    # Extraemos solo el nombre del archivo para la verificación.
    nombre_archivo=$(basename "${archivo_original}")

    # --- LÓGICA DE RENOMBRADO ---
    # Verificamos si el nombre del archivo ya contiene el patrón "_G" seguido de un número.
    # Ejemplos que se omitirán: "11-45-19_G3.mp4", "12-17-00_G1.mp4"
    # Ejemplos que se procesarán: "00-16-29.mp4", "08-24-41.mp4"
    if [[ "${nombre_archivo}" =~ _G[0-9]+ ]]; then
        echo "[OMITIENDO] ==> ${archivo_original} (ya tiene el formato correcto)."
    else
        echo "[RENOMBRANDO] ==> ${archivo_original}"

        # Construimos la nueva ruta del archivo añadiendo "_G1" antes de la extensión .mp4
        # Ejemplo: /ruta/00-16-29.mp4  ->  /ruta/00-16-29_G1.mp4
        nuevo_archivo="${archivo_original%.mp4}_G1.mp4"

        # Ejecutamos el comando para renombrar
        mv "${archivo_original}" "${nuevo_archivo}"

        # Comprobamos si el renombrado fue exitoso
        if [ $? -eq 0 ]; then
            echo "[ÉXITO] Archivo renombrado a: ${nuevo_archivo}"
        else
            echo "[ERROR] Falló el renombrado para ${archivo_original}."
        fi
    fi
    echo "----------------------------------------------------------------"
done

echo "¡PROCESO COMPLETADO! Todos los videos han sido verificados."