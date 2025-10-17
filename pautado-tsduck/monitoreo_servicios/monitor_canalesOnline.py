#!/usr/bin/env python3
import subprocess
import time
import threading
from datetime import datetime
import os

# Directorio donde se encuentra ESTE script (/home/pi/pautado-tsduck/monitoreo_servicios)
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))

# Directorio raíz del proyecto, un nivel arriba del script (/home/pi/pautado-tsduck)
PROJECT_ROOT = os.path.dirname(SCRIPT_DIR)

# La ruta al archivo de configuración ahora es relativa al script.
CONFIG_FILE = os.path.join(SCRIPT_DIR, "canales.conf")

# La ruta al log también puede estar junto al script.
LOG_FILE = os.path.join(SCRIPT_DIR, "monitor.log")

MAX_FAILURES = 3
RETRY_DELAY_S = 5
LOOP_DELAY_S = 20
FFPROBE_TIMEOUT = "3000000"
# --- FIN DE CONFIGURACIÓN ---

def log(channel_name, message):
    timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    log_message = f"{timestamp} [{channel_name}] - {message}\n"
    with threading.Lock():
        print(log_message, end='')
        with open(LOG_FILE, "a") as f:
            f.write(log_message)

def monitor_channel(channel_name, stream_url):
    failure_count = 0
    # La ruta a los canales se construye desde la raíz del proyecto.
    script_path = os.path.join(PROJECT_ROOT, "canales", channel_name, "start_vlc.sh")
    channel_dir = os.path.dirname(script_path)

    log(channel_name, "Vigilante iniciado.")

    while True:
        command = [ "ffprobe", "-v", "error", "-timeout", FFPROBE_TIMEOUT, f"udp://{stream_url}" ]
        result = subprocess.run(command, capture_output=True)

        if result.returncode == 0:
            if failure_count > 0:
                log(channel_name, "ÉXITO: Canal recuperado.")
            failure_count = 0
            time.sleep(LOOP_DELAY_S)
        else:
            failure_count += 1
            log(channel_name, f"FALLO [{failure_count}/{MAX_FAILURES}]: El stream no responde.")

            if failure_count >= MAX_FAILURES:
                log(channel_name, f"ACCIÓN: Límite de fallos alcanzado. Reiniciando el canal...")
                if os.path.exists(script_path):
                    subprocess.Popen([script_path], cwd=channel_dir)
                    log(channel_name, "ACCIÓN: Comando de reinicio enviado.")
                else:
                    log(channel_name, f"ERROR CRÍTICO: No se encontró el script de reinicio en {script_path}")
                failure_count = 0
            
            time.sleep(RETRY_DELAY_S)

if __name__ == "__main__":
    threads = []
    log("MAIN", "--- Iniciando Monitor Concurrente de Canales ---")
    
    if not os.path.exists(CONFIG_FILE):
         log("MAIN", f"ERROR CRÍTICO: El archivo de configuración {CONFIG_FILE} no existe. Saliendo.")
         exit(1)

    with open(CONFIG_FILE, "r") as f:
        for line in f:
            if line.strip() and not line.strip().startswith("#"):
                parts = line.strip().split()
                channel_name, stream_url = parts[0], parts[1]
                
                thread = threading.Thread(target=monitor_channel, args=(channel_name, stream_url))
                threads.append(thread)
                thread.daemon = True
                thread.start()
                log("MAIN", f"Vigilante para '{channel_name}' ({stream_url}) ha sido lanzado.")

    log("MAIN", "Todos los vigilantes están activos. El sistema está bajo supervisión.")
    for thread in threads:
        thread.join()