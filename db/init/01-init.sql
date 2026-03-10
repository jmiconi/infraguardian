-- InfraGuardian database initialization
-- This script runs automatically when PostgreSQL
-- initializes the database for the first time.

-- The metrics table stores all collected telemetry.
-- Each row represents a single metric sample from a device.

CREATE TABLE metrics (

    id SERIAL PRIMARY KEY,

    timestamp TIMESTAMP NOT NULL,

    device TEXT NOT NULL,

    sensor TEXT NOT NULL,

    value FLOAT,

    status TEXT

);
