# fox

[![Package Version](https://img.shields.io/hexpm/v/fox)](https://hex.pm/packages/fox)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/fox/)

```sh
gleam add fox
```

```gleam
import fox

pub fn main() {
  let queue =
    fox.new("default", your_pgo_connection)
    |> fox.register("name", fn(args) {
      io.debug(args)
      fox.ack()
    })

  let assert Ok(_) =
    queue
    |> fox.start_link()

  fox.push(queue, "name", "args here")
}
```

Further documentation can be found at <https://hexdocs.pm/fox>.

## Development

```sh
gleam run   # Run the project
gleam test  # Run the tests
gleam shell # Run an Erlang shell
```

```sql
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

create index idx_fox_jobs ON fox_jobs(state, queue, scheduled_at, id);
```
