# InfraGuardian DevOps Workflow

Este documento describe la forma recomendada de trabajar en el proyecto.

------------------------------------------------------------------------

## Git Workflow

Ramas recomendadas:

    main
    feature/*
    fix/*

Ejemplo:

    feature/windows-collector
    feature/grafana-dashboard

------------------------------------------------------------------------

## Flujo de trabajo

1 Crear rama

    git checkout -b feature/nueva-feature

2 Desarrollar cambios

3 Commit

    git commit -m "Add feature"

4 Push

    git push origin feature/nueva-feature

5 Merge a main

------------------------------------------------------------------------

## Buenas prácticas

-   Nunca subir archivos `.env`
-   Usar `.example` para configuraciones
-   Documentar cambios importantes
-   Mantener commits pequeños

------------------------------------------------------------------------

## Roadmap técnico

InfraGuardian evolucionará hacia:

1 multi-host monitoring 2 alerting system 3 anomaly detection 4 AI
assisted infrastructure analytics