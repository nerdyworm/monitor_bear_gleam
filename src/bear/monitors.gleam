import bear/error.{type BearError, Validation}
import bear/monitors/assertion
import bear/monitors/config.{Config}
import bear/monitors/flip.{type Flip, Flip}
import bear/monitors/message.{type Message}
import bear/monitors/metric.{type Metric, Metric}
import bear/monitors/metrics.{type Metrics, Metrics}
import bear/monitors/monitor.{type Monitor, Monitor}
import bear/monitors/report.{type Report}
import bear/monitors/state.{type State, State}
import bear/monitors/status.{type Status, Down, New, Up}
import bear/pubsub_message
import bear/scope.{type Scope}
import bear/tags
import bear_server/lib/db
import bear_server/lib/pubsub
import gleam/dynamic
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/pgo
import gleam/result
import gleam/string
import validates

pub fn ensure_create_limits(
  scope: Scope,
  monitor: Monitor,
) -> Result(Monitor, BearError) {
  use monitor <- result.try(ensure_update_limits(scope, monitor))
  let count = count_monitors(scope)

  validates.rules()
  |> validates.add(
    validates.int("team.limits.monitors", count + 1)
    |> validates.required()
    |> validates.range(0, scope.team.limits.monitors),
  )
  |> validates.result_map_error(monitor, Validation)
}

pub fn ensure_update_limits(
  scope: Scope,
  monitor: Monitor,
) -> Result(Monitor, BearError) {
  let intervals = config.intervals_for_team(scope.team)

  validates.rules()
  |> validates.add(
    validates.string("config.interval", monitor.config.interval)
    |> validates.required()
    |> validates.in(intervals),
  )
  |> validates.result_map_error(monitor, Validation)
}

pub fn count_monitors(scope: Scope) {
  let assert Ok(count) =
    db.one(
      "SELECT count(*) FROM monitors WHERE team_id = $1",
      [pgo.int(scope.team.id)],
      dynamic.element(0, dynamic.int),
    )

  count
}

pub fn delete_monitor(monitor: Monitor) {
  db.execute(
    "DELETE FROM monitors WHERE id = $1",
    [pgo.int(monitor.id)],
    dynamic.dynamic,
  )
}

pub fn update_monitor(scope: Scope, monitor: Monitor, params: Monitor) {
  use params <- result.try(monitor.validate(params))
  use params <- result.try(ensure_update_limits(scope, params))

  let assert Ok(updated) =
    db.one(
      "UPDATE monitors SET name = $2, kind = $3, config_interval = $4, config_url = $5, config_regions = $6, config_assertions = $7, tags = $8, config_tolerance = $9, config_recovery = $10,
       config_request_method = $11,
       config_request_headers = $12,
       config_request_body = $13,
       config_request_timeout = $14 WHERE id = $1 RETURNING "
        <> monitor_columns,
      [
        pgo.int(monitor.id),
        pgo.text(params.name),
        pgo.text(monitor.kind_to_string(params.kind)),
        pgo.text(params.config.interval),
        pgo.text(params.config.url),
        pgo.text_array(params.config.regions),
        pgo.text(
          json.array(params.config.assertions, assertion.to_json)
          |> json.to_string(),
        ),
        pgo.text_array(tags.trim(params.tags)),
        pgo.int(params.config.tolerance),
        pgo.int(params.config.recovery),
        pgo.text(params.config.request.method),
        pgo.text(
          json.array(params.config.request.headers, config.header_to_json)
          |> json.to_string(),
        ),
        pgo.text(params.config.request.body),
        pgo.int(params.config.request.timeout),
      ],
      monitor_decoder,
    )

  case monitor.config == updated.config {
    True -> Nil
    False -> {
      let _ =
        create_message(
          monitor,
          message.Configured(
            monitor.config,
            params.config,
            scope.user.id,
            scope.user.email,
          ),
        )

      let assert Ok(state) = configured(updated)

      pubsub_message.MonitorState(state)
      |> pubsub_message.to_json()
      |> json.to_string()
      |> broadcast(monitor)
    }
  }

  Ok(updated)
}

pub fn create_monitor(scope: Scope, monitor: Monitor) {
  use monitor <- result.try(monitor.validate(monitor))
  use monitor <- result.try(ensure_create_limits(scope, monitor))
  use <- db.transaction()

  let assert Ok(monitor) =
    db.one(
      "INSERT INTO monitors (team_id, name, kind, config_interval, config_url, config_regions, config_assertions, config_request_method, config_request_headers, config_request_body, config_request_timeout) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11) RETURNING "
        <> monitor_columns,
      [
        pgo.int(scope.team.id),
        pgo.text(monitor.name),
        pgo.text(monitor.kind_to_string(monitor.kind)),
        pgo.text(monitor.config.interval),
        pgo.text(monitor.config.url),
        pgo.text_array(monitor.config.regions),
        pgo.text(
          json.array(monitor.config.assertions, assertion.to_json)
          |> json.to_string(),
        ),
        pgo.text(monitor.config.request.method),
        pgo.text(
          json.array(monitor.config.request.headers, config.header_to_json)
          |> json.to_string(),
        ),
        pgo.text(monitor.config.request.body),
        pgo.int(monitor.config.request.timeout),
      ],
      monitor_decoder,
    )

  let assert Ok(_) =
    db.one(
      "INSERT INTO monitor_states (monitor_id) VALUES ($1) RETURNING "
        <> monitor_state_columns,
      [pgo.int(monitor.id)],
      state_decoder,
    )

  Ok(monitor)
}

pub fn get_monitor(scope: Scope, id: Int) {
  db.one(
    "SELECT "
      <> monitor_columns
      <> " FROM monitors WHERE id = $1 AND team_id = $2",
    [pgo.int(id), pgo.int(scope.team.id)],
    monitor_decoder,
  )
}

pub fn get_monitor_bang(id: Int) {
  db.one(
    "SELECT " <> monitor_columns <> " FROM monitors WHERE id = $1",
    [pgo.int(id)],
    monitor_decoder,
  )
}

pub fn create_message(monitor: Monitor, message: Message) {
  let assert Ok(record) =
    db.one(
      "INSERT INTO monitor_messages (monitor_id, data) VALUES ($1, $2) RETURNING id, monitor_id, data, inserted_at::text",
      [
        pgo.int(monitor.id),
        pgo.text(
          message.to_json(message)
          |> json.to_string,
        ),
      ],
      message_record_decoder,
    )
  pubsub_message.MonitorMessageRecord(record)
  |> pubsub_message.to_json()
  |> json.to_string()
  |> broadcast(monitor)

  Ok(message)
}

pub fn list_messages(monitor: Monitor) {
  db.execute(
    "SELECT id, monitor_id, data, inserted_at::text FROM monitor_messages WHERE monitor_id = $1 ORDER BY id desc
     LIMIT (SELECT limits_monitors_messages FROM teams WHERE teams.id = (SELECT monitors.team_id FROM monitors WHERE id = $1))",
    [pgo.int(monitor.id)],
    message_record_decoder,
  )
}

pub fn list_recent_messages(monitor: Monitor) {
  db.all(
    "SELECT id, monitor_id, data, inserted_at::text FROM monitor_messages WHERE monitor_id = $1 ORDER BY id desc LIMIT 10",
    [pgo.int(monitor.id)],
    message_record_decoder,
  )
}

pub fn list(scope: Scope) {
  db.execute(
    "SELECT " <> monitor_columns <> " FROM monitors WHERE team_id = $1",
    [pgo.int(scope.team.id)],
    monitor_decoder,
  )
}

pub fn list_monitors_by_states(states: List(State)) {
  let ids =
    states
    |> list.map(fn(state: State) { state.id })
    |> list.map(fn(id: Int) { int.to_string(id) })
    |> string.join(",")

  db.execute(
    "SELECT "
      <> monitor_columns
      <> " FROM monitors WHERE id = ANY(string_to_array($1, ',')::int[])",
    [pgo.text(ids)],
    monitor_decoder,
  )
}

pub fn list_states(scope: Scope) {
  db.execute(
    "SELECT "
      <> monitor_state_columns
      <> " FROM monitor_states JOIN monitors ON monitor_states.monitor_id = monitors.id WHERE monitors.team_id = $1",
    [pgo.int(scope.team.id)],
    state_decoder,
  )
}

pub fn list_states_by_ids(ids: List(Int)) {
  db.all(
    "SELECT "
      <> monitor_state_columns
      <> " FROM monitor_states WHERE monitor_id = ANY($1)",
    [pgo.array(ids, pgo.int)],
    state_decoder,
  )
}

pub fn get_state(monitor: Monitor) {
  db.one(
    "SELECT "
      <> monitor_state_columns
      <> " FROM monitor_states WHERE monitor_id = $1",
    [pgo.int(monitor.id)],
    state_decoder,
  )
}

pub fn get_state_by_id(id: Int) {
  db.one(
    "SELECT "
      <> monitor_state_columns
      <> " FROM monitor_states WHERE monitor_id = $1",
    [pgo.int(id)],
    state_decoder,
  )
}

pub fn maybe_prune(state: State) {
  case state.events % 50 == 0 {
    True -> prune(state)
    False -> Ok(0)
  }
}

fn prune(state: State) {
  db.execute(
    "
    DELETE FROM monitor_messages
      WHERE monitor_messages.monitor_id = $1 AND id < (
        SELECT id FROM monitor_messages WHERE monitor_messages.monitor_id = $1
        ORDER BY id DESC OFFSET (
          SELECT teams.limits_monitors_messages FROM teams WHERE teams.id = (SELECT team_id from monitors where id = $1)
        )
        LIMIT 1

    );
    ",
    [pgo.int(state.id)],
    dynamic.dynamic,
  )
  |> result.map(fn(rows) { rows.count })
}

fn get_next_region(monitor: Monitor, state: State) {
  next_region(monitor.config.regions, state.next_region)
}

pub fn next_region(regions: List(String), next: Option(String)) {
  let result = case next {
    None -> list.first(regions)

    Some(region) -> {
      let index =
        regions
        |> list.index_fold(-1, fn(acc, r, index) {
          case region == r {
            True -> index
            False -> acc
          }
        })

      case index + 1 >= list.length(regions) {
        True -> list.first(regions)
        False -> {
          list.index_fold(regions, Error(Nil), fn(acc, r, i) {
            case i == index + 1 {
              True -> Ok(r)
              False -> acc
            }
          })
        }
      }
    }
  }

  case result {
    Ok(region) -> Some(region)
    Error(Nil) -> None
  }
}

fn configured(monitor: Monitor) {
  db.one("
    UPDATE monitor_states SET
    checking = false,
    next_check_at = now() at time zone 'utc' + ($2::text)::interval,
    next_region = $3
    WHERE monitor_id = $1
    RETURNING " <> monitor_state_columns, [
    pgo.int(monitor.id),
    pgo.text(monitor.config.interval),
    pgo.nullable(pgo.text, next_region(monitor.config.regions, None)),
  ], state_decoder)
}

pub fn ok(report: Report, monitor: Monitor, state: State) {
  let #(status, recovered) = recover(monitor, state)

  db.one("
    UPDATE monitor_states SET
    status = $2, missed = '0', events = events + 1,
    checking = false,
    next_check_at = now() at time zone 'utc' + ($3::text)::interval,
    metrics_last_success_at = now() at time zone 'utc',
    metrics_last_runtime_ms = $4,
    metrics_runtimes = array_cat(metrics_runtimes[2:10], ARRAY[$4::int]),
    next_region = $5,
    recovered = $6
    WHERE monitor_id = $1
    RETURNING " <> monitor_state_columns, [
    pgo.int(monitor.id),
    pgo.text(status.to_string(status)),
    pgo.text(monitor.config.interval),
    pgo.int(report.runtime),
    pgo.nullable(pgo.text, get_next_region(monitor, state)),
    pgo.int(recovered),
  ], state_decoder)
}

fn recover(monitor: Monitor, state: State) {
  case state.status, state.recovered + 1 > monitor.config.recovery {
    Down, True -> #(Up, 0)
    Down, False -> #(Down, state.recovered + 1)
    New, _ -> #(Up, 0)
    _, _ -> #(state.status, 0)
  }
}

pub fn missed(report: Report, monitor: Monitor, state: State) {
  let status = case state.missed + 1 > monitor.config.tolerance {
    True -> status.Down
    False -> state.status
  }

  // next_check_at = now() at time zone 'utc' + ($3::text)::interval + (interval '1 second' * (1 + (random() * 5)::integer)),
  db.one("
    UPDATE monitor_states SET status = $2, missed = missed + 1, events = events + 1,
    checking = false, recovered = '0',
    next_check_at = now() at time zone 'utc' + ($3::text)::interval,
    metrics_last_error_at = now() at time zone 'utc',
    metrics_last_runtime_ms = $4,
    metrics_runtimes = array_cat(metrics_runtimes[2:10], ARRAY[$4::int]),
    next_region = $5
    WHERE monitor_id = $1
    RETURNING " <> monitor_state_columns, [
    pgo.int(monitor.id),
    pgo.text(status.to_string(status)),
    pgo.text(monitor.config.interval),
    pgo.int(report.runtime),
    pgo.nullable(pgo.text, get_next_region(monitor, state)),
  ], state_decoder)
}

const monitor_columns = "
  monitors.id,
  monitors.team_id,
  monitors.name,
  monitors.kind,
  monitors.tags,
  monitors.config_interval,
  monitors.config_url,
  monitors.config_regions,
  monitors.config_assertions,
  monitors.config_tolerance,
  monitors.config_recovery,
  monitors.config_request_method,
  monitors.config_request_headers,
  monitors.config_request_body,
  monitors.config_request_timeout
  "

fn monitor_decoder(dynamic) {
  dynamic.decode6(
    Monitor,
    dynamic.element(0, dynamic.int),
    dynamic.element(1, dynamic.int),
    dynamic.element(2, dynamic.string),
    dynamic.element(3, monitor.kind_decoder),
    dynamic.element(4, dynamic.list(dynamic.string)),
    dynamic.decode7(
      Config,
      dynamic.element(5, dynamic.string),
      dynamic.element(6, dynamic.string),
      dynamic.element(7, dynamic.list(dynamic.string)),
      dynamic.element(8, fn(dynamic) {
        case dynamic.string(dynamic) {
          Error(error) -> Error(error)
          Ok(string) -> {
            let assert Ok(json) = json.decode(string, dynamic.dynamic)
            dynamic.list(assertion.decoder)(json)
          }
        }
      }),
      dynamic.element(9, dynamic.int),
      dynamic.element(10, dynamic.int),
      dynamic.decode4(
        config.Request,
        dynamic.element(11, dynamic.string),
        dynamic.element(12, fn(dynamic) {
          case dynamic.string(dynamic) {
            Error(error) -> Error(error)
            Ok(string) -> {
              let assert Ok(json) = json.decode(string, dynamic.dynamic)
              dynamic.list(config.header_decoder)(json)
            }
          }
        }),
        dynamic.element(13, dynamic.string),
        dynamic.element(14, dynamic.int),
      ),
    ),
  )(dynamic)
}

const monitor_state_columns = "
  monitor_states.monitor_id,
  monitor_states.status,
  monitor_states.missed,
  monitor_states.recovered,
  monitor_states.events,
  monitor_states.checking,
  monitor_states.next_check_at::text,
  monitor_states.next_region,
  monitor_states.metrics_last_success_at::text,
  monitor_states.metrics_last_error_at::text,
  monitor_states.metrics_last_runtime_ms,
  monitor_states.metrics_runtimes
  "

fn state_decoder(dynamic) {
  dynamic.decode9(
    State,
    dynamic.element(0, dynamic.int),
    dynamic.element(1, status.decoder),
    dynamic.element(2, dynamic.int),
    dynamic.element(3, dynamic.int),
    dynamic.element(4, dynamic.int),
    dynamic.element(5, dynamic.bool),
    dynamic.element(6, dynamic.optional(dynamic.string)),
    dynamic.element(7, dynamic.optional(dynamic.string)),
    dynamic.decode4(
      Metrics,
      dynamic.element(8, dynamic.optional(dynamic.string)),
      dynamic.element(9, dynamic.optional(dynamic.string)),
      dynamic.element(10, dynamic.optional(dynamic.int)),
      dynamic.element(11, dynamic.list(dynamic.int)),
    ),
  )(dynamic)
}

fn message_record_decoder(dynamic) {
  dynamic.decode4(
    message.MessageRecord,
    dynamic.element(0, dynamic.int),
    dynamic.element(1, dynamic.int),
    dynamic.element(2, fn(dynamic) {
      case dynamic.string(dynamic) {
        Error(error) -> Error(error)
        Ok(json) ->
          case json.decode(json, message.decoder) {
            Ok(m) -> Ok(m)
            Error(_) -> Error([])
          }
      }
    }),
    dynamic.element(3, dynamic.string),
  )(dynamic)
}

pub fn create_flip(monitor: Monitor, from: Status, to: Status) {
  db.one(
    "INSERT INTO monitor_flips (monitor_id, \"from\", \"to\") VALUES ($1, $2, $3) RETURNING id, monitor_id, \"from\", \"to\", inserted_at::text",
    [
      pgo.int(monitor.id),
      pgo.text(status.to_string(from)),
      pgo.text(status.to_string(to)),
    ],
    flip_decoder,
  )
}

pub fn list_flips(scope: Scope) {
  db.execute(
    "
    SELECT 
      monitor_flips.id, 
      monitor_flips.monitor_id, 
      monitor_flips.\"from\", 
      monitor_flips.\"to\",
      monitor_flips.inserted_at::text FROM monitor_flips 
    JOIN monitors ON monitor_flips.monitor_id = monitors.id
    WHERE monitors.team_id = $1 AND monitor_flips.inserted_at > now() - interval '30 days'
    ORDER BY inserted_at DESC
    ",
    [pgo.int(scope.team.id)],
    flip_decoder,
  )
}

fn flip_decoder(dynamic) {
  dynamic.decode5(
    Flip,
    dynamic.element(0, dynamic.int),
    dynamic.element(1, dynamic.int),
    dynamic.element(2, status.decoder),
    dynamic.element(3, status.decoder),
    dynamic.element(4, dynamic.string),
  )(dynamic)
}

pub fn pop_healthchecks(regions: List(String), limit: Int) {
  db.execute("
  WITH subset AS MATERIALIZED (
    SELECT monitor_id FROM monitor_states WHERE
      status <> 'paused' AND
      (
        (checking = false AND next_check_at < now() at time zone 'utc' AND next_region = ANY($1))
        OR
        (checking = true AND next_check_at < now() at time zone 'utc' - interval '10 minutes' AND next_region = ANY($1))
      )
    ORDER BY next_check_at
    LIMIT $2
    FOR UPDATE SKIP LOCKED
  ),

  updated AS (
    UPDATE monitor_states
    SET checking = true,
    next_check_at = now() at time zone 'UTC' + (SELECT config_interval::interval FROM monitors WHERE id = subset.monitor_id)
    FROM subset WHERE monitor_states.monitor_id = subset.monitor_id
    RETURNING  " <> monitor_state_columns <> "
  )

  SELECT " <> monitor_state_columns <> " FROM updated as monitor_states
  ", [pgo.text_array(regions), pgo.int(limit)], state_decoder)
}

pub fn check_now(monitor: Monitor) {
  let assert Ok(state) = get_state(monitor)

  db.one("
    UPDATE monitor_states SET
    checking = false, next_check_at = now() at time zone 'utc',
    next_region = $2
    WHERE monitor_id = $1
    RETURNING " <> monitor_state_columns, [
    pgo.int(monitor.id),
    pgo.nullable(pgo.text, get_next_region(monitor, state)),
  ], state_decoder)
}

pub fn pause(monitor: Monitor) {
  let assert Ok(state) = db.one("
    UPDATE monitor_states SET
    checking = false,
    status = 'paused'
    WHERE monitor_id = $1
    RETURNING " <> monitor_state_columns, [pgo.int(monitor.id)], state_decoder)

  pubsub_message.MonitorState(state)
  |> pubsub_message.to_json()
  |> json.to_string()
  |> broadcast(monitor)

  Ok(state)
}

pub fn resume(monitor: Monitor) {
  let assert Ok(state) = db.one("
    UPDATE monitor_states SET
    checking = false,
    status = 'up',
    next_check_at = now() at time zone 'utc'
    WHERE monitor_id = $1
    RETURNING " <> monitor_state_columns, [pgo.int(monitor.id)], state_decoder)

  pubsub_message.MonitorState(state)
  |> pubsub_message.to_json()
  |> json.to_string()
  |> broadcast(monitor)

  Ok(state)
}

pub fn create_metric(monitor: Monitor, name: String, value: Int) {
  db.execute(
    "INSERT INTO monitor_metrics (monitor_id, name, value) VALUES ($1, $2, $3)",
    [pgo.int(monitor.id), pgo.text(name), pgo.int(value)],
    dynamic.dynamic,
  )
}

pub fn broadcast(message, monitor: Monitor) {
  pubsub.broadcast("team:" <> int.to_string(monitor.team_id), message)
}

pub type M {
  M(name: String, timestamp: String, value: Int)
}

pub fn m_to_json(m: M) {
  json.object([
    #("name", json.string(m.name)),
    #("timestamp", json.string(m.timestamp)),
    #("value", json.int(m.value)),
  ])
}

pub fn list_healthcheck_metrics_by_name(monitor: Monitor, name: String) {
  case name {
    "1hour" -> list_healthcheck_metrics_1hour(monitor)
    "5min" -> list_healthcheck_metrics_5min(monitor)
    _ -> list_healthcheck_metrics_1min(monitor)
  }
}

pub fn list_healthcheck_metrics_1min(monitor: Monitor) {
  db.all(
    "
    SELECT
      monitor_id,
      name,
      time_bucket('1 minute', t)::text,
      ROUND(AVG(value))::int
    FROM
        monitor_metrics
    WHERE
      monitor_id = $1 AND
      name LIKE 'healthcheck:%' AND
      t >= NOW() - INTERVAL '3 hours'
    GROUP BY
      monitor_id, name, time_bucket
    ORDER BY
      time_bucket DESC, name
    ",
    [pgo.int(monitor.id)],
    dynamic.decode4(
      Metric,
      dynamic.element(0, dynamic.int),
      dynamic.element(1, dynamic.string),
      dynamic.element(2, dynamic.string),
      dynamic.element(3, dynamic.int),
    ),
  )
}

pub fn list_healthcheck_metrics_5min(monitor: Monitor) {
  db.all(
    "
    SELECT
      monitor_id,
      name,
      bucket::text,
      value::int
    FROM
        monitor_metrics_5min
    WHERE
      monitor_id = $1 AND
      name LIKE 'healthcheck:%' AND
      bucket >= NOW() - INTERVAL '5 days'
    ORDER BY
      bucket DESC, name
    ",
    [pgo.int(monitor.id)],
    dynamic.decode4(
      Metric,
      dynamic.element(0, dynamic.int),
      dynamic.element(1, dynamic.string),
      dynamic.element(2, dynamic.string),
      dynamic.element(3, dynamic.int),
    ),
  )
}

pub fn list_healthcheck_metrics_1hour(monitor: Monitor) {
  db.all(
    "
    SELECT
      monitor_id,
      name,
      bucket::text,
      value::int
    FROM
        monitor_metrics_hourly
    WHERE
      monitor_id = $1 AND
      name LIKE 'healthcheck:%' AND
      bucket >= NOW() - INTERVAL '1 year'
    ORDER BY
      bucket DESC, name
    ",
    [pgo.int(monitor.id)],
    dynamic.decode4(
      Metric,
      dynamic.element(0, dynamic.int),
      dynamic.element(1, dynamic.string),
      dynamic.element(2, dynamic.string),
      dynamic.element(3, dynamic.int),
    ),
  )
}
