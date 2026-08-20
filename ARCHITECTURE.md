# InfraGuardian Architecture

InfraGuardian separates **collection**, **persistence** and **visualization** so each layer can be operated and evolved independently.

## High-level design

```text
             Infrastructure hosts
        ┌────────────┴────────────┐
        │                         │
        ▼                         ▼
┌───────────────┐         ┌───────────────┐
│ Linux hosts   │         │ Windows hosts │
│ Python agent  │         │ PS/Python     │
└───────┬───────┘         └───────┬───────┘
        │                          │
        └────────────┬─────────────┘
                     │ metrics
                     ▼
              ┌─────────────┐
              │ PostgreSQL  │
              │ time-series │
              │  history    │
              └──────┬──────┘
                     │ queries
                     ▼
              ┌─────────────┐
              │   Grafana   │
              │ dashboards  │
              └─────────────┘
```

## 1. Collection layer

Collectors run close to the operating system being observed.

Typical host metrics include:

- CPU utilization
- RAM utilization
- filesystem/disk utilization
- process count
- network bytes sent and received
- hostname / node identity
- collection timestamp

Python collectors use `psutil` for portable system instrumentation. Windows deployment material also uses PowerShell so installation and service management can be automated without requiring manual setup on each endpoint.

### Design choice

Collectors are intentionally lightweight. They gather data and publish it to the persistence layer rather than embedding visualization or analysis logic in the endpoint.

This keeps agents easier to audit, troubleshoot and replace.

## 2. Persistence layer

PostgreSQL stores historical observations.

A typical metric record contains fields such as:

```text
hostname
cpu_percent
ram_percent
disk_percent
process_count
network_bytes_sent
network_bytes_recv
collected_at
```

Historical persistence enables questions that cannot be answered reliably from a current-state check alone, including:

- Is resource consumption trending upward?
- When did degradation begin?
- Is a problem isolated to one node?
- Does saturation recur at a particular time?

## 3. Visualization layer

Grafana reads the PostgreSQL data source and provides operational dashboards.

Representative panels include:

- CPU utilization
- memory utilization
- disk utilization
- process counts
- network traffic
- host-level comparisons

Provisioning material lives in the repository so dashboards and data-source configuration can be treated as infrastructure assets rather than only UI state.

## 4. Runtime and deployment

Docker Compose provides the reproducible platform runtime for central components.

Linux integration includes Bash/setup tooling and systemd material. Windows integration includes PowerShell-oriented deployment assets.

This allows the project to demonstrate both sides of an infrastructure environment:

- centralized platform deployment
- endpoint/host deployment and operation

## 5. Configuration and secrets

Configuration is externalized using environment/example files.

The public repository must never contain:

- real credentials
- private keys
- organization-specific internal DNS names
- production IP addressing
- proprietary configuration exports

Example values exist only to document the required configuration contract.

## 6. Failure domains

The architecture keeps failures relatively easy to isolate:

| Failure | Expected impact |
|---|---|
| Single collector stops | One host stops reporting; historical data remains available |
| Grafana unavailable | Collection/storage can continue |
| PostgreSQL unavailable | Collectors cannot persist new observations |
| Individual host offline | Other hosts continue reporting |

This separation is useful operationally because visualization availability is not the same thing as data collection availability.

## 7. Evolution path

The architecture is intentionally extensible. Natural additions include:

```text
Collectors
   │
   ▼
Storage ─────► Alert evaluation
   │               │
   │               ▼
   │          Notifications
   │
   ├──────────► Grafana
   │
   └──────────► Analysis layer
                    │
                    ├── anomaly detection
                    ├── capacity forecasting
                    └── AI-assisted diagnosis
```

Future integrations can therefore build on the historical data model without rewriting endpoint collection from scratch.