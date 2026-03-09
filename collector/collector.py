import os
import time
import socket
import psutil
import psycopg2


# -----------------------------------------
# CONFIGURACIÓN
# -----------------------------------------
# Todas las variables salen del entorno.
# Esto permite que el collector sea portable
# y no dependa de valores hardcodeados.
# Si alguna variable no existe, usamos un valor
# por defecto razonable para el lab/proyecto.
# -----------------------------------------

DB_HOST = os.getenv("POSTGRES_HOST", "ig-postgres")
DB_PORT = int(os.getenv("POSTGRES_PORT", "5432"))
DB_NAME = os.getenv("POSTGRES_DB", "infraguardian")
DB_USER = os.getenv("POSTGRES_USER", "igadmin")
DB_PASS = os.getenv("POSTGRES_PASSWORD", "")
COLLECTOR_INTERVAL = int(os.getenv("COLLECTOR_INTERVAL", "30"))


# -----------------------------------------
# FUNCIÓN: CONECTAR A POSTGRESQL
# -----------------------------------------
# Intenta conectarse hasta que la base esté
# disponible. Esto es útil en Docker, porque
# el collector puede arrancar antes que Postgres.
# -----------------------------------------

def connect_db():
    while True:
        try:
            conn = psycopg2.connect(
                host=DB_HOST,
                port=DB_PORT,
                database=DB_NAME,
                user=DB_USER,
                password=DB_PASS
            )

            print(
                f"[OK] Collector connected to PostgreSQL: "
                f"{DB_NAME} on {DB_HOST}:{DB_PORT}"
            )
            return conn

        except Exception as e:
            print("[WARN] PostgreSQL no disponible todavía")
            print(f"[DETAIL] {e}")
            print("[INFO] Reintentando en 5 segundos...")
            time.sleep(5)


# -----------------------------------------
# FUNCIÓN: GUARDAR MÉTRICAS
# -----------------------------------------
# Guarda las 3 métricas del ciclo usando
# una sola conexión y una sola transacción.
# Esto reduce overhead y deja el collector
# más prolijo para crecer después.
# -----------------------------------------

def save_metrics(device, cpu, ram, disk):
    conn = None
    cursor = None

    try:
        conn = connect_db()
        cursor = conn.cursor()

        query = """
        INSERT INTO metrics (timestamp, device, sensor, value, status)
        VALUES (NOW(), %s, %s, %s, %s)
        """

        metrics = [
            (device, "cpu_usage", cpu, "ok"),
            (device, "ram_usage", ram, "ok"),
            (device, "disk_usage", disk, "ok")
        ]

        cursor.executemany(query, metrics)
        conn.commit()

        print(f"[OK] Métricas guardadas para device={device}")
        print(f"     cpu_usage  = {cpu}")
        print(f"     ram_usage  = {ram}")
        print(f"     disk_usage = {disk}")

    except Exception as e:
        print("[ERROR] No se pudieron guardar las métricas en PostgreSQL")
        print(f"[DETAIL] {e}")

        if conn:
            conn.rollback()

    finally:
        if cursor:
            cursor.close()
        if conn:
            conn.close()


# -----------------------------------------
# FUNCIÓN: OBTENER MÉTRICAS DEL SISTEMA
# -----------------------------------------
# device = hostname del contenedor/equipo
# cpu    = porcentaje de CPU
# ram    = porcentaje de RAM usada
# disk   = porcentaje de disco usado en /
# -----------------------------------------

def collect_metrics():
    device = socket.gethostname()

    cpu = psutil.cpu_percent(interval=1)
    ram = psutil.virtual_memory().percent
    disk = psutil.disk_usage("/").percent

    return device, cpu, ram, disk


# -----------------------------------------
# LOOP PRINCIPAL
# -----------------------------------------
# Ciclo infinito:
# 1. toma métricas
# 2. las guarda en DB
# 3. espera el intervalo configurado
# -----------------------------------------

if __name__ == "__main__":
    print("[INFO] InfraGuardian Collector iniciado")
    print(f"[INFO] Intervalo de recolección: {COLLECTOR_INTERVAL} segundos")
    print(f"[INFO] Destino PostgreSQL: {DB_HOST}:{DB_PORT}/{DB_NAME}")

    while True:
        device, cpu, ram, disk = collect_metrics()
        save_metrics(device, cpu, ram, disk)
        time.sleep(COLLECTOR_INTERVAL)
