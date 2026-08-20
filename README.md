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
└── DEVOPS_WORKFLOW.md
```

## Quick start

### Prerequisites

Validated on **Ubuntu Server 24.04.4 LTS**.

A fresh host needs only Git, curl and CA certificates before cloning the repository:

```bash
sudo apt update
sudo apt install -y git curl ca-certificates
```

### 1. Clone

```bash
sudo git clone https://github.com/jmiconi/infraguardian.git /opt/infraguardian
sudo chown -R "$USER":"$USER" /opt/infraguardian
cd /opt/infraguardian
```

### 2. Bootstrap Docker

The repository includes a bootstrap script that installs Docker when it is not already present and adds the current user to the `docker` group.

```bash
chmod +x setup.sh
./setup.sh
```

If the script adds your account to the `docker` group, log out and log back in before continuing:

```bash
exit
```

After reconnecting, verify access:

```bash
groups
docker --version
docker compose version
docker ps
```

The `groups` output should include `docker` and `docker ps` should work without `sudo`.

### 3. Review configuration

Use the example environment file as a starting point and keep real credentials outside version control.

```bash
cd /opt/infraguardian
cp .env.example .env
```

Change the example PostgreSQL password before starting the stack.

### 4. Validate Compose configuration

```bash
docker compose config
```

This catches missing variables and Compose syntax problems before containers are started.

### 5. Start the platform

```bash
docker compose up -d
```

### 6. Validate containers

```bash
docker compose ps
docker compose logs --tail=100 postgres
docker compose logs --tail=100 grafana
```

Expected core services:

- `ig-postgres` — healthy
- `ig-grafana` — running

Grafana is exposed on TCP port `3000` by the default Compose configuration.

## Validation status

The deployment procedure is being tested from clean VM snapshots rather than only from an already-prepared development machine.

Current validated baseline:

- Ubuntu Server 24.04.4 LTS
- Docker Engine 29.x installed successfully by `setup.sh`
- Docker Compose plugin 5.x installed successfully by `setup.sh`
- clean Git clone to `/opt/infraguardian`
- Docker daemon enabled and started by the bootstrap process

Further validation covers PostgreSQL initialization, Grafana provisioning, collector execution, persistence and reboot behavior.

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

The default Compose file publishes PostgreSQL and Grafana ports on the host. For production use, exposure should be restricted with host firewall rules, network segmentation or a reverse proxy as appropriate.

## Portfolio context

InfraGuardian represents the kind of work I focus on as an infrastructure engineer: **automation, observability, cross-platform operations and building systems that remain understandable when they need to be troubleshot under pressure**.

---

Built and maintained by [Julián Miconi](https://github.com/jmiconi).
