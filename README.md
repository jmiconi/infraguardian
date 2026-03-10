===============================================================================
  PROJECT: InfraGuardian
  MAINTAINER: jmiconi
  ROLE: Lightweight Infrastructure Observability Stack
  VERSION: 0.1.0-beta
  STATUS: Development / MVP
===============================================================================

## 1. EXECUTIVE SUMMARY
InfraGuardian is an opinionated observability solution designed for automated 
system metrics monitoring. It leverages a decoupled architecture to ensure 
that data collection, persistence, and visualization layers scale independently 
following SRE best practices.

## 2. TECHNICAL STACK (CORE COMPONENTS)
* COLLECTOR: Python 3.11 (Asynchronous ingestion engine).
* STORAGE: PostgreSQL 15 (Relational backend for time-series data).
* VISUALIZATION: Grafana 10.x (Automated Dashboard-as-Code provisioning).
* ORCHESTRATION: Docker Compose (Immutable infrastructure manifest).

## 3. REPOSITORY STRUCTURE
The project follows a "Separation of Concerns" (SoC) directory pattern:

.
├── collector/          # Ingestion logic & Python SDK
├── db/                 # SQL DDL & persistence layer
│   └── init/           # Auto-initialization scripts (Schema Seeders)
├── grafana/            # Observability config (Provisioning & Dashboards)
│   ├── dashboards/     # JSON Dashboard definitions
│   └── provisioning/   # Automated Datasource/Provider configs
├── setup.sh            # Environment bootstrap script
├── .env.example        # Environment configuration template
└── docker-compose.yml  # Multi-container orchestration manifest

## 4. DEPLOYMENT & INSTALLATION

### 4.1. First-Time Setup (Bootstrap)
We provide a bootstrap script to automate environment validation, dependency 
checks, and initial configuration:

# Clone the asset
$ git clone https://github.com/jmiconi/infraguardian.git
$ cd infraguardian

# Run the bootstrap script
$ chmod +x setup.sh
$ ./setup.sh

### 4.2. Manual Quickstart
If you prefer manual orchestration, execute the following:

# Initialize environment variables
$ cp .env.example .env

# Provision the full stack (Detached Mode)
$ docker compose up -d --build

## 5. SCHEMA DEFINITION (TIME-SERIES)
The `metrics` table is indexed and optimized for time-based aggregation queries:

| Column     | Data Type    | Description                              |
|------------|--------------|------------------------------------------|
| id         | UUID/PK      | Unique entry identifier                  |
| timestamp  | TIMESTAMPTZ  | Event capture time (UTC)                 |
| device     | VARCHAR      | Origin hostname or instance ID           |
| sensor     | VARCHAR      | Metric type (cpu, ram, disk)             |
| value      | FLOAT        | Recorded numerical value                 |
| status     | ENUM         | Health state (ok, warning, critical)     |

## 6. ACCESS & DEFAULT CREDENTIALS
* GRAFANA UI: http://localhost:3000 (User: admin / Pass: admin)
* POSTGRES: localhost:5432 (Local port-forwarding enabled)

## 7. OBSERVED TELEMETRY
The 'Collector' agent currently monitors:
- CPU Utilization: Percentage load per core.
- RAM Usage: Available vs. Committed memory.
- Disk I/O: Capacity and mount point utilization.

## 8. ENGINEERING ROADMAP
[ ] Migration to TimescaleDB for hyper-table optimizations.
[ ] Multi-host agent support (Remote Linux/Windows exporters).
[ ] Webhook-based Alerting (Slack/PagerDuty) based on status thresholds.
[ ] OpenTelemetry (OTel) exporter compatibility.

---
Maintained by jmiconi
"In code we trust, in metrics we verify."
===============================================================================
