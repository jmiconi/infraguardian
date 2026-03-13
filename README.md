# InfraGuardian

InfraGuardian es una plataforma de **observabilidad para infraestructura
on‑premise** diseñada como proyecto de aprendizaje DevOps/SRE y como
base para un sistema real de monitoreo.

El objetivo es construir una solución simple, portable y extensible que
permita:

-   Monitorear múltiples hosts
-   Analizar métricas históricas
-   Detectar saturación de recursos
-   Servir como base para análisis con IA

------------------------------------------------------------------------

## Stack

-   Docker
-   Docker Compose
-   PostgreSQL
-   Grafana
-   Python
-   Bash
-   Windows PowerShell (para deploy en Windows)

------------------------------------------------------------------------

## Arquitectura

InfraGuardian sigue un modelo simple de **collector → base de datos →
visualización**.

Host Metrics\
↓\
Python Collector\
↓\
PostgreSQL\
↓\
Grafana Dashboards

Los collectors se ejecutan en cada host y envían métricas periódicamente
a PostgreSQL.

Grafana consulta PostgreSQL para generar dashboards.

------------------------------------------------------------------------

## Estructura del repositorio

    infraguardian
    │
    ├ collector
    │   ├ collector.py
    │   ├ requirements.txt
    │   └ config.env.example
    │
    ├ windows
    │   └ v2-python
    │       ├ collector.py
    │       ├ requirements.txt
    │       ├ config.env.example
    │       └ install_collector.ps1
    │
    ├ db
    │   └ init
    │
    ├ grafana
    │   ├ dashboards
    │   └ provisioning
    │
    ├ docker-compose.yml
    └ README.md

------------------------------------------------------------------------

## Deploy rápido

### 1 Clonar repositorio

    git clone https://github.com/jmiconi/infraguardian.git
    cd infraguardian

### 2 Configurar variables

    cp collector/config.env.example collector/config.env

Editar con tus valores.

------------------------------------------------------------------------

### 3 Levantar stack

    docker compose up -d

------------------------------------------------------------------------

### 4 Acceder a Grafana

    http://localhost:3000

------------------------------------------------------------------------

## Objetivos del proyecto

InfraGuardian busca evolucionar hacia:

-   monitoreo multi‑host
-   análisis histórico de infraestructura
-   detección automática de anomalías
-   predicción de saturación mediante IA

------------------------------------------------------------------------

## Estado actual

Versión estable:

    v0.x – Observabilidad básica

Incluye:

-   collector Linux
-   collector Windows
-   PostgreSQL
-   Grafana dashboards

------------------------------------------------------------------------

## Autor

Proyecto desarrollado por **InfraGuardian**