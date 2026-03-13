# InfraGuardian Collectors

InfraGuardian utiliza collectors para recolectar métricas de hosts.

Actualmente existen dos implementaciones.

------------------------------------------------------------------------

## Linux Collector

Ubicación:

    collector/

Características:

-   Python
-   psutil
-   ejecución como servicio
-   envío periódico a PostgreSQL

Intervalo configurable mediante:

    COLLECTOR_INTERVAL

------------------------------------------------------------------------

## Windows Collector

Ubicación:

    windows/v2-python/

Características:

-   Python
-   psutil
-   deploy simple en Windows
-   script PowerShell de instalación

------------------------------------------------------------------------

## Configuración

Los collectors utilizan archivos:

    config.env

Pero en el repositorio solo se incluye:

    config.env.example

Para configurar:

    cp config.env.example config.env

Editar con tus parámetros de base de datos.

------------------------------------------------------------------------

## Variables principales

    POSTGRES_HOST
    POSTGRES_PORT
    POSTGRES_DB
    POSTGRES_USER
    POSTGRES_PASSWORD
    COLLECTOR_INTERVAL

------------------------------------------------------------------------

## Objetivo

Permitir monitorear múltiples hosts enviando métricas a un servidor
central InfraGuardian.