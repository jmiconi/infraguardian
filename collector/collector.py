import os
import time
import socket
import psutil
import psycopg2
from datetime import datetime


# -----------------------------------------
# CONFIGURACIÓN DE BASE DE DATOS
# -----------------------------------------

DB_HOST = os.getenv("POSTGRES_HOST", "postgres")
DB_NAME = os.getenv("POSTGRES_DB")
DB_USER = os.getenv("POSTGRES_USER")
DB_PASS = os.getenv("POSTGRES_PASSWORD")

# -----------------------------------------
# FUNCIÓN: CONECTAR A POSTGRESQL
# -----------------------------------------

def connect_db():
    """
    Intenta conectarse a PostgreSQL hasta que esté disponible.
    Esto es necesario porque Docker puede levantar
    el collector antes que la base de datos.
    """

    while True:
        try:
            conn = psycopg2.connect(
                host=DB_HOST,
                database=DB_NAME,
                user=DB_USER,
                password=DB_PASS
            )

            print(f"Collector connected to PostgreSQL: {DB_NAME} on {DB_HOST}")
            return conn

        except Exception as e:

            print("PostgreSQL no disponible todavía...")
            print("Reintentando en 5 segundos")

            time.sleep(5)


# -----------------------------------------
# FUNCIÓN: GUARDAR MÉTRICA
# -----------------------------------------

def save_metric(device, sensor, value, status):
    """
    Inserta una métrica en la base de datos.

    IMPORTANTE:
    El timestamp lo genera PostgreSQL con NOW()
    para evitar problemas de timezone.
    """

    conn = connect_db()
    cursor = conn.cursor()

    query = """
    INSERT INTO metrics (timestamp, device, sensor, value, status)
    VALUES (NOW(), %s, %s, %s, %s)
    """

    cursor.execute(
        query,
        (device, sensor, value, status)
    )

    conn.commit()

    cursor.close()
    conn.close()

    print(f"Métrica guardada → {sensor}: {value}")


# -----------------------------------------
# FUNCIÓN: OBTENER MÉTRICAS DEL SISTEMA
# -----------------------------------------

def collect_metrics():
    """
    Obtiene métricas básicas del sistema.
    """

    device = socket.gethostname()

    cpu = psutil.cpu_percent(interval=1)
    ram = psutil.virtual_memory().percent
    disk = psutil.disk_usage("/").percent

    return device, cpu, ram, disk


# -----------------------------------------
# LOOP PRINCIPAL
# -----------------------------------------

if __name__ == "__main__":

    print("InfraGuardian Collector iniciado")

    while True:

        device, cpu, ram, disk = collect_metrics()

        save_metric(device, "cpu_usage", cpu, "ok")
        save_metric(device, "ram_usage", ram, "ok")
        save_metric(device, "disk_usage", disk, "ok")

        # Esperamos 30 segundos
        time.sleep(10)
