#!/bin/bash

# Directorio base donde se encuentran todas las carpetas de los canales
BASE_DIR="/home/pi/pautado-tsduck/canales"

echo "--- Iniciando todos los scripts start_vlc.sh ---"

# Busca todos los scripts "start_vlc.sh" a un nivel de profundidad
find "$BASE_DIR" -maxdepth 2 -name "start_vlc.sh" -type f | while read script_path; do
    # Extrae el directorio del canal a partir de la ruta del script
    canal_dir=$(dirname "$script_path")

    # Extrae el nombre del canal para mostrar un mensaje
    canal_nombre=$(basename "$canal_dir")

    echo "Iniciando VLC para el canal: $canal_nombre"

    # Nos movemos al directorio
    (cd "$canal_dir" && ./start_vlc.sh &)
done

echo "--- Todos los scripts han sido lanzados en segundo plano ---"
