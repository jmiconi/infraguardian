CREATE TABLE IF NOT EXISTS system_metrics (
    id BIGSERIAL PRIMARY KEY,
    collected_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    hostname TEXT NOT NULL,
    role TEXT NOT NULL,
    environment TEXT NOT NULL,
    cpu_percent DOUBLE PRECISION NOT NULL,
    ram_percent DOUBLE PRECISION NOT NULL,
    disk_percent DOUBLE PRECISION NOT NULL,
    process_count INTEGER NOT NULL,
    load_1 DOUBLE PRECISION,
    load_5 DOUBLE PRECISION,
    load_15 DOUBLE PRECISION,
    network_bytes_sent BIGINT,
    network_bytes_recv BIGINT
);

CREATE INDEX IF NOT EXISTS idx_system_metrics_collected_at
    ON system_metrics (collected_at);

CREATE INDEX IF NOT EXISTS idx_system_metrics_hostname
    ON system_metrics (hostname);

CREATE INDEX IF NOT EXISTS idx_system_metrics_hostname_collected_at
    ON system_metrics (hostname, collected_at);
