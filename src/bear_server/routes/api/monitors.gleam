import bear/monitors
import bear/monitors/flip
import bear/monitors/message
import bear/monitors/metric
import bear/monitors/monitor
import bear/monitors/report
import bear/monitors/state.{State}
import bear/monitors_checked
import bear/pubsub_message
import bear/scope.{type Scope}
import bear_server/render
import gleam/dynamic
import gleam/int
import gleam/json
import gleam/list
import wisp.{type Request, type Response}

pub fn index(scope: Scope, _req: Request) -> Response {
  let assert Ok(monitors) = monitors.list(scope)

  monitors.rows
  |> json.array(monitor.to_json)
  |> render.json(200)
}

pub fn index_states(scope: Scope, _req: Request) -> Response {
  let assert Ok(states) = monitors.list_states(scope)

  states.rows
  |> json.array(state.to_json)
  |> render.json(200)
}

pub fn index_flips(scope: Scope, _req: Request) -> Response {
  let assert Ok(states) = monitors.list_flips(scope)

  states.rows
  |> json.array(flip.to_json)
  |> render.json(200)
}

pub fn messages(scope: Scope, id: String, _req: Request) -> Response {
  let assert Ok(id) = int.parse(id)
  let assert Ok(monitor) = monitors.get_monitor(scope, id)
  let assert Ok(messages) = monitors.list_messages(monitor)

  messages.rows
  |> json.array(message.record_to_json)
  |> render.json(200)
}

pub fn show(scope: Scope, id: String, _req: Request) -> Response {
  let assert Ok(id) = int.parse(id)
  let assert Ok(monitor) = monitors.get_monitor(scope, id)

  monitor
  |> monitor.to_json()
  |> render.json(200)
}

pub fn update(scope: Scope, id: String, req: Request) -> Response {
  let assert Ok(id) = int.parse(id)
  let assert Ok(monitor) = monitors.get_monitor(scope, id)

  use params <- wisp.require_json(req)
  let assert Ok(params) = monitor.decoder(params)

  monitors.update_monitor(scope, monitor, params)
  |> render.respond(monitor.to_json)
}

pub fn check_now(scope: Scope, id: String, _req: Request) -> Response {
  let assert Ok(id) = int.parse(id)
  let assert Ok(monitor) = monitors.get_monitor(scope, id)
  let assert Ok(state) = monitors.check_now(monitor)

  State(..state, checking: True)
  |> state.to_json()
  |> render.json(200)
}

pub fn pause(scope: Scope, id: String, _req: Request) -> Response {
  let assert Ok(id) = int.parse(id)
  let assert Ok(monitor) = monitors.get_monitor(scope, id)
  let assert Ok(state) = monitors.pause(monitor)

  state
  |> state.to_json()
  |> render.json(200)
}

pub fn resume(scope: Scope, id: String, _req: Request) -> Response {
  let assert Ok(id) = int.parse(id)
  let assert Ok(monitor) = monitors.get_monitor(scope, id)
  let assert Ok(state) = monitors.resume(monitor)

  state
  |> state.to_json()
  |> render.json(200)
}

pub fn create(scope: Scope, req: Request) -> Response {
  use params <- wisp.require_json(req)

  let assert Ok(monitor) = monitor.decoder(params)
  monitors.create_monitor(scope, monitor)
  |> render.respond(monitor.to_json)
}

pub fn delete(scope: Scope, id: String, _req: Request) -> Response {
  let assert Ok(id) = int.parse(id)
  let assert Ok(monitor) = monitors.get_monitor(scope, id)
  let assert Ok(_) = monitors.delete_monitor(monitor)

  Ok(monitor)
  |> render.respond(monitor.to_json)
}

pub fn pop_healthchecks(req: Request) -> Response {
  use params <- wisp.require_json(req)
  let assert Ok(limit) = dynamic.field("limit", dynamic.int)(params)
  let assert Ok(regions) =
    dynamic.field("regions", dynamic.list(dynamic.string))(params)
  let assert Ok(states) = monitors.pop_healthchecks(regions, limit)
  let assert Ok(monitors) = monitors.list_monitors_by_states(states.rows)

  list.each(states.rows, fn(state) {
    case list.find(monitors.rows, fn(m) { m.id == state.id }) {
      Error(Nil) -> Nil
      Ok(monitor) -> {
        pubsub_message.MonitorState(state)
        |> pubsub_message.to_json()
        |> json.to_string()
        |> monitors.broadcast(monitor)
      }
    }
  })

  monitors.rows
  |> json.array(monitor.to_json)
  |> render.json(200)
}

pub fn report(id: String, req: Request) -> Response {
  let assert Ok(id) = int.parse(id)
  let assert Ok(monitor) = monitors.get_monitor_bang(id)

  use params <- wisp.require_json(req)
  let assert Ok(report) = report.decoder(params)
  let _ = monitors_checked.checked(report, monitor)
  wisp.no_content()
}

pub fn metrics(
  scope: Scope,
  id: String,
  _name: String,
  _req: Request,
) -> Response {
  let assert Ok(id) = int.parse(id)
  let assert Ok(monitor) = monitors.get_monitor(scope, id)
  let assert Ok(metrics) = monitors.list_healthcheck_metrics_1min(monitor)

  metrics
  |> json.array(metric.to_json)
  |> render.json(200)
}

pub fn metrics_by_name(
  scope: Scope,
  id: String,
  name: String,
  _req: Request,
) -> Response {
  let assert Ok(id) = int.parse(id)
  let assert Ok(monitor) = monitors.get_monitor(scope, id)

  let assert Ok(metrics) =
    monitors.list_healthcheck_metrics_by_name(monitor, name)

  metrics
  |> json.array(metric.to_json)
  |> render.json(200)
}
