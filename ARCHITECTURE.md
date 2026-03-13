# InfraGuardian Architecture

InfraGuardian utiliza una arquitectura simple orientada a
observabilidad.

## Componentes principales

### Collector

Script en Python que recolecta métricas del sistema:

-   CPU
-   RAM
-   Disco
-   Procesos
-   Network

Utiliza la librería:

    psutil

El collector envía métricas periódicamente a PostgreSQL.

------------------------------------------------------------------------

### PostgreSQL

Base de datos donde se almacenan las métricas históricas.

Tabla principal:

    system_metrics

Campos principales:

-   hostname
-   cpu_percent
-   ram_percent
-   disk_percent
-   process_count
-   network_bytes_sent
-   network_bytes_recv

------------------------------------------------------------------------

### Grafana

Grafana se conecta a PostgreSQL y genera dashboards para visualizar
métricas.

Paneles actuales:

-   CPU usage
-   RAM usage
-   Disk usage
-   Processes
-   Network traffic

------------------------------------------------------------------------

## Flujo de datos

    Host
     ↓
    Python Collector
     ↓
    PostgreSQL
     ↓
    Grafana

------------------------------------------------------------------------

## Diseño futuro

InfraGuardian planea agregar:

-   soporte multi-host
-   análisis predictivo
-   alertas automáticas
-   motor de análisis con IA