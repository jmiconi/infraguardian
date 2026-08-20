# Validation record

InfraGuardian is validated by following the public deployment procedure on a clean virtual machine rather than relying only on an existing development environment.

## Validation run 1

**Date:** 2026-08-20  
**Result:** PASS  
**Platform:** VMware virtual machine  
**Operating system:** Ubuntu Server 24.04.4 LTS (Noble)  
**Architecture:** x86_64  
**Docker Engine:** 29.7.2  
**Docker Compose:** v5.5.0

### Starting state

The VM was prepared as a reusable clean baseline with:

- Ubuntu Server installed
- working network connectivity
- OpenSSH available
- `git`, `curl` and `ca-certificates` installed
- no Docker installation
- no InfraGuardian checkout
- no previous PostgreSQL or Grafana state

### Validation sequence

| Test | Result |
|---|---|
| Clone repository into `/opt/infraguardian` | PASS |
| Run `setup.sh` on a host without Docker | PASS |
| Install Docker Engine | PASS |
| Install Docker Compose plugin | PASS |
| Run Docker as the test user after session refresh | PASS |
| Render `docker compose config` | PASS |
| Start PostgreSQL and Grafana | PASS |
| PostgreSQL health check reaches `healthy` | PASS |
| Database initialization scripts create schema | PASS |
| Grafana responds on TCP/3000 | PASS |
| PostgreSQL datasource provisioning | PASS |
| Dashboard provisioning | PASS |
| Create Python virtual environment | PASS |
| Install collector dependencies | PASS |
| Run Linux collector manually | PASS |
| Write host metrics to `system_metrics` | PASS |
| Run collector as a systemd service | PASS |
| Continue inserting metrics unattended | PASS |
| Reboot the VM | PASS |
| Docker starts automatically after reboot | PASS |
| PostgreSQL and Grafana recover automatically | PASS |
| Collector starts automatically after reboot | PASS |
| Existing metrics persist after reboot | PASS |
| New metrics continue after reboot | PASS |
| Provisioned Grafana dashboard displays live host metrics | PASS |

### End-to-end path demonstrated

```text
Linux host
   │
   ▼
Python / psutil collector
   │
   ▼
PostgreSQL system_metrics
   │
   ▼
Grafana provisioned datasource
   │
   ▼
InfraGuardian Host Overview dashboard
```

The dashboard displayed CPU, RAM, disk utilization, process count, network traffic and load-average data collected from the test host.

## Findings from the first clean installation

The validation run also exposed documentation and packaging details that were corrected in the repository:

1. The original quick start assumed Docker was already installed even though `setup.sh` provides the bootstrap path.
2. Adding the user to the Docker group requires a new login session before non-root Docker access works.
3. `collector/config.env.example` used a password example that did not match the root `.env.example` lab default.
4. Grafana logged missing optional `plugins` and `alerting` provisioning directories during startup.
5. The Linux collector installation and systemd deployment needed to be part of the reproducible quick-start path, not just represented elsewhere in the repository.
6. Reboot/persistence validation is now an explicit deployment test.

## Validation run 2 — README revalidation

**Date:** 2026-08-20  
**Result:** PASS  
**Method:** restore the clean Ubuntu snapshot and follow the published README procedure from scratch

### Revalidation results

| Test | Result |
|---|---|
| Clean snapshot contains no Docker installation | PASS |
| Clean snapshot contains no InfraGuardian checkout | PASS |
| Clone current `main` branch | PASS |
| Bootstrap Docker using documented `setup.sh` procedure | PASS |
| Docker and Compose work without `sudo` after reconnect | PASS |
| Copy `.env.example` and render Compose configuration | PASS |
| Start PostgreSQL and Grafana | PASS |
| Database schema contains `metrics` and `system_metrics` | PASS |
| Install collector dependencies using documented venv procedure | PASS |
| `collector/config.env.example` works with lab defaults | PASS |
| Manual collector writes metrics | PASS |
| systemd collector writes metrics unattended | PASS |
| Host reboot preserves database state | PASS |
| Docker restarts automatically | PASS |
| PostgreSQL recovers and becomes `healthy` | PASS |
| Grafana recovers automatically | PASS |
| Collector recovers automatically | PASS |
| Metrics continue increasing after reboot | PASS |

The post-reboot `system_metrics` row count increased from **7 to 9** without manual collector execution, confirming continued unattended collection after restart.

### Readiness finding

The second run identified an application-readiness race during both initial startup and reboot validation. `docker compose up -d` and an `Up` container state can occur before Grafana is ready to accept HTTP connections. An immediate request may therefore return a temporary connection reset even though the service is starting correctly.

The README was updated to wait for Grafana's `/login` endpoint before treating HTTP validation as complete:

```bash
until curl -fsS -o /dev/null http://localhost:3000/login; do
  echo "Waiting for Grafana..."
  sleep 2
done
```

The same readiness check is used after reboot. This removes timing assumptions from the documented validation path.

## Current validation status

**PASS — reproducible from a clean Ubuntu Server 24.04.4 LTS baseline.**

Two clean-VM runs demonstrated the complete Linux path from bootstrap through persisted metrics and Grafana visualization, including automatic recovery after a host reboot.

## Security note

The validation was performed as an isolated lab deployment. Example credentials are not production credentials. PostgreSQL TCP/5432 is published by the current Compose topology so host-based or remote collectors can connect; production deployments should restrict access with firewall rules or a narrower binding appropriate to the intended topology.

## Revalidation policy

Changes that affect bootstrap, Compose services, database initialization, collector dependencies, systemd integration or Grafana provisioning should be retested from the clean VM baseline.

A successful development environment is not considered sufficient evidence of reproducibility.
