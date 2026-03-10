import os
import time
import socket
import psutil
import psycopg2


# -----------------------------------------
# CONFIGURATION
# -----------------------------------------
# All values are loaded from environment variables.
# This keeps the collector portable and avoids hardcoded settings.
# If a variable is not defined, a reasonable default is used
# for lab or development environments.
# -----------------------------------------

DB_HOST = os.getenv("POSTGRES_HOST", "ig-postgres")
DB_PORT = int(os.getenv("POSTGRES_PORT", "5432"))
DB_NAME = os.getenv("POSTGRES_DB", "infraguardian")
DB_USER = os.getenv("POSTGRES_USER", "igadmin")
DB_PASS = os.getenv("POSTGRES_PASSWORD", "")
COLLECTOR_INTERVAL = int(os.getenv("COLLECTOR_INTERVAL", "30"))


# -----------------------------------------
# FUNCTION: CONNECT TO POSTGRESQL
# -----------------------------------------
# Tries to connect until the database becomes available.
# This is useful in Docker environments because the collector
# may start before the PostgreSQL container is fully ready.
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
            print("[WARN] PostgreSQL not available yet")
            print(f"[DETAIL] {e}")
            print("[INFO] Retrying in 5 seconds...")
            time.sleep(5)


# -----------------------------------------
# FUNCTION: SAVE METRICS
# -----------------------------------------
# Saves the metrics collected in the current cycle
# using a single connection and transaction.
# This reduces overhead and keeps the collector
# simple enough for future expansion.
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

        # One row is stored per metric type.
        # This keeps the schema flexible for future sensors.
        metrics = [
            (device, "cpu_usage", cpu, "ok"),
            (device, "ram_usage", ram, "ok"),
            (device, "disk_usage", disk, "ok")
        ]

        cursor.executemany(query, metrics)
        conn.commit()

        print(f"[OK] Metrics stored for device={device}")
        print(f"     cpu_usage  = {cpu}")
        print(f"     ram_usage  = {ram}")
        print(f"     disk_usage = {disk}")

    except Exception as e:
        print("[ERROR] Failed to store metrics in PostgreSQL")
        print(f"[DETAIL] {e}")

        if conn:
            conn.rollback()

    finally:
        if cursor:
            cursor.close()
        if conn:
            conn.close()


# -----------------------------------------
# FUNCTION: COLLECT SYSTEM METRICS
# -----------------------------------------
# device = hostname reported by the runtime environment
# cpu    = CPU usage percentage
# ram    = RAM usage percentage
# disk   = disk usage percentage for "/"
# -----------------------------------------

def collect_metrics():
    device = socket.gethostname()

    cpu = psutil.cpu_percent(interval=1)
    ram = psutil.virtual_memory().percent
    disk = psutil.disk_usage("/").percent

    return device, cpu, ram, disk


# -----------------------------------------
# MAIN LOOP
# -----------------------------------------
# Infinite loop:
# 1. collect metrics
# 2. store them in the database
# 3. wait for the configured interval
# -----------------------------------------

if __name__ == "__main__":
    print("[INFO] InfraGuardian Collector started")
    print(f"[INFO] Collection interval: {COLLECTOR_INTERVAL} seconds")
    print(f"[INFO] PostgreSQL target: {DB_HOST}:{DB_PORT}/{DB_NAME}")

    while True:
        device, cpu, ram, disk = collect_metrics()
        save_metrics(device, cpu, ram, disk)
        time.sleep(COLLECTOR_INTERVAL)
