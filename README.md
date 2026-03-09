# InfraGuardian

InfraGuardian is a lightweight infrastructure monitoring platform built with Docker, PostgreSQL and Grafana.

The project collects system metrics from hosts and stores them in PostgreSQL for visualization in Grafana dashboards.

## Architecture

Collector → PostgreSQL → Grafana

The collector gathers metrics such as:

- CPU usage
- RAM usage
- Disk usage

These metrics are stored as time-series data in PostgreSQL and visualized through Grafana dashboards.

## Stack

- Python
- PostgreSQL
- Grafana
- Docker

## Quick Start

Clone the repository:
git clone https://github.com/YOURUSER/infraguardian.git

cd infraguardian

Create environment file:
cp .env.example .env

Start the stack:
docker compose up -d

Grafana will be available at:
http://localhost:3000

Default credentials:
admin / admin

## Current Features (v0.0.1)

- System metrics collector
- PostgreSQL time-series storage
- Grafana visualization
- Docker-based deployment

## Roadmap

v0.0.2
- Multi-host agents
- Linux / Windows support

v0.0.3
- Anomaly detection
- AI-assisted diagnostics

## License

MIT
