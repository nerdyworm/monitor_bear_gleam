CREATE EXTENSION IF NOT EXISTS citext;

;;


create table users (
  id bigserial primary key not null,
  email citext not null,
  hashed_password text
)

;;

CREATE UNIQUE INDEX idx_users_email ON users(email)

;;


CREATE TABLE user_tokens (
    id          bigserial not null primary key,
    user_id     BIGINT NOT NULL,
    token       TEXT NOT NULL,
    context     CHARACTER VARYING(255) NOT NULL,
    sent_to     CHARACTER VARYING(255),
    inserted_at TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT now(),
    CONSTRAINT fk_user_tokens_user_id FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
)
;;

CREATE UNIQUE INDEX users_tokens_context_token_index ON user_tokens (context, token);

;;

CREATE INDEX users_tokens_user_id_index ON user_tokens (user_id);

;;

create table teams (
  id bigserial primary key not null,
  name citext not null,
  plan text not null default 'free',
  limits_monitors_count int not null default 3,
  limits_monitors_interval text not null default '5 minutes',
  limits_monitors_messages int not null default 20
)

;;

CREATE TABLE memberships (
  user_id bigint NOT NULL,
  team_id bigint NOT NULL,
  role text NOT NULL DEFAULT 'user',
  tags text[] NOT NULL DEFAULT '{}',
  CONSTRAINT pk_memberships PRIMARY KEY (user_id, team_id),
  CONSTRAINT fk_memberships_user_id FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT fk_memberships_team_id FOREIGN KEY (team_id) REFERENCES teams(id) ON DELETE CASCADE
)

;;

CREATE INDEX idx_memberships_on_team_id ON memberships(team_id);

;;


create table monitors(
  id bigserial primary key not null,
  team_id bigint not null,
  name text not null,
  tags text[] not null default '{}',
  kind text not null default 'healthcheck',
  config_interval text not null default '3 minutes',
  config_url text not null default '',
  config_regions text[] not null default '{}',
  config_assertions jsonb not null default '[]',
  config_tolerance integer not null default 3,
  config_recovery integer not null default 0,
  config_request_method text not null default 'get',
  config_request_headers jsonb not null default '[]',
  config_request_body text not null default '',
  config_request_timeout integer not null default 5000,
  CONSTRAINT fk_monitor_team_id FOREIGN KEY (team_id) REFERENCES teams(id) ON DELETE CASCADE
)

;;

create table monitor_states(
  monitor_id bigint primary key not null,
  status text not null default 'new',
  missed bigint not null default 0,
  recovered int not null default 0,
  events bigint not null default 0,
  checking bool not null default false,
  next_check_at timestamp(0) without time zone,
  next_region text,
  metrics_last_success_at timestamp(0) without time zone,
  metrics_last_error_at timestamp(0) without time zone,
  metrics_last_runtime_ms int,
  metrics_runtimes int[] not null default '{0, 0, 0, 0, 0, 0, 0, 0, 0, 0}',
  CONSTRAINT fk_monitor_states_monitor_id FOREIGN KEY (monitor_id) REFERENCES monitors(id) ON DELETE CASCADE
)

;;

CREATE INDEX idx_monitor_states_next_check_at ON monitor_states(checking, next_check_at)

;;

create table monitor_messages(
  id bigserial primary key not null,
  monitor_id bigint not null,
  data jsonb not null,
  inserted_at timestamp(0) without time zone default (now() at time zone 'utc'),
  CONSTRAINT fk_monitor_messages_monitor_id FOREIGN KEY (monitor_id) REFERENCES monitors(id) ON DELETE CASCADE
)
;;
CREATE INDEX idx_monitor_logs_monitor_id ON monitor_messages(monitor_id)
;;

create table monitor_flips(
  id bigserial primary key not null,
  monitor_id bigint not null,
  "from" text not null,
  "to" text not null,
  inserted_at timestamp(0) without time zone default now(),
  CONSTRAINT fk_monitor_flips_monitor_id FOREIGN KEY (monitor_id) REFERENCES monitors(id) ON DELETE CASCADE
)
;;
CREATE INDEX idx_monitor_flips_monitor_id ON monitor_flips(monitor_id)
;;

create table alerts (
  id bigserial primary key not null,
  team_id bigint not null,
  name text not null,
  enabled boolean not null default true,
  triggers jsonb not null,
  filters jsonb not null,
  actions jsonb not null,
  last_triggered_at TIMESTAMP WITHOUT TIME ZONE,
  inserted_at TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT now(),
  CONSTRAINT fk_alerts_team_id FOREIGN KEY (team_id) REFERENCES teams(id) ON DELETE CASCADE
)
;;
CREATE INDEX idx_alerts_team_id ON alerts(team_id)
;;
