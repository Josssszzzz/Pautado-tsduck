"""
Este script realiza las siguientes acciones:
1.  Recibe los datos del nuevo canal.
2.  Crea la estructura de directorios necesaria.
3.  Copia los spots de video desde una plantilla.
4.  Procesa los archivos de configuración (.sh, .conf) a partir de plantillas,
    reemplazando los placeholders con los datos del nuevo canal.
5.  Actualiza el script central 'monitor.sh' para incluir el nuevo canal.
"""

import os
import shutil
import sys
import argparse
import json

# --- 1. CONFIGURACIÓN DE RUTAS ---

# Obtiene la ruta absoluta del script actual (ej: /home/pi/pautado-tsduck/funciones/crear_canal.py)
script_path = os.path.realpath(__file__)
script_dir = os.path.dirname(script_path)
RUTA_BASE = os.path.dirname(script_dir)
RUTA_PLANTILLAS = os.path.join(RUTA_BASE, "plantillas")
RUTA_CANALES = os.path.join(RUTA_BASE, "canales")
RUTA_MONITOR_SH = os.path.join(RUTA_BASE, "detectarPauta", "monitor.sh")


# --- FUNCIONES AUXILIARES ---

def crear_directorios(ruta_canal_nuevo):
    """
    Crea la carpeta principal del canal y la subcarpeta 'spots'.
    """
    log_paso = []
    log_paso.append(f"Creando directorios en {ruta_canal_nuevo}...")
    
    if os.path.exists(ruta_canal_nuevo):
        raise FileExistsError(f"Error: El directorio {ruta_canal_nuevo} ya existe. Proceso abortado.")
    
    # Creamos la estructura de directorios primero.
    ruta_spots = os.path.join(ruta_canal_nuevo, "spots")
    os.makedirs(ruta_spots)
    log_paso.append("-> Directorios creados con éxito.")

    log_paso.append("-> Asignando permisos de grupo a los nuevos directorios...")
    
    os.chmod(ruta_canal_nuevo, 0o775)
    os.chmod(ruta_spots, 0o775)
    
    log_paso.append("-> Permisos asignados correctamente.")
    return log_paso

def copiar_spots(ruta_destino_spots):
    """Copia los videos de la plantilla a la nueva carpeta de spots."""
    log_paso = [] # <-- CORREGIDO: Inicializa la lista de logs
    log_paso.append("Copiando videos de spots...")
    ruta_origen_spots = os.path.join(RUTA_PLANTILLAS, "spots")
    
    if not os.path.isdir(ruta_origen_spots):
        log_paso.append("-> ADVERTENCIA: No se encontró el directorio de spots en plantillas. Omitiendo copia.")
        return log_paso

    for nombre_archivo in os.listdir(ruta_origen_spots):
        origen = os.path.join(ruta_origen_spots, nombre_archivo)
        destino = os.path.join(ruta_destino_spots, nombre_archivo)
        if os.path.isfile(origen):
            shutil.copy2(origen, destino)
            log_paso.append(f"-> Copiado: {nombre_archivo}")
    log_paso.append("-> Spots copiados con éxito.")
    return log_paso

def procesar_plantillas(ruta_canal_nuevo, placeholders):
    """
    Lee las plantillas, reemplaza valores y crea los nuevos archivos,
    asegurando permisos correctos para todos ellos.
    """
    log_paso = []
    log_paso.append("Procesando plantillas de configuración...")
    archivos_plantilla = ["grabar.sh", "pauta.sh", "start_vlc.sh", "vlm.conf"]
    
    for nombre_plantilla in archivos_plantilla:
        ruta_plantilla = os.path.join(RUTA_PLANTILLAS, nombre_plantilla)
        ruta_destino = os.path.join(ruta_canal_nuevo, nombre_plantilla)
        
        # --- Lectura y escritura (sin cambios) ---
        with open(ruta_plantilla, 'r') as f:
            contenido = f.read()
            
        for placeholder, valor in placeholders.items():
            contenido = contenido.replace(placeholder, str(valor))
            
        with open(ruta_destino, 'w') as f:
            f.write(contenido)
        # --- Asignación de permisos --- 
        os.chmod(ruta_destino, 0o664)

        if nombre_plantilla.endswith(".sh"):
            os.chmod(ruta_destino, 0o775)
            
        log_paso.append(f"-> Creado y configurado: {nombre_plantilla}")
        
    log_paso.append("-> Plantillas procesadas con éxito.")
    return log_paso

def actualizar_monitor(placeholders):
    """Agrega la nueva línea de configuración al script monitor.sh."""
    log_paso = [] # Inicializamos la lista de logs
    log_paso.append("Actualizando el script del monitor (monitor.sh)...")
    
    # Construir la nueva línea a partir de la "plantilla de línea"
    nueva_linea = (
        f'  "{placeholders["{{ UDP_ENTRADA_SIN_PROTOCOLO }}"]} {placeholders["{{ NOMBRE_CANAL_MAYUSCULAS }}"]} '
        f'{os.path.join(RUTA_CANALES, placeholders["{{ NOMBRE_CANAL_MINUSCULAS }}"], "pauta.sh")} '
        f'{os.path.join(RUTA_CANALES, placeholders["{{ NOMBRE_CANAL_MINUSCULAS }}"], "grabar.sh")}"\n'
    )
    
    if not os.path.exists(RUTA_MONITOR_SH):
        raise FileNotFoundError(f"Error: El archivo del monitor no se encuentra en {RUTA_MONITOR_SH}.")

    with open(RUTA_MONITOR_SH, 'r') as f:
        lineas = f.readlines()
        
    # Encontrar dónde insertar la nueva línea (justo antes del paréntesis de cierre)
    indice_insercion = -1
    for i, linea in enumerate(lineas):
        if linea.strip() == ")":
            indice_insercion = i
            break
            
    if indice_insercion == -1:
        raise ValueError("Error: No se pudo encontrar el final del array CANALES en monitor.sh.")
        
    lineas.insert(indice_insercion, nueva_linea)
    
    with open(RUTA_MONITOR_SH, 'w') as f:
        f.writelines(lineas)
        
    log_paso.append("-> monitor.sh actualizado con éxito.")
    return log_paso

def reiniciar_servicios():
    """Ejecuta el comando para reiniciar los servicios y devuelve el log."""
    log_paso = []
    log_paso.append("Reiniciando servicios del monitor y VLC...")
    
    # Este es el comando que configuraste en el archivo sudoers
    comando = "sudo systemctl restart monitor-pautado.service vlc-monitor.service vlc-canales.service"
    
    # Ejecutamos el comando. os.system() devuelve 0 si fue exitoso.
    exit_code = os.system(comando)

    if exit_code == 0:
        log_paso.append("-> Servicios reiniciados con éxito.")
    else:
        # Si el comando falla, lanzamos un error que será capturado por el bloque principal
        raise RuntimeError(f"Error al reiniciar los servicios. Código de salida: {exit_code}")

    return log_paso

# --- PUNTO DE ENTRADA PRINCIPAL ---
if __name__ == "__main__":
    
    # Definimos los argumentos que el script va a recibir
    parser = argparse.ArgumentParser(description="Script para crear un nuevo canal de pautado.")
    parser.add_argument("--nombre", required=True, help="Nombre del canal")
    parser.add_argument("--udp-in", required=True, help="URL UDP de entrada")
    parser.add_argument("--udp-out", required=True, help="URL UDP de salida")
    parser.add_argument("--port", required=True, help="Puerto de telnet/rc")
    args = parser.parse_args()

    # Diccionario para almacenar los resultados
    resultado_json = {
        "proceso": {
            "nombre_canal": args.nombre
        },
        "pasos": [],
        "conclusion": ""
    }
    
    # Creamos el diccionario de datos a partir de los argumentos recibidos
    datos_formulario = {
        "nombre_canal": args.nombre, "udp_entrada": args.udp_in,
        "udp_salida": args.udp_out, "telnet_port": args.port
    }
    
    try:
        # --- 3. TRANSFORMACIÓN DE DATOS ---
        nombre_original = datos_formulario["nombre_canal"]
        nombre_canal_minusculas = nombre_original.lower().replace(" ", "_")
        nombre_canal_mayusculas = nombre_original.upper().replace(" ", "_")
        udp_entrada_sin_protocolo = datos_formulario["udp_entrada"].replace("udp://@", "")
        udp_salida_sin_protocolo = datos_formulario["udp_salida"].replace("udp://@", "")

        # Diccionario con todos los placeholders y sus valores finales.
        reemplazos = {
            "{{ NOMBRE_CANAL_MINUSCULAS }}": nombre_canal_minusculas,
            "{{ NOMBRE_CANAL_MAYUSCULAS }}": nombre_canal_mayusculas,
            "{{ UDP_ENTRADA }}": datos_formulario["udp_entrada"],
            "{{ UDP_ENTRADA_SIN_PROTOCOLO }}": udp_entrada_sin_protocolo,
            "{{ UDP_SALIDA }}": datos_formulario["udp_salida"],
            "{{ UDP_SALIDA_SIN_PROTOCOLO }}": udp_salida_sin_protocolo,
            "{{ TELNET_PORT }}": datos_formulario["telnet_port"]
        }
        
        # --- 4. EJECUCIÓN DE LA LÓGICA PRINCIPAL ---
        ruta_nuevo_canal = os.path.join(RUTA_CANALES, nombre_canal_minusculas)

        # Ejecutar y capturar logs de cada paso
        log_paso_1 = crear_directorios(ruta_nuevo_canal)
        resultado_json["pasos"].append({"paso": "Creación de Directorios", "log": log_paso_1})

        ruta_spots_nuevo_canal = os.path.join(ruta_nuevo_canal, "spots")
        log_paso_2 = copiar_spots(ruta_spots_nuevo_canal) # Necesitas modificar esta función también
        resultado_json["pasos"].append({"paso": "Copia de Spots", "log": log_paso_2})

        log_paso_3 = procesar_plantillas(ruta_nuevo_canal, reemplazos) # Y esta
        resultado_json["pasos"].append({"paso": "Procesamiento de Plantillas", "log": log_paso_3})

        log_paso_4 = actualizar_monitor(reemplazos)
        resultado_json["pasos"].append({"paso": "Actualización del Monitor", "log": log_paso_4})

        log_paso_5 = reiniciar_servicios()
        resultado_json["pasos"].append({"paso": "Reinicio de Servicios", "log": log_paso_5})

        resultado_json["conclusion"] = f"¡PROCESO COMPLETADO! El canal '{args.nombre}' ha sido creado y configurado."

        # Al final, en lugar de muchos prints, imprimimos el diccionario como un string JSON
        print(json.dumps(resultado_json, indent=4))
        sys.exit(0)

    except (ValueError, FileExistsError, RuntimeError, Exception) as e:
        error_json = {
            "error": True,
            "mensaje": str(e)
        }
        print(json.dumps(error_json, indent=4), file=sys.stderr)
        sys.exit(1) # Termina el script con un código de error