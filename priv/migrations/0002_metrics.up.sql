CREATE EXTENSION IF NOT EXISTS timescaledb;

;;

create table monitor_metrics (
  monitor_id bigint not null,
  name text not null,
  t timestamptz not null DEFAULT now(),
  value numeric not null,
  CONSTRAINT fk_monitor_flips_monitor_id FOREIGN KEY (monitor_id) REFERENCES monitors(id) ON DELETE CASCADE
)

;;

SELECT create_hypertable('monitor_metrics', by_range('t', INTERVAL '1 hour'));

;;


CREATE INDEX idx_monitor_metrics ON monitor_metrics(monitor_id, name, t DESC)

;;

SELECT add_retention_policy('monitor_metrics', INTERVAL '6 hours');

;;

CREATE MATERIALIZED VIEW monitor_metrics_5min
WITH (timescaledb.continuous) AS
SELECT monitor_id,
       name,
       time_bucket('5 minute', t) AS bucket,
       AVG(value) AS value
FROM monitor_metrics
GROUP BY monitor_id, name, bucket;

;;

SELECT add_retention_policy('monitor_metrics_5min', INTERVAL '5 days');

;;

SELECT add_continuous_aggregate_policy('monitor_metrics_5min',
  start_offset => INTERVAL '15 minutes',
  end_offset => INTERVAL '0 seconds',
  schedule_interval => INTERVAL '5 minutes');


CREATE INDEX idx_monitor_metrics_5min ON monitor_metrics(monitor_id, name, t DESC)

;;

CREATE MATERIALIZED VIEW monitor_metrics_hourly
WITH (timescaledb.continuous) AS
SELECT monitor_id,
       name,
       time_bucket('1 hour', t) AS bucket,
       AVG(value) AS value
FROM monitor_metrics
GROUP BY monitor_id, name, bucket;

;;

SELECT add_retention_policy('monitor_metrics_hourly', INTERVAL '1 year');

;;

SELECT add_continuous_aggregate_policy('monitor_metrics_hourly',
    start_offset => INTERVAL '4 hours',
    end_offset => INTERVAL '0 seconds',
    schedule_interval => INTERVAL '1 hour');

;;

CREATE INDEX idx_monitor_metrics_hourly ON monitor_metrics(monitor_id, name, t DESC)
