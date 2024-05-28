DROP TABLE IF EXISTS incident_messages;

DROP TABLE IF EXISTS incident_monitors;

DROP TABLE IF EXISTS incidents;

DROP TYPE IF EXISTS incident_status;

DELETE FROM schema_migrations WHERE version = '3';
