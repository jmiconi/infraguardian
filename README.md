# InfraGuardian

Infrastructure observability platform for **Windows and Linux environments**, built around lightweight collectors, PostgreSQL and Grafana.

InfraGuardian is designed as a practical infrastructure engineering project: collect operational data from heterogeneous hosts, persist historical metrics, visualize system health and provide a foundation for automation and capacity analysis.

## Why this project exists

Traditional infrastructure environments often grow around multiple operating systems, isolated monitoring scripts and manual troubleshooting. InfraGuardian explores a simple, auditable architecture that keeps collection, storage and visualization separated.

The goal is not to replace every monitoring platform. It is to provide a transparent stack that can be understood, deployed and extended by an infrastructure team.

## Architecture

```text
┌─────────────────┐        ┌─────────────────┐
│  Linux hosts    │        │  Windows hosts  │
│ Python collector│        │ PS/Python agent │
└────────┬────────┘        └────────┬────────┘
         │                          │
         └────────────┬─────────────┘
                      ▼
               ┌────────────┐
               │ PostgreSQL │
               │ historical │
               │  metrics   │
               └─────┬──────┘
                     ▼
               ┌────────────┐
               │  Grafana   │
               │ dashboards │
               └────────────┘
```

See [ARCHITECTURE.md](ARCHITECTURE.md) for the design in more detail.

## What it collects

Current collectors are designed around host-level infrastructure metrics such as:

- CPU utilization
- memory utilization
- disk utilization
- process count
- network traffic
- hostname / node identity
- collection timestamps

The repository includes implementations and deployment material for both Linux and Windows-oriented collection.

## Stack

| Layer | Technology |
|---|---|
| Collection | Python, PowerShell, psutil |
| Storage | PostgreSQL |
| Visualization | Grafana |
| Runtime | Docker / Docker Compose |
| Linux operations | Bash, systemd |
| Windows operations | PowerShell |
| Configuration | Environment variables / example configuration files |

## Repository structure

```text
infraguardian/
├── collector/          # collector implementation
├── windows/            # Windows collector/deployment material
├── db/                 # database initialization
├── grafana/            # provisioning and dashboards
├── deploy/             # deployment helpers
├── systemd/            # Linux service integration
├── scripts/            # operational scripts
├── docker-compose.yml
├── setup.sh
├── ARCHITECTURE.md
├── COLLECTORS.md
├── DEVOPS_WORKFLOW.md
└── VALIDATION.md
```

## Quick start — Ubuntu Server 24.04 LTS

The sequence below is intended to be reproducible on a clean Ubuntu Server installation.

### 1. Install base tools

```bash
sudo apt update
sudo apt -y upgrade
sudo apt install -y git curl ca-certificates
```

### 2. Clone the repository

```bash
cd /opt
sudo git clone https://github.com/jmiconi/infraguardian.git
sudo chown -R "$USER":"$USER" /opt/infraguardian
cd /opt/infraguardian
```

### 3. Bootstrap Docker

```bash
chmod +x setup.sh
./setup.sh
```

If the script adds your account to the `docker` group, log out and reconnect before continuing.

Validate:

```bash
docker --version
docker compose version
docker ps
```

### 4. Configure the platform

```bash
cd /opt/infraguardian
cp .env.example .env
docker compose config
```

The example credentials are lab defaults only. Replace them before exposing the platform beyond an isolated test environment.

### 5. Start PostgreSQL and Grafana

```bash
docker compose up -d
docker compose ps
```

Expected state:

- `ig-postgres` becomes `healthy`
- `ig-grafana` becomes `Up`
- Grafana listens on TCP/3000

`docker compose up -d` returning successfully means the containers were started; Grafana may still need a few seconds before its HTTP endpoint is ready. Wait for application readiness instead of assuming container state means HTTP readiness:

```bash
until curl -fsS -o /dev/null http://localhost:3000/login; do
  echo "Waiting for Grafana..."
  sleep 2
done

echo "Grafana is ready"
curl -I http://localhost:3000
```

A `302` redirect to `/login` from the root endpoint confirms that Grafana is responding.

Validate the database schema:

```bash
docker exec -it ig-postgres \
  psql -U igadmin -d infraguardian \
  -c "\\dt"
```

### 6. Install the Linux collector

```bash
sudo apt install -y python3-venv python3-pip

cd /opt/infraguardian
python3 -m venv venv
./venv/bin/pip install --upgrade pip
./venv/bin/pip install -r collector/requirements.txt
```

Create the collector configuration:

```bash
cp collector/config.env.example collector/config.env
```

For the default single-host lab deployment, the collector can connect to PostgreSQL through `127.0.0.1:5432`.

Review `collector/config.env` and make sure its PostgreSQL credentials match `.env`.

### 7. Test the collector manually

```bash
cd /opt/infraguardian
set -a
source collector/config.env
set +a
./venv/bin/python -u collector/collector.py
```

After a few collection cycles, stop it with `Ctrl+C` and verify stored data:

```bash
docker exec -it ig-postgres \
  psql -U igadmin -d infraguardian \
  -c "SELECT collected_at, hostname, cpu_percent, ram_percent, disk_percent FROM system_metrics ORDER BY collected_at DESC LIMIT 10;"
```

### 8. Run the collector with systemd

```bash
sudo cp systemd/infraguardian-collector.service \
  /etc/systemd/system/infraguardian-collector.service

sudo systemctl daemon-reload
sudo systemctl enable --now infraguardian-collector
```

Validate:

```bash
systemctl status infraguardian-collector --no-pager
journalctl -u infraguardian-collector -n 50 --no-pager
```

### 9. Validate Grafana

Open:

```text
http://<server-ip>:3000
```

The provisioned **InfraGuardian Host Overview** dashboard should display the host data written to `system_metrics`.

### 10. Reboot validation

A deployment should survive a host reboot without manual intervention.

```bash
sudo reboot
```

After reconnecting:

```bash
cd /opt/infraguardian
systemctl status docker --no-pager
systemctl status infraguardian-collector --no-pager
docker compose ps
curl -I http://localhost:3000
```

Then confirm that new rows continue to appear in `system_metrics`.

See [VALIDATION.md](VALIDATION.md) for the clean-VM validation record.

## Engineering principles

This project intentionally emphasizes operational concerns that matter in real infrastructure:

- configuration and secrets are separated from code
- Linux services can be managed through systemd
- Windows deployment is automated with PowerShell
- infrastructure state is persisted for historical analysis
- dashboards are provisioned as part of the platform
- components are kept loosely coupled so they can evolve independently

## Current scope

Implemented or represented in the repository:

- Linux host collection
- Windows host collection/deployment
- PostgreSQL metric persistence
- Grafana provisioning and dashboards
- Docker Compose deployment
- systemd integration
- operational documentation

## Roadmap

Future work includes:

- richer multi-host inventory and metadata
- alerting and health-state evaluation
- service-specific checks
- anomaly detection
- capacity forecasting
- integration with centralized logging
- AI-assisted infrastructure analysis

## Security

This public repository contains only generic configuration and example values. Production credentials, internal hostnames, private addressing and organization-specific data should remain outside the repository.

The default configuration is intended for an isolated lab. PostgreSQL is published on TCP/5432 because host-based and remote collectors may need database access. In a real deployment, restrict that port with host/network firewall rules or change the Compose binding to match the intended collector topology.

## Portfolio context

InfraGuardian represents the kind of work I focus on as an infrastructure engineer: **automation, observability, cross-platform operations and building systems that remain understandable when they need to be troubleshot under pressure**.

---

Built and maintained by [Julián Miconi](https://github.com/jmiconi).
