CREATE TABLE fox_jobs (
  id bigserial primary key not null,
  state text not null default 'available',
  queue text not null,
  worker text not null,
  args jsonb not null default '{}'::jsonb,
  errors jsonb not null default '[]'::jsonb,
  attempt integer not null default 0,
  max_attempts integer not null default 10,
  inserted_at timestamp without time zone not null default (now() at time zone 'utc'),
  scheduled_at timestamp without time zone not null default (now() at time zone 'utc'),
  completed_at timestamp without time zone
);


;;

create index idx_fox_jobs ON fox_jobs(state, queue, scheduled_at, id)


