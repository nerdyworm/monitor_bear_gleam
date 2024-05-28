CREATE TYPE incident_status AS ENUM ('ongoing', 'resolved');

;;

CREATE TABLE incidents (
  id bigserial primary key not null,
  team_id bigint NOT NULL,
  status incident_status NOT NULL default 'ongoing',
  started_at timestamp(0) without time zone default (now() at time zone 'utc'),
  resolved_at timestamp(0) without time zone,
  description citext not null default '',
  tags text[] NOT NULL DEFAULT '{}',
  CONSTRAINT fk_incidents_team_id FOREIGN KEY (team_id) REFERENCES teams(id) ON DELETE CASCADE
)

;;

CREATE INDEX idx_incidents_on_team_id ON incidents(team_id);

;;

create table incident_messages (
  id bigserial primary key not null,
  incident_id bigint not null,
  data jsonb not null,
  inserted_at timestamp(0) without time zone default (now() at time zone 'utc'),
  CONSTRAINT fk_incident_messages_incident_id FOREIGN KEY (incident_id) REFERENCES incidents(id) ON DELETE CASCADE
)

;;

CREATE INDEX idx_incident_messages_incident_id ON incident_messages(incident_id)

;;

CREATE INDEX idx_incident_messages_inserted_at ON incident_messages(inserted_at DESC)

;;

create table incident_monitors (
  incident_id bigint not null,
  monitor_id bigint not null,
  PRIMARY KEY (incident_id, monitor_id),
  CONSTRAINT fk_incident_monitors_incident_id FOREIGN KEY (incident_id) REFERENCES incidents(id) ON DELETE CASCADE,
  CONSTRAINT fk_incident_monitors_monitor_id FOREIGN KEY (monitor_id) REFERENCES monitors(id) ON DELETE CASCADE
)

;;

CREATE INDEX idx_incident_monitors_monitor_id ON incident_monitors (monitor_id);

;;

CREATE INDEX idx_incident_id ON incident_monitors (incident_id);

