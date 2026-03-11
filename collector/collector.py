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
HOST_ROLE = os.getenv("HOST_ROLE", "unknown")
ENVIRONMENT = os.getenv("ENVIRONMENT", "lab")


# -----------------------------------------
# FUNCTION: CONNECT TO POSTGRESQL
# -----------------------------------------
# Tries to connect until the database becomes available.
# This is useful in environments where the collector
# may start before PostgreSQL is fully ready.
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
# FUNCTION: COLLECT SYSTEM METRICS
# -----------------------------------------
# Collects one complete snapshot of the current host.
#
# hostname            = system hostname
# cpu_percent         = CPU usage percentage
# ram_percent         = RAM usage percentage
# disk_percent        = disk usage percentage for "/"
# process_count       = number of running processes
# load_1/load_5/load_15 = system load averages (Linux/Unix)
# network_bytes_sent  = total bytes sent since boot
# network_bytes_recv  = total bytes received since boot
# -----------------------------------------

def collect_metrics():
    hostname = socket.gethostname()

    cpu_percent = psutil.cpu_percent(interval=1)
    ram_percent = psutil.virtual_memory().percent
    disk_percent = psutil.disk_usage("/").percent
    process_count = len(psutil.pids())

    # Load average is available on Linux/Unix.
    # If the platform does not support it, store NULL-compatible values.
    try:
        load_1, load_5, load_15 = os.getloadavg()
    except (AttributeError, OSError):
        load_1, load_5, load_15 = None, None, None

    net = psutil.net_io_counters()
    network_bytes_sent = net.bytes_sent
    network_bytes_recv = net.bytes_recv

    return {
        "hostname": hostname,
        "role": HOST_ROLE,
        "environment": ENVIRONMENT,
        "cpu_percent": cpu_percent,
        "ram_percent": ram_percent,
        "disk_percent": disk_percent,
        "process_count": process_count,
        "load_1": load_1,
        "load_5": load_5,
        "load_15": load_15,
        "network_bytes_sent": network_bytes_sent,
        "network_bytes_recv": network_bytes_recv,
    }


# -----------------------------------------
# FUNCTION: SAVE METRICS
# -----------------------------------------
# Saves one complete host snapshot into system_metrics.
# One collection cycle = one row in the database.
# -----------------------------------------

def save_metrics(metrics):
    conn = None
    cursor = None

    try:
        conn = connect_db()
        cursor = conn.cursor()

        query = """
        INSERT INTO system_metrics (
            collected_at,
            hostname,
            role,
            environment,
            cpu_percent,
            ram_percent,
            disk_percent,
            process_count,
            load_1,
            load_5,
            load_15,
            network_bytes_sent,
            network_bytes_recv
        )
        VALUES (
            NOW(),
            %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s
        )
        """

        values = (
            metrics["hostname"],
            metrics["role"],
            metrics["environment"],
            metrics["cpu_percent"],
            metrics["ram_percent"],
            metrics["disk_percent"],
            metrics["process_count"],
            metrics["load_1"],
            metrics["load_5"],
            metrics["load_15"],
            metrics["network_bytes_sent"],
            metrics["network_bytes_recv"],
        )

        cursor.execute(query, values)
        conn.commit()

        print(
            f"[OK] Metrics stored for hostname={metrics['hostname']} "
            f"role={metrics['role']} env={metrics['environment']}"
        )
        print(f"     cpu_percent         = {metrics['cpu_percent']}")
        print(f"     ram_percent         = {metrics['ram_percent']}")
        print(f"     disk_percent        = {metrics['disk_percent']}")
        print(f"     process_count       = {metrics['process_count']}")
        print(f"     load_1              = {metrics['load_1']}")
        print(f"     load_5              = {metrics['load_5']}")
        print(f"     load_15             = {metrics['load_15']}")
        print(f"     network_bytes_sent  = {metrics['network_bytes_sent']}")
        print(f"     network_bytes_recv  = {metrics['network_bytes_recv']}")

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
    print(f"[INFO] Host role: {HOST_ROLE}")
    print(f"[INFO] Environment: {ENVIRONMENT}")

    while True:
        metrics = collect_metrics()
        save_metrics(metrics)
        time.sleep(COLLECTOR_INTERVAL)