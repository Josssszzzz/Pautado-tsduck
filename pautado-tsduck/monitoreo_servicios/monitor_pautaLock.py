#!/usr/bin/python3
# -*- coding: utf-8 -*-

import subprocess
import requests

# --- CONFIGURACIÓN ---
# ¡IMPORTANTE! Rellena estos valores con tus credenciales.
TELEGRAM_BOT_TOKEN = "6294396591:AAHiHGThKdj9vX9P8qQ-1uPQu_my0A_ORwY"
TELEGRAM_CHAT_ID = "-4870581431"

# Configuración de la búsqueda
DIRECTORIO_A_BUSCAR = "/home/pi/pautado-tsduck/canales"
MINUTOS_ANTIGUEDAD = 5
# --------------------

def send_telegram_message(message):
    """Envía un mensaje a través del bot de Telegram."""
    if not TELEGRAM_BOT_TOKEN or "AQUI_VA" in TELEGRAM_BOT_TOKEN:
        print("Error: El token del bot de Telegram no está configurado.")
        return

    url = f"https://api.telegram.org/bot{TELEGRAM_BOT_TOKEN}/sendMessage"
    payload = {
        "chat_id": TELEGRAM_CHAT_ID,
        "text": message,
        "parse_mode": "Markdown"
    }
    try:
        response = requests.post(url, json=payload, timeout=10)
        if response.status_code == 200:
            print(f"Mensaje de Telegram enviado exitosamente.")
        else:
            print(f"Error al enviar mensaje de Telegram: {response.status_code} - {response.text}")
    except requests.exceptions.RequestException as e:
        print(f"Excepción al conectar con la API de Telegram: {e}")

def buscar_archivos_lock_antiguos():
    """
    Ejecuta el comando 'find' para buscar archivos .lock antiguos y
    envía una notificación por Telegram si encuentra alguno.
    """
    print(f"Buscando archivos .lock con más de {MINUTOS_ANTIGUEDAD} minutos en '{DIRECTORIO_A_BUSCAR}'...")

    # Construimos el comando a ejecutar de forma segura (en una lista)
    command = [
        'find',
        DIRECTORIO_A_BUSCAR,
        '-type', 'f',
        '-name', '*.lock',
        '-mmin', f'+{MINUTOS_ANTIGUEDAD}'
    ]

    try:
        # Ejecutamos el comando y capturamos la salida y los errores
        resultado = subprocess.run(command, capture_output=True, text=True, check=False)

        # Verificamos si hubo algún error al ejecutar 'find' (ej: permisos)
        if resultado.stderr:
            print(f"Error al ejecutar el comando 'find':\n{resultado.stderr.strip()}")
            mensaje_error = (
                f"⚠️ *SCRIPT DE MONITOREO DE PAUTAS.LOCK*\n\n"
                f"⚠️ *Error en el script de monitoreo*\n\n"
                f"El comando 'find' devolvió un error:\n\n"
                f"```\n{resultado.stderr.strip()}\n```"
            )
            send_telegram_message(mensaje_error)
            return

        # Obtenemos la lista de archivos encontrados y quitamos espacios en blanco
        archivos_encontrados = resultado.stdout.strip()

        # Si la variable 'archivos_encontrados' tiene contenido, es que se encontraron archivos
        if archivos_encontrados:
            print(f"¡Alerta! Se encontraron archivos .lock antiguos:\n{archivos_encontrados}")
            
            # Preparamos el mensaje para Telegram
            mensaje_alerta = (
                f"⚠️ *SCRIPT DE MONITOREO DE PAUTAS.LOCK*\n\n"
                f"🚨 *Alerta: Se encontraron archivos .lock antiguos!*\n\n"
                f"Se detectaron los siguientes archivos con más de {MINUTOS_ANTIGUEDAD} minutos de antigüedad:\n\n"
                f"```\n{archivos_encontrados}\n```\n\n"
                f"Estos archivos indican que un canal, no se encuentra pautando."
            )
            
            # Enviamos la notificación
            send_telegram_message(mensaje_alerta)
        else:
            # Si no se encontraron archivos, simplemente lo mostramos en la consola.
            print("No se encontraron archivos .lock antiguos. Todo en orden.")

    except FileNotFoundError:
        # Esto solo ocurriría si el comando 'find' no existe en el sistema
        print("Error: El comando 'find' no se encontró. Asegúrate de que esté instalado.")
        send_telegram_message("⚠️ Error Crítico: El comando 'find' no se encuentra en el sistema del Pi.")
    except Exception as e:
        print(f"Ha ocurrido un error inesperado: {e}")
        send_telegram_message(f"⚠️ Error Crítico inesperado en el script de monitoreo: {e}")


# --- Punto de entrada principal del script ---
if __name__ == "__main__":
    buscar_archivos_lock_antiguos()
