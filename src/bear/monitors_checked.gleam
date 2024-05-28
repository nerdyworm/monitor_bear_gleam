import bear/alerts
import bear/incidents
import bear/log
import bear/monitors
import bear/monitors/message
import bear/monitors/monitor.{type Monitor, Monitor}
import bear/monitors/report.{type Report}
import bear/monitors/status.{type Status, Down, Up}
import bear/pubsub_message
import bear/queue
import bear_server/lib/db
import gleam/dynamic as d
import gleam/int
import gleam/json

pub fn checked(report: Report, monitor: Monitor) {
  use <- db.transaction()
  let assert Ok(state) = monitors.get_state(monitor)
  let assert Ok(_) = monitors.create_message(monitor, message.Checked(report))

  let assert Ok(updated) = case report.healthy {
    True -> monitors.ok(report, monitor, state)
    False -> monitors.missed(report, monitor, state)
  }

  pubsub_message.MonitorState(updated)
  |> pubsub_message.to_json()
  |> json.to_string()
  |> monitors.broadcast(monitor)

  let assert Ok(_) = monitors.maybe_prune(state)
  let assert Ok(_) =
    monitors.create_metric(
      monitor,
      "healthcheck:" <> report.region,
      report.runtime,
    )

  case state, updated {
    state, updated if state.status != updated.status -> {
      monitor_flipped(monitor, state.status, updated.status)
    }

    state, updated if state.recovered == 0 && updated.recovered == 1 -> {
      monitor_recovering(monitor)
    }

    _, _ -> {
      monitor_checked(monitor, updated)
    }
  }
}

fn monitor_flipped(monitor: Monitor, from: Status, to: Status) {
  queue.push(
    "monitor_flipped",
    json.object([
      #("monitor_id", json.int(monitor.id)),
      #("from", json.string(status.to_string(from))),
      #("to", json.string(status.to_string(to))),
    ])
      |> json.to_string(),
  )
}

fn monitor_recovering(monitor: Monitor) {
  incidents.recovering(monitor)
}

fn monitor_checked(monitor: Monitor, state) {
  alerts.maybe_trigger_still_down(monitor, state)
  Ok(Nil)
}

pub fn worker_after_flipped(args: String) {
  let assert Ok(monitor_id) = json.decode(args, d.field("monitor_id", d.int))
  let assert Ok(from) = json.decode(args, d.field("from", status.decoder))
  let assert Ok(to) = json.decode(args, d.field("to", status.decoder))
  let assert Ok(monitor) = monitors.get_monitor_bang(monitor_id)

  log.info(
    "[flipped] team_id="
    <> int.to_string(monitor.team_id)
    <> " monitor_id="
    <> int.to_string(monitor.id)
    <> " monitor_name="
    <> monitor.name
    <> " from="
    <> status.to_string(from)
    <> " to="
    <> status.to_string(to),
  )

  let assert Ok(_) = monitors.create_message(monitor, message.Flipped(from, to))
  let assert Ok(flip) = monitors.create_flip(monitor, from, to)

  case to {
    status.Down -> {
      let assert Ok(history) = monitors.list_recent_messages(monitor)
      let assert Ok(_) = incidents.start_incident(monitor, history)
      Nil
    }

    status.Up -> {
      let assert Ok(_) = incidents.recovered(monitor)
      Nil
    }

    _ -> {
      Nil
    }
  }

  alerts.trigger_monitor_flipped(monitor, flip)
  queue.ack()
}
