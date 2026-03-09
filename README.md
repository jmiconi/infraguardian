# InfraGuardian

InfraGuardian is a lightweight infrastructure observability stack built with:

- Docker
- PostgreSQL
- Python
- Grafana

It collects basic system metrics from a host, stores them in PostgreSQL, and visualizes them in Grafana.

## Features

- CPU usage collection
- RAM usage collection
- Disk usage collection
- PostgreSQL as metrics storage
- Grafana datasource provisioning
- Docker Compose deployment
- Environment-based configuration

## Architecture

InfraGuardian currently includes three main components:

- **collector**  
  A Python-based collector that gathers system metrics.

- **postgres**  
  A PostgreSQL database used to store collected metrics.

- **grafana**  
  A Grafana instance used to query and visualize metrics.

## Collected metrics

The collector currently stores the following metrics:

- `cpu_usage`
- `ram_usage`
- `disk_usage`

## Project structure

```text
collector/
  collector.py
  Dockerfile
  requirements.txt

db/
  init/
    01-init.sql
  data/

grafana/
  dashboards/
    system_metrics.json
  provisioning/
    dashboards/
    datasources/
  data/

docker-compose.yml
.env.example
README.md




Requirements

Docker

Docker Compose

Quick start

Clone the repository:

git clone https://github.com/YOUR_USERNAME/infraguardian.git
cd infraguardian

Create your environment file:

cp .env.example .env

Start the stack:

docker compose up -d --build
Services

Grafana: http://localhost:3000

PostgreSQL: localhost:5432

Default Grafana credentials

Username: admin

Password: admin

Database schema

The main table is:

metrics

Columns:

id

timestamp

device

sensor

value

status

Current status

InfraGuardian v0.0.1 provides a functional local observability base with:

Docker Compose orchestration

PostgreSQL metrics ingestion

Python collector

Grafana provisioning

Environment variable support for configuration

Roadmap

Multi-host support

Linux agents

Windows agents

Dynamic dashboards

Event correlation

AI-assisted observability features

License

MIT
