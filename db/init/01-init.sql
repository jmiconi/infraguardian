-- InfraGuardian DB initialization
-- Este script se ejecuta automáticamente
-- cuando PostgreSQL crea la base por primera vez

CREATE TABLE metrics (

    id SERIAL PRIMARY KEY,

    timestamp TIMESTAMP NOT NULL,

    device TEXT NOT NULL,

    sensor TEXT NOT NULL,

    value FLOAT,

    status TEXT

);
