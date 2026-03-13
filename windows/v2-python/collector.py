import os
import time
import socket
import logging
from logging.handlers import RotatingFileHandler
from datetime import datetime

import psutil
import psycopg
from dotenv import load_dotenv


# --------------------------------------------------
# PATHS
# --------------------------------------------------

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
ENV_FILE = os.path.join(BASE_DIR, "config.env")

LOG_DIR = "C:\\InfraGuardian\\logs"
LOG_FILE = os.path.join(LOG_DIR, "collector.log")


# --------------------------------------------------
# CREATE LOG DIRECTORY IF NOT EXISTS
# --------------------------------------------------

if not os.path.exists(LOG_DIR):
    os.makedirs(LOG_DIR)


# --------------------------------------------------
# LOGGING CONFIGURATION
# --------------------------------------------------

logger = logging.getLogger("InfraGuardianCollector")
logger.setLevel(logging.INFO)

formatter = logging.Formatter(
    "%(asctime)s | %(levelname)s | %(message)s",
    "%Y-%m-%d %H:%M:%S"
)

file_handler = RotatingFileHandler(
    LOG_FILE,
    maxBytes=5 * 1024 * 1024,
    backupCount=5
)

file_handler.setFormatter(formatter)

console_handler = logging.StreamHandler()
console_handler.setFormatter(formatter)

logger.addHandler(file_handler)
logger.addHandler(console_handler)


# --------------------------------------------------
# LOAD CONFIG
# --------------------------------------------------

if os.path.exists(ENV_FILE):
    load_dotenv(ENV_FILE)
else:
    logger.warning(f"config.env not found at: {ENV_FILE}")

DB_HOST = os.getenv("POSTGRES_HOST", "localhost")
DB_PORT = int(os.getenv("POSTGRES_PORT", "5432"))
DB_NAME = os.getenv("POSTGRES_DB", "infraguardian")
DB_USER = os.getenv("POSTGRES_USER", "igadmin")
DB_PASS = os.getenv("POSTGRES_PASSWORD", "")

HOST_ROLE = os.getenv("HOST_ROLE", "windows-server")
HOST_ENVIRONMENT = os.getenv("HOST_ENVIRONMENT", "production")

COLLECTOR_INTERVAL = int(os.getenv("COLLECTOR_INTERVAL", "30"))
DISK_PATH = os.getenv("DISK_PATH", "C:\\")


# --------------------------------------------------
# CONNECTION STRING
# --------------------------------------------------

def get_connection_string() -> str:
    return (
        f"host={DB_HOST} "
        f"port={DB_PORT} "
        f"dbname={DB_NAME} "
        f"user={DB_USER} "
        f"password={DB_PASS}"
    )


# --------------------------------------------------
# METRICS COLLECTION
# --------------------------------------------------

def collect_metrics() -> dict:

    hostname = socket.gethostname()

    cpu_percent = psutil.cpu_percent(interval=1)
    ram_percent = psutil.virtual_memory().percent
    disk_percent = psutil.disk_usage(DISK_PATH).percent
    process_count = len(psutil.pids())

    net_io = psutil.net_io_counters()

    metrics = {
        "hostname": hostname,
        "role": HOST_ROLE,
        "environment": HOST_ENVIRONMENT,
        "cpu_percent": cpu_percent,
        "ram_percent": ram_percent,
        "disk_percent": disk_percent,
        "process_count": process_count,
        "load_1": None,
        "load_5": None,
        "load_15": None,
        "network_bytes_sent": net_io.bytes_sent,
        "network_bytes_recv": net_io.bytes_recv,
    }

    return metrics


# --------------------------------------------------
# PRINT METRICS (CONSOLA)
# --------------------------------------------------

def print_metrics(metrics: dict):

    print("-" * 40)
    print("InfraGuardian Collector - New Sample")
    print(f"Timestamp: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"Hostname: {metrics['hostname']}")
    print(f"Role: {metrics['role']}")
    print(f"Environment: {metrics['environment']}")
    print(f"CPU %: {metrics['cpu_percent']:.2f}")
    print(f"RAM %: {metrics['ram_percent']:.2f}")
    print(f"Disk %: {metrics['disk_percent']:.2f}")
    print(f"Process Count: {metrics['process_count']}")
    print(f"Load 1: {metrics['load_1']}")
    print(f"Load 5: {metrics['load_5']}")
    print(f"Load 15: {metrics['load_15']}")
    print(f"Network Bytes Sent: {metrics['network_bytes_sent']}")
    print(f"Network Bytes Recv: {metrics['network_bytes_recv']}")
    print("-" * 40)


# --------------------------------------------------
# INSERT INTO POSTGRESQL
# --------------------------------------------------

def insert_metrics(metrics: dict):

    insert_sql = """
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
            %(hostname)s,
            %(role)s,
            %(environment)s,
            %(cpu_percent)s,
            %(ram_percent)s,
            %(disk_percent)s,
            %(process_count)s,
            %(load_1)s,
            %(load_5)s,
            %(load_15)s,
            %(network_bytes_sent)s,
            %(network_bytes_recv)s
        );
    """

    conn_str = get_connection_string()

    with psycopg.connect(conn_str) as conn:
        with conn.cursor() as cur:
            cur.execute(insert_sql, metrics)

        conn.commit()


# --------------------------------------------------
# MAIN LOOP
# --------------------------------------------------

def main():

    logger.info("InfraGuardian Windows Collector starting")
    logger.info(f"DB target: {DB_HOST}:{DB_PORT}/{DB_NAME}")
    logger.info(f"Role: {HOST_ROLE}")
    logger.info(f"Environment: {HOST_ENVIRONMENT}")
    logger.info(f"Disk path: {DISK_PATH}")
    logger.info(f"Interval: {COLLECTOR_INTERVAL}s")

    while True:

        try:

            metrics = collect_metrics()

            print_metrics(metrics)

            logger.info("New metrics sample")
            logger.info(f"Hostname: {metrics['hostname']}")
            logger.info(f"CPU: {metrics['cpu_percent']:.2f}%")
            logger.info(f"RAM: {metrics['ram_percent']:.2f}%")
            logger.info(f"Disk: {metrics['disk_percent']:.2f}%")
            logger.info(f"Process count: {metrics['process_count']}")

            insert_metrics(metrics)

            logger.info("Metrics inserted into PostgreSQL")

        except Exception as e:

            logger.error(f"Collector error: {str(e)}")

        time.sleep(COLLECTOR_INTERVAL)


# --------------------------------------------------

if __name__ == "__main__":
    main()