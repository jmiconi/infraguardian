# InfraGuardian -- DevOps Observability Platform

![Platform](https://img.shields.io/badge/platform-linux%20%7C%20windows-blue)
![Stack](https://img.shields.io/badge/stack-docker%20%7C%20postgres%20%7C%20grafana-orange)
![Collectors](https://img.shields.io/badge/collectors-python%20%7C%20powershell-green)
![Status](https://img.shields.io/badge/status-active%20development-yellow)

InfraGuardian is a lightweight **observability platform for on‑prem
infrastructure** built with a **DevOps / SRE mindset**.

It provides:

• Centralized infrastructure metrics\
• Cross‑platform collectors (Linux + Windows)\
• Historical metrics storage\
• Grafana dashboards\
• A foundation for **future AI‑assisted infrastructure analysis**

InfraGuardian began as a DevOps learning lab and is evolving into a
**practical observability platform for real on‑prem environments**.

------------------------------------------------------------------------

# Architecture

InfraGuardian uses a **centralized metrics ingestion model**.

Linux hosts run a **Python collector**, while Windows hosts run a
**PowerShell collector**.

Both send metrics to a **central PostgreSQL database**, which feeds
**Grafana dashboards**.

    Linux Host
       ↓
    Python Collector
       ↓
    PostgreSQL
       ↓
    Grafana Dashboards

    Windows Host
       ↓
    PowerShell Collector
       ↓
    PostgreSQL
       ↓
    Grafana Dashboards

Benefits of this architecture:

• Multi‑host observability\
• Centralized metrics storage\
• Historical analysis\
• Unified dashboards

------------------------------------------------------------------------

# Technology Stack

InfraGuardian intentionally uses **simple, robust technologies**.

  Component            Technology
  -------------------- --------------------------------------
  Collectors           Python (Linux), PowerShell (Windows)
  Database             PostgreSQL
  Visualization        Grafana
  Infrastructure       Docker
  Service Management   systemd
  Windows Scheduling   Task Scheduler
  Version Control      Git / GitHub

This design keeps the platform:

• simple to deploy\
• easy to debug\
• easy to extend

------------------------------------------------------------------------

# Collected Metrics

InfraGuardian currently collects:

  Metric            Description
  ----------------- -------------------------------
  CPU usage         CPU utilization percentage
  RAM usage         Memory utilization percentage
  Disk usage        Disk utilization percentage
  Process count     Number of running processes
  Network traffic   Bytes sent / received
  Load average      Linux system load averages

## Linux Specific Metrics

Linux collectors expose:

    load_1
    load_5
    load_15

## Windows Behavior

Windows does not expose load average, therefore these values are stored
as:

    NULL

------------------------------------------------------------------------

# Repository Structure

    /opt/infraguardian

    collector/
        collector.py
        requirements.txt
        config.env

    windows/
        collector/
            collector.ps1
            config.env
        install_collector.ps1

    scripts/
        install_collector.sh

    systemd/
        infraguardian-collector.service

    grafana/
        dashboards/
        provisioning/

    db/init/
        002_system_metrics.sql

    docker-compose.yml

------------------------------------------------------------------------

# Quick Start

Clone the repository:

    git clone https://github.com/jmiconi/infraguardian.git
    cd infraguardian

------------------------------------------------------------------------

# Linux Installation

Run the installer:

    ./scripts/install_collector.sh

The installer will:

• create Python virtual environment\
• install dependencies\
• configure the collector\
• register systemd service\
• start the collector automatically

Default collection interval:

    30 seconds

------------------------------------------------------------------------

# Windows Collector

The Windows collector is implemented in **PowerShell**.

It gathers system metrics and inserts them into PostgreSQL using the
**psql command‑line client**.

------------------------------------------------------------------------

# Windows Requirements

Before installing the collector you must install:

## PostgreSQL Client Tools

Download from:

https://www.postgresql.org/download/windows/

During installation ensure the following component is selected:

    Command Line Tools

Typical installation path:

    C:\Program Files\PostgreSQL\<version>\bin\psql.exe

The InfraGuardian installer attempts to **automatically detect this
path**.

------------------------------------------------------------------------

# Windows Installation

Run the installer:

    powershell -ExecutionPolicy Bypass -File install_collector.ps1

The installer performs:

• installation directory creation\
• collector file deployment\
• PostgreSQL client detection\
• collector test execution\
• scheduled task creation\
• automatic collector startup

------------------------------------------------------------------------

# Windows Collector Schedule

Collectors run via **Windows Task Scheduler**.

Default schedule:

    Every 1 minute

------------------------------------------------------------------------

# Verifying Installation

Verify scheduled task:

    schtasks /Query /TN "InfraGuardian Collector" /V /FO LIST

Expected result:

    Last Result: 0

------------------------------------------------------------------------

# Verifying Metrics

Confirm data ingestion in PostgreSQL:

    SELECT hostname, collected_at
    FROM system_metrics
    ORDER BY collected_at DESC
    LIMIT 10;

------------------------------------------------------------------------

# Grafana Dashboards

Grafana dashboards are **automatically provisioned**.

Current dashboards include:

• CPU usage\
• RAM utilization\
• Disk utilization\
• Network traffic\
• System load

------------------------------------------------------------------------

# Security

Configuration files containing credentials:

    config.env

must **never be committed to Git**.

Instead use:

    config.env.example

and ignore local configuration using:

    .gitignore

------------------------------------------------------------------------

# Troubleshooting

## Collector not inserting metrics

Verify PostgreSQL client installation:

    where psql

or check typical location:

    C:\Program Files\PostgreSQL\<version>\bin\psql.exe

------------------------------------------------------------------------

## Check scheduled task

    schtasks /Query /TN "InfraGuardian Collector" /V /FO LIST

------------------------------------------------------------------------

## Run collector manually

    powershell -ExecutionPolicy Bypass -File C:\InfraGuardian\collector\collector.ps1

------------------------------------------------------------------------

# Roadmap

InfraGuardian is designed to evolve into a **full observability
platform**.

## Device Inventory

Future table:

    devices

Allowing:

• host metadata\
• environment grouping\
• infrastructure roles

------------------------------------------------------------------------

## Disk Observability

Filesystem level metrics:

• mountpoints\
• disk capacity\
• saturation trends

------------------------------------------------------------------------

## Network Observability

Derived metrics:

• Mbps throughput\
• network saturation

------------------------------------------------------------------------

## Predictive Infrastructure Analytics

Long‑term objective:

Apply **AI models** to infrastructure metrics to detect:

• abnormal resource behavior\
• capacity risks\
• infrastructure growth trends

------------------------------------------------------------------------

# Project Status

InfraGuardian is currently in **active development**.

Current capabilities:

✔ Linux collector\
✔ Windows collector\
✔ PostgreSQL ingestion\
✔ Grafana dashboards\
✔ Automated installers